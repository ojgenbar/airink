import SwiftUI

@main
struct AirinkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Airink", systemImage: "pencil.and.scribble") {
            MenuBarMenu(model: appDelegate.model)
        }

        Settings {
            SettingsView(model: appDelegate.model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests host inside the app; don't grab the global shortcut while they run.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        model.start()
    }
}
