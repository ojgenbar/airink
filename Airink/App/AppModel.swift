import AppKit
import Observation
import ServiceManagement

/// App-wide state: the global shortcut, launch-at-login, and the hotkey → editor flow.
@Observable
final class AppModel {
    private(set) var shortcut = Shortcut.load()
    /// Set when the shortcut could not be registered; shown in the menu and Settings.
    private(set) var hotKeyError: String?
    private(set) var isRecordingShortcut = false
    private(set) var recordingHint: String?
    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    @ObservationIgnored private let hotKeys = HotKeyCenter()
    @ObservationIgnored private let editor = EditorController()
    @ObservationIgnored private var recordingMonitor: Any?

    func start() {
        hotKeys.onPress = { [weak self] in self?.annotateClipboard() }
        if !registerHotKey(), let hotKeyError {
            showAlert(
                String(localized: "Airink couldn’t register its shortcut"),
                info: hotKeyError + "\n\n" + String(localized: "Choose a different shortcut in Settings.")
            )
        }
    }

    // MARK: Annotate

    func annotateClipboard() {
        if editor.isOpen {
            editor.bringToFront()
            return
        }
        switch Clipboard.readImage() {
        case let .success(image):
            editor.open(image)
        case .failure(.noImage):
            showAlert(
                String(localized: "No image on the clipboard"),
                info: String(localized: "Copy a screenshot first, for example with ⌃⇧⌘4, then press \(shortcut.displayString).")
            )
        case .failure(.accessDenied):
            showAlert(
                String(localized: "Airink can’t read the clipboard"),
                info: String(localized: "Allow Airink in System Settings › Privacy & Security › Paste from Other Apps.")
            )
        }
    }

    // MARK: Shortcut

    @discardableResult
    private func registerHotKey() -> Bool {
        do throws(HotKeyCenter.RegistrationError) {
            try hotKeys.register(shortcut)
            hotKeyError = nil
            return true
        } catch {
            switch error {
            case .alreadyInUse:
                hotKeyError = String(localized: "\(shortcut.displayString) is already used by another app.")
            case let .failed(status):
                hotKeyError = String(localized: "\(shortcut.displayString) couldn’t be registered (error \(status)).")
            }
            return false
        }
    }

    func startRecordingShortcut() {
        guard !isRecordingShortcut else { return }
        isRecordingShortcut = true
        recordingHint = nil
        // Release the current hotkey so pressing it again can be recorded.
        hotKeys.unregister()
        // A local monitor sees only events sent to Airink's own windows; no permission needed.
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.record(event)
            return nil
        }
    }

    func stopRecordingShortcut() {
        guard isRecordingShortcut else { return }
        if let recordingMonitor { NSEvent.removeMonitor(recordingMonitor) }
        recordingMonitor = nil
        isRecordingShortcut = false
        registerHotKey()
    }

    func resetShortcut() {
        stopRecordingShortcut()
        setShortcut(.default)
    }

    private func record(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.keyCode == 53, modifiers.isEmpty { // Esc cancels recording.
            stopRecordingShortcut()
            return
        }
        do {
            let recorded = try Shortcut.from(
                keyCode: event.keyCode,
                modifierFlags: event.modifierFlags,
                characters: event.charactersIgnoringModifiers
            )
            stopRecordingShortcut()
            setShortcut(recorded)
        } catch {
            recordingHint = String(localized: "Include ⌘, ⌥ or ⌃ in the shortcut.")
        }
    }

    private func setShortcut(_ newValue: Shortcut) {
        shortcut = newValue
        shortcut.save()
        registerHotKey()
    }

    // MARK: Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            showAlert(String(localized: "Couldn’t change Launch at Login"), info: error.localizedDescription)
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: Alerts

    private func showAlert(_ message: String, info: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.runModal()
        // Return focus to the previous app unless one of our real windows (Settings) is open.
        // The menu bar item's own window is untitled, so it doesn't count.
        let hasOpenWindow = NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
        if !editor.isOpen, !hasOpenWindow {
            NSApp.hide(nil)
        }
    }
}
