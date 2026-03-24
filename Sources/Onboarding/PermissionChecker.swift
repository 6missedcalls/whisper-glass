import AVFoundation
import ApplicationServices
import SwiftUI

// MARK: - Permission Checker

/// Monitors and requests required system permissions for WhisperGlass.
/// Uses timer-based polling for accessibility since the user grants it
/// externally in System Settings.
@Observable
public final class PermissionChecker {

    // MARK: - Properties

    public private(set) var microphoneGranted: Bool = false
    public private(set) var accessibilityGranted: Bool = false

    public var allPermissionsGranted: Bool {
        microphoneGranted && accessibilityGranted
    }

    private var pollingTimer: Timer?

    // MARK: - Lifecycle

    public init() {
        // Check current state immediately
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityGranted = AXIsProcessTrusted()
    }

    deinit {
        pollingTimer?.invalidate()
    }

    // MARK: - Microphone

    public func checkMicrophone() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            microphoneGranted = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            await MainActor.run {
                microphoneGranted = granted
            }
        case .denied, .restricted:
            microphoneGranted = false
        @unknown default:
            microphoneGranted = false
        }
    }

    // MARK: - Accessibility

    /// Checks whether the app has been granted accessibility permission.
    @discardableResult
    public func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        accessibilityGranted = trusted
        return trusted
    }

    /// Opens System Settings to the Accessibility pane.
    /// Does NOT use AXIsProcessTrustedWithOptions(prompt: true) because
    /// that shows an annoying system dialog every time. Instead, just
    /// open settings and let the polling detect when it's granted.
    public func requestAccessibility() {
        let trusted = AXIsProcessTrusted()
        accessibilityGranted = trusted

        if !trusted {
            openAccessibilitySettings()
        }
    }

    /// Opens System Settings to the Accessibility privacy pane.
    public func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Polling

    public func startAccessibilityPolling() {
        stopAccessibilityPolling()
        checkAccessibility()

        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: 1.5,
            repeats: true
        ) { [weak self] _ in
            self?.checkAccessibility()
        }
    }

    public func stopAccessibilityPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Refresh

    public func refreshAll() async {
        await checkMicrophone()
        checkAccessibility()
    }
}
