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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum TextKey {
        case credits
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

    struct InputSourceState {
        let sourceID: String
        let languageCode: String
        let localizedName: String
    }

    private var statusItem: NSStatusItem!
    private var creditsItem: NSMenuItem?
    private var launchAtLoginItem: NSMenuItem?
    private var interfaceLanguageItem: NSMenuItem?
    private var quitItem: NSMenuItem?
    private var interfaceLanguageMenuItems: [InterfaceLanguage: NSMenuItem] = [:]

    private var selectedInterfaceLanguage: InterfaceLanguage = .english
    private var lastSourceID = ""
    private var refreshTimer: Timer?

    private let flagStore = FlagStore()

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

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        refreshTimer?.invalidate()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageOnly

        let menu = NSMenu()

        let credits = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        credits.isEnabled = false
        menu.addItem(credits)
        creditsItem = credits

        menu.addItem(NSMenuItem.separator())

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

        statusItem.menu = menu
    }

    private func registerKeyboardSourceObserver() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: NSNotification.Name(rawValue: kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }

    private func startFallbackRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateFlag(force: false)
        }
    }

    @objc private func inputSourceChanged() {
        updateFlag(force: false)
    }

    private func updateFlag(force: Bool) {
        let state = currentInputSourceState()
        if !force, state.sourceID == lastSourceID {
            return
        }

        lastSourceID = state.sourceID
        statusItem.button?.title = ""
        statusItem.button?.image = flagStore.image(for: state)
        statusItem.button?.toolTip = state.localizedName
    }

    private func currentInputSourceState() -> InputSourceState {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return InputSourceState(sourceID: "", languageCode: "en", localizedName: "")
        }

        let sourceID: String = {
            guard let value = tisPropertyValue(source, key: kTISPropertyInputSourceID),
                  CFGetTypeID(value) == CFStringGetTypeID(),
                  let str = value as? String
            else { return "" }
            return str
        }()

        let localizedName: String = {
            guard let value = tisPropertyValue(source, key: kTISPropertyLocalizedName),
                  CFGetTypeID(value) == CFStringGetTypeID(),
                  let str = value as? String
            else { return "" }
            return str
        }()

        let languageCode: String = {
            guard let value = tisPropertyValue(source, key: kTISPropertyInputSourceLanguages),
                  CFGetTypeID(value) == CFArrayGetTypeID(),
                  let langs = value as? [String],
                  let first = langs.first
            else {
                return "en"
            }
            let lowered = first.lowercased()
            return String(lowered.split(separator: "-").first ?? Substring("en"))
        }()

        return InputSourceState(sourceID: sourceID, languageCode: languageCode, localizedName: localizedName)
    }

    private func tisPropertyValue(_ source: TISInputSource, key: CFString) -> CFTypeRef? {
        guard let raw = TISGetInputSourceProperty(source, key) else {
            return nil
        }
        return Unmanaged<CFTypeRef>.fromOpaque(raw).takeUnretainedValue()
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
        let creatorName = "Created by Sergey Russu, 2026"
        switch selectedInterfaceLanguage {
        case .russian:
            switch key {
            case .credits: return "Создано Сергеем Руссу, 2026"
            case .launchAtLogin: return "Запускать при входе"
            case .interfaceLanguage: return "Язык интерфейса"
            case .quit: return "Выход"
            }
        case .english:
            switch key {
            case .credits: return creatorName
            case .launchAtLogin: return "Launch at Login"
            case .interfaceLanguage: return "Interface Language"
            case .quit: return "Quit"
            }
        case .hindi:
            switch key {
            case .credits: return creatorName
            case .launchAtLogin: return "लॉगिन पर चलाएं"
            case .interfaceLanguage: return "इंटरफ़ेस भाषा"
            case .quit: return "बंद करें"
            }
        case .chinese:
            switch key {
            case .credits: return creatorName
            case .launchAtLogin: return "登录时启动"
            case .interfaceLanguage: return "界面语言"
            case .quit: return "退出"
            }
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}


