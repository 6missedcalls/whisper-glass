import SwiftUI
import ApplicationServices

/// In-app permission prompt shown when Accessibility is not granted.
///
/// Opens System Settings directly (no janky system dialog) and polls
/// at 300ms until the user toggles the permission. Closes automatically
/// once granted — matching how Rectangle and Alt-Tab handle this.
public struct AccessibilityPromptView: View {

    private let onGranted: () -> Void

    public init(onGranted: @escaping () -> Void) {
        self.onGranted = onGranted
    }

    @State private var isPolling = false

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Accessibility Permission Required")
                .font(.headline)

            Text("WhisperGlass needs Accessibility access to inject transcribed text into your focused app and to listen for the global hotkey.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Label("Click \"Open System Settings\" below", systemImage: "1.circle.fill")
                Label("Find WhisperGlass in the list", systemImage: "2.circle.fill")
                Label("Toggle it on (you may need to unlock first)", systemImage: "3.circle.fill")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Button(action: openSettingsAndPoll) {
                Text("Open System Settings")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if isPolling {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for permission...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(30)
        .frame(width: 380)
        .onAppear {
            if AXIsProcessTrusted() {
                onGranted()
            }
        }
    }

    private func openSettingsAndPoll() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
        isPolling = true
        pollForAccess()
    }

    private func pollForAccess() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if AXIsProcessTrusted() {
                onGranted()
            } else {
                pollForAccess()
            }
        }
    }
}
