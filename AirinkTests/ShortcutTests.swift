import AppKit
import Carbon.HIToolbox
import Foundation
import Testing
@testable import Airink

struct ShortcutTests {
    @Test func defaultIsCommandShiftA() {
        #expect(Shortcut.default.displayString == "⇧⌘A")
        #expect(Shortcut.default.keyCode == UInt32(kVK_ANSI_A))
    }

    @Test func recordsModifiersInStandardOrder() throws {
        let shortcut = try Shortcut.from(
            keyCode: UInt16(kVK_ANSI_K),
            modifierFlags: [.command, .option, .control, .shift],
            characters: "k"
        )
        #expect(shortcut.displayString == "⌃⌥⇧⌘K")
        #expect(shortcut.carbonModifiers == UInt32(cmdKey | optionKey | controlKey | shiftKey))
    }

    @Test func rejectsShortcutWithoutStrongModifier() {
        #expect(throws: Shortcut.ValidationError.missingModifier) {
            try Shortcut.from(keyCode: UInt16(kVK_ANSI_A), modifierFlags: [.shift], characters: "A")
        }
    }

    @Test func allowsBareFunctionKey() throws {
        let shortcut = try Shortcut.from(keyCode: UInt16(kVK_F5), modifierFlags: [], characters: nil)
        #expect(shortcut.displayString == "F5")
    }

    @Test func labelsSpecialKeys() throws {
        let shortcut = try Shortcut.from(keyCode: UInt16(kVK_Space), modifierFlags: [.option], characters: " ")
        #expect(shortcut.displayString == "⌥Space")
    }

    @Test func persistsRoundTrip() throws {
        let suite = "dev.airink.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(Shortcut.load(from: defaults) == .default)
        let custom = Shortcut(keyCode: UInt32(kVK_ANSI_J), carbonModifiers: UInt32(controlKey), keyLabel: "J")
        custom.save(to: defaults)
        #expect(Shortcut.load(from: defaults) == custom)
    }
}
