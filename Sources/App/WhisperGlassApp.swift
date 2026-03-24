import SwiftUI
import WhisperGlassCore

extension Notification.Name {
    static let openSettingsRequest = Notification.Name("WhisperGlass.openSettings")
}

@main
struct WhisperGlassApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Hidden 1x1 window that captures @Environment(\.openSettings).
        // Required because MenuBarExtra uses NSMenu which doesn't provide
        // a SwiftUI environment. This window is never visible to the user.
        Window("Hidden", id: "hidden") {
            SettingsOpenerView()
                .frame(width: 0, height: 0)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)

        MenuBarExtra {
            Button(appDelegate.isRecording ? "Stop & Transcribe" : "Start Recording") {
                appDelegate.toggleRecording()
            }
            Divider()
            Text("Hold \(appDelegate.appSettings.hotkeyDescription) to dictate")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Button("Settings...") {
                NotificationCenter.default.post(name: .openSettingsRequest, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(systemName: appDelegate.isRecording ? "mic.fill" : "mic")
        }

        Settings {
            SettingsView(
                appSettings: appDelegate.appSettings,
                audioDeviceManager: appDelegate.audioDeviceManager
            )
        }
    }
}

/// Captures `@Environment(\.openSettings)` from the hidden window's SwiftUI
/// context and opens Settings when triggered via NotificationCenter.
private struct SettingsOpenerView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { _ in
                Task { @MainActor in
                    NSApp.setActivationPolicy(.regular)
                    try? await Task.sleep(for: .milliseconds(100))
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
            }
    }
}
