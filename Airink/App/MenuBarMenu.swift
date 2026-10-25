import SwiftUI

struct MenuBarMenu: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Annotate Clipboard  \(model.shortcut.displayString)") {
            model.annotateClipboard()
        }

        if let error = model.hotKeyError {
            Text(error)
        }

        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { model.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        ))

        Button("Settings…") {
            // Menu-bar apps aren't active by default; activate so Settings comes to the front.
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Airink") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
