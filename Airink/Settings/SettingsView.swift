import SwiftUI

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Shortcut") {
                    ShortcutRecorder(model: model)
                }
                if let error = model.hotKeyError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
            } footer: {
                Text("Airink reads the clipboard only when you press the shortcut. Nothing is stored or sent anywhere.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onDisappear { model.stopRecordingShortcut() }
    }
}

private struct ShortcutRecorder: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    if model.isRecordingShortcut {
                        model.stopRecordingShortcut()
                    } else {
                        model.startRecordingShortcut()
                    }
                } label: {
                    Text(model.isRecordingShortcut ? "Type shortcut…" : model.shortcut.displayString)
                        .monospacedDigit()
                        .frame(minWidth: 110)
                }
                .help("Click, then press the new key combination. Esc cancels.")

                if model.shortcut != .default {
                    Button("Reset", systemImage: "arrow.counterclockwise") {
                        model.resetShortcut()
                    }
                    .labelStyle(.iconOnly)
                    .help("Reset to \(Shortcut.default.displayString)")
                }
            }
            if model.isRecordingShortcut, let hint = model.recordingHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
