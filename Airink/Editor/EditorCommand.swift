import AppKit
import Carbon.HIToolbox

/// Keyboard commands available in the editor while no text is being typed.
nonisolated enum EditorCommand: Equatable, Sendable {
    case copy, cancel, undo, redo
    case tool(Tool)
    case width(StrokeWidth)

    init?(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags, characters: String?) {
        let flags = modifierFlags.intersection([.command, .option, .control, .shift])
        let key = characters?.lowercased()

        if flags == .command {
            switch key {
            case "c": self = .copy
            case "z": self = .undo
            case "w": self = .cancel
            default: return nil
            }
            return
        }
        if flags == [.command, .shift], key == "z" {
            self = .redo
            return
        }

        // Plain keys; Shift is allowed so it doesn't block e.g. Return.
        guard flags.subtracting(.shift).isEmpty else { return nil }
        switch Int(keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter: self = .copy; return
        case kVK_Escape: self = .cancel; return
        default: break
        }
        switch key {
        case "a": self = .tool(.arrow)
        case "r": self = .tool(.rectangle)
        case "l": self = .tool(.line)
        case "t": self = .tool(.text)
        case "1": self = .width(.thin)
        case "2": self = .width(.medium)
        case "3": self = .width(.thick)
        default: return nil
        }
    }

    init?(_ event: NSEvent) {
        self.init(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags,
            characters: event.charactersIgnoringModifiers
        )
    }
}
