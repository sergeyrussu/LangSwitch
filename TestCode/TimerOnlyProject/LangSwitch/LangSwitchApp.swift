import SwiftUI
import AppKit
import Carbon

@main
struct LangSwitchTimerOnlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    struct InputSourceState {
        let sourceID: String
        let languageCode: String
        let localizedName: String
    }

    private var statusItem: NSStatusItem!
    private var refreshTimer: Timer?
    private var lastInputStateKey = ""

    private let flagStore = FlagStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        startRefreshTimer()
        updateFlag(force: true)
    }

    deinit {
        refreshTimer?.invalidate()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func startRefreshTimer() {
        // Timer-only mode: no notification observers.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateFlag(force: false)
        }
    }

    private func updateFlag(force: Bool) {
        let state = currentInputSourceState()
        let stateKey = makeStateKey(for: state)
        if !force, stateKey == lastInputStateKey {
            return
        }

        lastInputStateKey = stateKey
        statusItem.button?.title = ""
        statusItem.button?.image = flagStore.image(for: state)
        statusItem.button?.toolTip = state.localizedName
    }

    private func makeStateKey(for state: InputSourceState) -> String {
        "\(state.sourceID)|\(state.languageCode)|\(state.localizedName)"
    }

    private func currentInputSourceState() -> InputSourceState {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return InputSourceState(sourceID: "", languageCode: "", localizedName: "")
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
                return ""
            }
            let lowered = first.lowercased()
            return String(lowered.split(separator: "-").first ?? Substring(""))
        }()

        return InputSourceState(sourceID: sourceID, languageCode: languageCode, localizedName: localizedName)
    }

    private func tisPropertyValue(_ source: TISInputSource, key: CFString) -> CFTypeRef? {
        guard let raw = TISGetInputSourceProperty(source, key) else {
            return nil
        }
        return Unmanaged<CFTypeRef>.fromOpaque(raw).takeUnretainedValue()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
