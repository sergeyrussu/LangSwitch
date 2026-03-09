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
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
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
            guard let idRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return "" }
            return unsafeBitCast(idRef, to: NSString.self) as String
        }()

        let localizedName: String = {
            guard let nameRef = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { return "" }
            return unsafeBitCast(nameRef, to: NSString.self) as String
        }()

        let languageCode: String = {
            guard let langsRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages),
                  let langs = unsafeBitCast(langsRef, to: NSArray.self) as? [String],
                  let first = langs.first
            else {
                return "en"
            }
            let lowered = first.lowercased()
            return String(lowered.split(separator: "-").first ?? Substring("en"))
        }()

        return InputSourceState(sourceID: sourceID, languageCode: languageCode, localizedName: localizedName)
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

private final class FlagStore {
    private var cache: [String: NSImage] = [:]

    func image(for state: AppDelegate.InputSourceState) -> NSImage {
        let country = mappedCountryCode(sourceID: state.sourceID, languageCode: state.languageCode)
        if let cached = cache[country] {
            return cached
        }

        let image = FlagImageFactory.flag(for: country)
        cache[country] = image
        return image
    }

    private func mappedCountryCode(sourceID: String, languageCode: String) -> String {
        let source = sourceID.lowercased()

        // Most reliable: map from concrete macOS input source IDs.
        if source.contains("russian") { return "RU" }
        if source.contains("hindi") || source.contains("devanagari") { return "IN" }
        if source.contains("pinyin") || source.contains("chinese") || source.contains("scim") { return "CN" }
        if source.contains("kotoeri") || source.contains("japanese") { return "JP" }
        if source.contains("korean") { return "KR" }
        if source.contains("ukrainian") { return "UA" }
        if source.contains("german") { return "DE" }
        if source.contains("french") { return "FR" }
        if source.contains("spanish") { return "ES" }
        if source.contains("italian") { return "IT" }
        if source.contains("arabic") { return "SA" }
        if source.contains("turkish") { return "TR" }
        if source.contains("abc") || source.contains("us") { return "US" }

        // Fallback: map from language code.
        switch languageCode.lowercased() {
        case "ru": return "RU"
        case "en": return "US"
        case "hi": return "IN"
        case "zh": return "CN"
        case "ja": return "JP"
        case "ko": return "KR"
        case "uk": return "UA"
        case "de": return "DE"
        case "fr": return "FR"
        case "es": return "ES"
        case "it": return "IT"
        case "ar": return "SA"
        case "tr": return "TR"
        default: return "US"
        }
    }
}

private enum FlagImageFactory {
    static func flag(for countryCode: String, size: NSSize = NSSize(width: 22, height: 14)) -> NSImage {
        switch countryCode {
        case "RU": return russia(size: size)
        case "US": return usa(size: size)
        case "IN": return india(size: size)
        case "CN": return china(size: size)
        case "JP": return japan(size: size)
        case "KR": return korea(size: size)
        case "UA": return ukraine(size: size)
        case "DE": return germany(size: size)
        case "FR": return france(size: size)
        case "ES": return spain(size: size)
        case "IT": return italy(size: size)
        case "SA": return saudi(size: size)
        case "TR": return turkey(size: size)
        default: return usa(size: size)
        }
    }

    private static func russia(size: NSSize) -> NSImage {
        stripe3(size: size, top: .white, mid: .systemBlue, bottom: .systemRed)
    }

    private static func usa(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let stripeHeight = size.height / 13
        for i in 0..<13 {
            (i.isMultiple(of: 2) ? NSColor.systemRed : NSColor.white).setFill()
            NSBezierPath(rect: NSRect(x: 0, y: CGFloat(i) * stripeHeight, width: size.width, height: stripeHeight)).fill()
        }
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: size.height - stripeHeight * 7, width: size.width * 0.45, height: stripeHeight * 7)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func india(size: NSSize) -> NSImage {
        let image = stripe3(size: size, top: .systemOrange, mid: .white, bottom: .systemGreen)
        image.lockFocus()
        NSColor.systemBlue.setStroke()
        let d = min(size.width, size.height) * 0.34
        let r = NSRect(x: (size.width - d) / 2, y: (size.height - d) / 2, width: d, height: d)
        let chakra = NSBezierPath(ovalIn: r)
        chakra.lineWidth = 1
        chakra.stroke()
        image.unlockFocus()
        return image
    }

    private static func china(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 6), .foregroundColor: NSColor.systemYellow]
        NSAttributedString(string: "★", attributes: attrs).draw(at: NSPoint(x: 3, y: 5))
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func japan(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor.systemRed.setFill()
        let d = min(size.width, size.height) * 0.48
        NSBezierPath(ovalIn: NSRect(x: (size.width - d) / 2, y: (size.height - d) / 2, width: d, height: d)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func korea(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor.systemRed.setFill()
        let d = min(size.width, size.height) * 0.42
        NSBezierPath(ovalIn: NSRect(x: (size.width - d) / 2, y: (size.height - d) / 2, width: d, height: d)).fill()
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: NSRect(x: (size.width - d) / 2, y: (size.height - d) / 2 - d * 0.2, width: d, height: d * 0.5)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func ukraine(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: size.height / 2, width: size.width, height: size.height / 2)).fill()
        NSColor.systemYellow.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: size.width, height: size.height / 2)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func germany(size: NSSize) -> NSImage { stripe3(size: size, top: .black, mid: .systemRed, bottom: .systemYellow) }

    private static func france(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let w = size.width / 3
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: w, height: size.height)).fill()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: w, y: 0, width: w, height: size.height)).fill()
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(x: w * 2, y: 0, width: w, height: size.height)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func spain(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let small = size.height * 0.25
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: size.height - small, width: size.width, height: small)).fill()
        NSColor.systemYellow.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: small, width: size.width, height: size.height - small * 2)).fill()
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: size.width, height: small)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func italy(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let w = size.width / 3
        NSColor.systemGreen.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: w, height: size.height)).fill()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: w, y: 0, width: w, height: size.height)).fill()
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(x: w * 2, y: 0, width: w, height: size.height)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func saudi(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemGreen.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: size.width * 0.2, y: size.height * 0.2, width: size.width * 0.6, height: 1.5)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func turkey(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor.white.setFill()
        let d = min(size.width, size.height) * 0.44
        NSBezierPath(ovalIn: NSRect(x: size.width * 0.25, y: (size.height - d) / 2, width: d, height: d)).fill()
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: NSRect(x: size.width * 0.31, y: (size.height - d * 0.8) / 2, width: d * 0.8, height: d * 0.8)).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 4), .foregroundColor: NSColor.white]
        NSAttributedString(string: "★", attributes: attrs).draw(at: NSPoint(x: size.width * 0.56, y: size.height * 0.38))
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func stripe3(size: NSSize, top: NSColor, mid: NSColor, bottom: NSColor) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let h = size.height / 3
        top.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: h * 2, width: size.width, height: h)).fill()
        mid.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: h, width: size.width, height: h)).fill()
        bottom.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: size.width, height: h)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func border(size: NSSize) {
        NSColor.black.withAlphaComponent(0.25).setStroke()
        let p = NSBezierPath(rect: NSRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5))
        p.lineWidth = 1
        p.stroke()
    }
}
