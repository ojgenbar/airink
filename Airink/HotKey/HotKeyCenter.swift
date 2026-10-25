import Carbon.HIToolbox

/// Registers a single system-wide hotkey via Carbon's `RegisterEventHotKey`.
///
/// This API works inside the App Sandbox and needs no Accessibility or Input Monitoring
/// permission: the system delivers only the registered key combination to us, never other keystrokes.
final class HotKeyCenter {
    enum RegistrationError: Error, Equatable {
        /// Another process holds the same combination exclusively.
        case alreadyInUse
        case failed(OSStatus)
    }

    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private static let signature: OSType = 0x4149_524B // 'AIRK'

    func register(_ shortcut: Shortcut) throws(RegistrationError) {
        unregister()
        try installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: 1),
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive),
            &ref
        )
        switch status {
        case noErr: hotKeyRef = ref
        case OSStatus(eventHotKeyExistsErr): throw .alreadyInUse
        default: throw .failed(status)
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() throws(RegistrationError) {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // Carbon delivers hotkey events on the main thread's event loop.
        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { center.onPress?() }
            return noErr
        }
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        guard status == noErr else { throw .failed(status) }
    }
}
