import AppKit
import Carbon.HIToolbox
import Testing
@testable import Airink

/// Shortcuts must work regardless of the active keyboard layout.
struct KeyboardLayoutTests {
    @Test func cyrillicLayoutUsesKeyPosition() {
        // Russian layout: the C key types "с", A types "ф", Z types "я".
        #expect(EditorCommand(keyCode: UInt16(kVK_ANSI_C), modifierFlags: .command, characters: "с") == .copy)
        #expect(EditorCommand(keyCode: UInt16(kVK_ANSI_Z), modifierFlags: .command, characters: "я") == .undo)
        #expect(EditorCommand(keyCode: UInt16(kVK_ANSI_Z), modifierFlags: [.command, .shift], characters: "Я") == .redo)
        #expect(EditorCommand(keyCode: UInt16(kVK_ANSI_A), modifierFlags: [], characters: "ф") == .tool(.arrow))
        #expect(EditorCommand(keyCode: UInt16(kVK_ANSI_P), modifierFlags: [], characters: "з") == .tool(.pixelate))
    }

    @Test func latinLayoutUsesKeyPosition() {
        // Dvorak: QWERTY's C key types "j", and QWERTY's J key types "c".
        #expect(EditorCommand(keyCode: UInt16(kVK_ANSI_C), modifierFlags: .command, characters: "j") == .copy)
        #expect(EditorCommand(keyCode: UInt16(kVK_ANSI_J), modifierFlags: .command, characters: "c") == nil)
        // AZERTY: QWERTY's A key types "q".
        #expect(EditorCommand(keyCode: UInt16(kVK_ANSI_A), modifierFlags: [], characters: "q") == .tool(.arrow))
    }

    @Test func numberRowWorksOnAzerty() {
        // AZERTY types "&" and "é" on the unshifted 1 and 2 keys.
        #expect(EditorCommand(keyCode: UInt16(kVK_ANSI_1), modifierFlags: [], characters: "&") == .width(.thin))
        #expect(EditorCommand(keyCode: UInt16(kVK_ANSI_2), modifierFlags: [], characters: "é") == .width(.medium))
        #expect(EditorCommand(keyCode: UInt16(kVK_ANSI_Keypad3), modifierFlags: [], characters: "3") == .width(.thick))
    }

    @Test func recordedShortcutLabelIsLatin() throws {
        let shortcut = try Shortcut.from(
            keyCode: UInt16(kVK_ANSI_A),
            modifierFlags: [.command, .shift],
            characters: "Ф"
        )
        #expect(shortcut.displayString == "⇧⌘A")
        #expect(shortcut == .default)
    }
}
