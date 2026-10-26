import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut: a virtual key code plus Carbon modifier flags.
nonisolated struct Shortcut: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    /// Human-readable key label captured at recording time (e.g. "A", "F5").
    var keyLabel: String

    static let `default` = Shortcut(
        keyCode: UInt32(kVK_ANSI_A),
        carbonModifiers: UInt32(cmdKey | shiftKey),
        keyLabel: "A"
    )

    /// Display string in standard macOS order, e.g. "⌃⌥⇧⌘A".
    var displayString: String {
        var result = ""
        if carbonModifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        return result + keyLabel
    }
}

// MARK: - Recording from NSEvent

extension Shortcut {
    enum ValidationError: Error, Equatable {
        /// Global shortcuts need ⌘, ⌃ or ⌥ (function keys excepted) so they don't swallow typing.
        case missingModifier
    }

    /// Builds a shortcut from a key-down event captured by the recorder.
    nonisolated static func from(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        characters: String?
    ) throws(ValidationError) -> Shortcut {
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }

        let functionKeyLabel = functionKeyLabels[Int(keyCode)]
        let hasStrongModifier = carbon & UInt32(cmdKey | optionKey | controlKey) != 0
        guard hasStrongModifier || functionKeyLabel != nil else { throw .missingModifier }

        let label = functionKeyLabel
            ?? specialKeyLabels[Int(keyCode)]
            ?? LatinKey.character(keyCode: keyCode, characters: characters)?
                .uppercased().trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? "Key \(keyCode)"
        return Shortcut(keyCode: UInt32(keyCode), carbonModifiers: carbon, keyLabel: label)
    }

    private nonisolated static let functionKeyLabels: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    private nonisolated static let specialKeyLabels: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    ]
}

// MARK: - Persistence

extension Shortcut {
    private nonisolated static let defaultsKey = "globalShortcut"

    nonisolated static func load(from defaults: UserDefaults = .standard) -> Shortcut {
        guard let data = defaults.data(forKey: defaultsKey),
              let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data)
        else { return .default }
        return shortcut
    }

    nonisolated func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}

private extension String {
    nonisolated var nonEmpty: String? { isEmpty ? nil : self }
}
