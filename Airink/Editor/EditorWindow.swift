import AppKit

/// Chromeless, movable editor window that routes keyboard commands to its controller.
final class EditorWindow: NSWindow {
    var onCommand: ((EditorCommand) -> Void)?
    var isEditingText: () -> Bool = { false }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        level = .floating
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }
    }

    override var canBecomeKey: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isEditingText() {
            // No main menu is shown for a menu-bar app, so forward standard editing
            // shortcuts to the text field's field editor ourselves.
            if let action = Self.textEditingAction(for: event),
               NSApp.sendAction(action, to: nil, from: self) {
                return true
            }
            return super.performKeyEquivalent(with: event)
        }
        if event.modifierFlags.contains(.command), let command = EditorCommand(event) {
            onCommand?(command)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if !isEditingText(), let command = EditorCommand(event) {
            onCommand?(command)
        } else {
            super.keyDown(with: event)
        }
    }

    private static func textEditingAction(for event: NSEvent) -> Selector? {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        switch (flags, event.charactersIgnoringModifiers?.lowercased()) {
        case (.command, "c"): return #selector(NSText.copy(_:))
        case (.command, "x"): return #selector(NSText.cut(_:))
        case (.command, "v"): return #selector(NSText.paste(_:))
        case (.command, "a"): return #selector(NSText.selectAll(_:))
        case (.command, "z"): return Selector(("undo:"))
        case ([.command, .shift], "z"): return Selector(("redo:"))
        default: return nil
        }
    }
}
