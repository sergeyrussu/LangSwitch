import SwiftUI
import AppKit
import Carbon
import ServiceManagement

@main
struct LangSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum TextKey {
        case credits
        case noInputSources
        case launchAtLogin
        case interfaceLanguage
        case quit
    }

    private enum InterfaceLanguage: String, CaseIterable {
        case russian
        case english
        case hindi
        case chinese

        var displayName: String {
            switch self {
            case .russian: return "Русский"
            case .english: return "English"
            case .hindi: return "हिन्दी"
            case .chinese: return "中文"
            }
        }
    }

    private enum SettingsKeys {
        static let interfaceLanguage = "InterfaceLanguage"
    }

    private struct InputSourceState: Equatable {
        let sourceID: String
        let languageCode: String
        let localizedName: String
    }

    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu?
    private var creditsItem: NSMenuItem?
    private var inputSourcesSeparatorItem: NSMenuItem?
    private var inputSourceItems: [NSMenuItem] = []
    private var launchAtLoginItem: NSMenuItem?
    private var interfaceLanguageItem: NSMenuItem?
    private var quitItem: NSMenuItem?
    private var interfaceLanguageMenuItems: [InterfaceLanguage: NSMenuItem] = [:]

    private var selectedInterfaceLanguage: InterfaceLanguage = .english
    private var lastInputState: InputSourceState?
    private var refreshTimer: Timer?
    private var eventRefreshTask: Task<Void, Never>?
    private var eventRefreshAttempts = 0

    private let eventRefreshDebounce: TimeInterval = 0.10
    private let eventRefreshInterval: TimeInterval = 0.12
    private let maxEventRefreshAttempts = 15

    private let flagStore = FlagStore()
    private let localizedTexts: [InterfaceLanguage: [TextKey: String]] = [
        .russian: [
            .credits: "Создал Сергей Руссу, 2026",
            .noInputSources: "Нет источников ввода",
            .launchAtLogin: "Запускать при входе",
            .interfaceLanguage: "Язык интерфейса",
            .quit: "Выход"
        ],
        .english: [
            .credits: "Created by Sergey Russu, 2026",
            .noInputSources: "No input sources",
            .launchAtLogin: "Launch at Login",
            .interfaceLanguage: "Interface Language",
            .quit: "Quit"
        ],
        .hindi: [
            .credits: "निर्माण: Sergey Russu, 2026",
            .noInputSources: "कोई इनपुट स्रोत नहीं",
            .launchAtLogin: "लॉगिन पर चलाएं",
            .interfaceLanguage: "इंटरफ़ेस भाषा",
            .quit: "बंद करें"
        ],
        .chinese: [
            .credits: "作者：Sergey Russu，2026年",
            .noInputSources: "没有输入源",
            .launchAtLogin: "登录时启动",
            .interfaceLanguage: "界面语言",
            .quit: "退出"
        ]
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        selectedInterfaceLanguage = loadSavedInterfaceLanguage()

        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        registerKeyboardSourceObserver()
        startFallbackRefreshTimer()
        updateFlag(force: true)
        updateLaunchAtLoginMenuState()
        applyInterfaceLanguage()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopObserversAndTimers()
    }

    private func stopObserversAndTimers() {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDistributedCenter(),
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            CFNotificationName(kTISNotifySelectedKeyboardInputSourceChanged as CFString),
            nil
        )
        eventRefreshTask?.cancel()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageOnly

        let menu = NSMenu()

        let credits = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        credits.isEnabled = false
        menu.addItem(credits)
        creditsItem = credits

        // Placeholder separator: input sources are dynamically inserted above this separator.
        let inputSeparator = NSMenuItem.separator()
        menu.addItem(inputSeparator)
        inputSourcesSeparatorItem = inputSeparator

        let launchItem = NSMenuItem(title: "", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        menu.addItem(launchItem)
        launchAtLoginItem = launchItem

        let languageItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for language in InterfaceLanguage.allCases {
            let item = NSMenuItem(title: language.displayName, action: #selector(selectInterfaceLanguage), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            languageMenu.addItem(item)
            interfaceLanguageMenuItems[language] = item
        }
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)
        interfaceLanguageItem = languageItem

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        quitItem = quit

        menu.delegate = self
        statusMenu = menu
        statusItem.menu = menu
    }

    private func registerKeyboardSourceObserver() {
        let center = CFNotificationCenterGetDistributedCenter()
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let app = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    app.scheduleEventRefresh()
                }
            },
            (kTISNotifySelectedKeyboardInputSourceChanged as CFString),
            nil,
            .deliverImmediately
        )
    }

    private func startFallbackRefreshTimer() {
        // Backup polling only: the primary update path is the system notification above.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in
                self.updateFlag(force: false)
            }
        }
    }

    private func scheduleEventRefresh() {
        eventRefreshTask?.cancel()
        eventRefreshAttempts = 0
        scheduleEventRefreshAttempt(after: eventRefreshDebounce)
    }

    private func scheduleEventRefreshAttempt(after delay: TimeInterval) {
        eventRefreshTask?.cancel()
        eventRefreshTask = Task { @MainActor [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }
            self?.runEventRefreshAttempt()
        }
    }

    private func runEventRefreshAttempt() {
        eventRefreshAttempts += 1
        let changed = updateFlag(force: false)
        if changed {
            return
        }
        if eventRefreshAttempts < maxEventRefreshAttempts {
            scheduleEventRefreshAttempt(after: eventRefreshInterval)
        }
    }

    @discardableResult
    private func updateFlag(force: Bool) -> Bool {
        let state = currentInputSourceState()
        if !force, state == lastInputState {
            return false
        }

        lastInputState = state
        statusItem.button?.title = ""
        statusItem.button?.image = flagStore.image(sourceID: state.sourceID, languageCode: state.languageCode)
        statusItem.button?.toolTip = "LangSwich"
        return true
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusMenu else { return }
        let state = lastInputState ?? currentInputSourceState()
        rebuildInputSourcesMenu(currentState: state)
    }

    private func currentInputSourceState() -> InputSourceState {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return InputSourceState(sourceID: "", languageCode: "", localizedName: "")
        }

        let sourceID = tisString(source, key: kTISPropertyInputSourceID) ?? ""
        let localizedName = tisString(source, key: kTISPropertyLocalizedName) ?? ""
        let languageCode = tisPrimaryLanguageCode(source) ?? ""

        return InputSourceState(sourceID: sourceID, languageCode: languageCode, localizedName: localizedName)
    }

    private func tisPropertyValue(_ source: TISInputSource, key: CFString) -> CFTypeRef? {
        guard let raw = TISGetInputSourceProperty(source, key) else {
            return nil
        }
        return Unmanaged<CFTypeRef>.fromOpaque(raw).takeUnretainedValue()
    }

    private func tisString(_ source: TISInputSource, key: CFString) -> String? {
        guard let value = tisPropertyValue(source, key: key),
              CFGetTypeID(value) == CFStringGetTypeID(),
              let stringValue = value as? String
        else {
            return nil
        }
        return stringValue
    }

    private func tisPrimaryLanguageCode(_ source: TISInputSource) -> String? {
        guard let value = tisPropertyValue(source, key: kTISPropertyInputSourceLanguages),
              CFGetTypeID(value) == CFArrayGetTypeID(),
              let langs = value as? [String],
              let first = langs.first
        else {
            return nil
        }
        let lowered = first.lowercased()
        return lowered.split(separator: "-").first.map(String.init) ?? ""
    }

    private func tisBool(_ source: TISInputSource, key: CFString) -> Bool {
        guard let value = tisPropertyValue(source, key: key),
              CFGetTypeID(value) == CFBooleanGetTypeID()
        else {
            return false
        }
        return CFEqual(value, kCFBooleanTrue)
    }

    private func availableInputSources() -> [InputSourceState] {
        guard let array = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }

        var result: [InputSourceState] = []
        var seen = Set<String>()

        for source in array {
            guard tisBool(source, key: kTISPropertyInputSourceIsSelectCapable) else { continue }
            guard let sourceID = tisString(source, key: kTISPropertyInputSourceID), !sourceID.isEmpty else { continue }
            guard let localizedName = tisString(source, key: kTISPropertyLocalizedName), !localizedName.isEmpty else { continue }
            if shouldExcludeInputSource(sourceID: sourceID, localizedName: localizedName) { continue }
            if seen.contains(sourceID) { continue }

            let languageCode = tisPrimaryLanguageCode(source) ?? ""
            result.append(InputSourceState(sourceID: sourceID, languageCode: languageCode, localizedName: localizedName))
            seen.insert(sourceID)
        }

        return result.sorted { $0.localizedName.localizedCaseInsensitiveCompare($1.localizedName) == .orderedAscending }
    }

    private func shouldExcludeInputSource(sourceID: String, localizedName: String) -> Bool {
        let id = sourceID.lowercased()
        let name = localizedName.lowercased()

        if id.contains("characterpalette") || id.contains("emoji") {
            return true
        }
        if name.contains("emoji") || name.contains("symbols") {
            return true
        }
        return false
    }

    private func rebuildInputSourcesMenu(currentState: InputSourceState) {
        guard let statusMenu, let inputSourcesSeparatorItem else { return }

        for item in inputSourceItems {
            statusMenu.removeItem(item)
        }
        inputSourceItems.removeAll()

        let sources = availableInputSources()
        let separatorIndex = statusMenu.index(of: inputSourcesSeparatorItem)
        let insertBaseIndex = separatorIndex >= 0 ? separatorIndex : 1

        if sources.isEmpty {
            let emptyItem = NSMenuItem(title: text(.noInputSources), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            statusMenu.insertItem(emptyItem, at: insertBaseIndex)
            inputSourceItems.append(emptyItem)
            return
        }

        for source in sources {
            let item = NSMenuItem(title: source.localizedName, action: #selector(selectInputSourceFromMenu(_:)), keyEquivalent: "")
            item.image = flagStore.image(sourceID: source.sourceID, languageCode: source.languageCode)
            item.target = self
            item.representedObject = source.sourceID
            item.isEnabled = true
            if source.sourceID == currentState.sourceID {
                item.state = .on
            }
            statusMenu.insertItem(item, at: insertBaseIndex + inputSourceItems.count)
            inputSourceItems.append(item)
        }
    }

    @objc private func selectInputSourceFromMenu(_ sender: NSMenuItem) {
        guard let sourceID = sender.representedObject as? String else {
            NSSound.beep()
            return
        }
        selectInputSource(withID: sourceID)
    }

    private func selectInputSource(withID sourceID: String) {
        guard let source = inputSource(withID: sourceID) else {
            NSSound.beep()
            return
        }

        let status = TISSelectInputSource(source)
        if status != noErr {
            NSSound.beep()
            return
        }

        // Fast UI sync right after manual menu selection.
        scheduleEventRefresh()
    }

    private func inputSource(withID sourceID: String) -> TISInputSource? {
        let properties = [kTISPropertyInputSourceID: sourceID as CFString] as CFDictionary
        guard let list = TISCreateInputSourceList(properties, false)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }
        return list.first
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            let service = SMAppService.mainApp
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSSound.beep()
            NSLog("Failed to toggle Launch at Login: \(error.localizedDescription)")
        }

        updateLaunchAtLoginMenuState()
    }

    private func updateLaunchAtLoginMenuState() {
        guard let launchAtLoginItem else { return }

        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLoginItem.state = .on
        case .requiresApproval:
            launchAtLoginItem.state = .mixed
        default:
            launchAtLoginItem.state = .off
        }
    }

    @objc private func selectInterfaceLanguage(_ sender: NSMenuItem) {
        guard
            let raw = sender.representedObject as? String,
            let language = InterfaceLanguage(rawValue: raw)
        else {
            return
        }

        selectedInterfaceLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: SettingsKeys.interfaceLanguage)
        applyInterfaceLanguage()
    }

    private func applyInterfaceLanguage() {
        creditsItem?.title = text(.credits)
        launchAtLoginItem?.title = text(.launchAtLogin)
        interfaceLanguageItem?.title = text(.interfaceLanguage)
        quitItem?.title = text(.quit)
        updateInterfaceLanguageMenuState()
    }

    private func updateInterfaceLanguageMenuState() {
        for (language, item) in interfaceLanguageMenuItems {
            item.state = language == selectedInterfaceLanguage ? .on : .off
        }
    }

    private func loadSavedInterfaceLanguage() -> InterfaceLanguage {
        guard
            let saved = UserDefaults.standard.string(forKey: SettingsKeys.interfaceLanguage),
            let language = InterfaceLanguage(rawValue: saved)
        else {
            return .english
        }
        return language
    }

    private func text(_ key: TextKey) -> String {
        localizedTexts[selectedInterfaceLanguage]?[key]
            ?? localizedTexts[.english]?[key]
            ?? ""
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
