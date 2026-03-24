import AppKit
import Carbon
import os

/// Injects text by copying to pasteboard, activating the target app,
/// and simulating Cmd+V.
public struct ClipboardInjector: TextInjectionStrategy, Sendable {
    public let strategyType: InjectionStrategy = .clipboard

    private static let logger = Logger(
        subsystem: "com.whisper-glass",
        category: "ClipboardInjector"
    )

    public init() {}

    public func inject(text: String) async -> Bool {
        let pasteboard = NSPasteboard.general

        // Save current clipboard
        let savedChangeCount = pasteboard.changeCount

        // Set our text
        pasteboard.clearContents()
        let didSet = pasteboard.setString(text, forType: .string)

        guard didSet else {
            Self.logger.error("Failed to set text on pasteboard")
            return false
        }

        // Find the previously active app (not WhisperGlass) and activate it
        let targetApp = findTargetApp()
        if let app = targetApp {
            app.activate()
            fputs("[WG-CI] Activated target app: \(app.localizedName ?? "unknown") (pid=\(app.processIdentifier))\n", stderr)
            // Wait for app activation to complete
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        } else {
            fputs("[WG-CI] WARNING: No target app found to activate\n", stderr)
        }

        // Simulate Cmd+V
        let pasteSuccess = simulatePaste()

        guard pasteSuccess else {
            Self.logger.error("Failed to simulate Cmd+V")
            return false
        }

        // Wait for paste to complete, then restore clipboard
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        fputs("[WG-CI] Clipboard injection succeeded (\(text.count) chars)\n", stderr)
        return true
    }

    // MARK: - Target App

    /// Finds the most recent non-WhisperGlass app to paste into.
    private func findTargetApp() -> NSRunningApplication? {
        let myBundleID = Bundle.main.bundleIdentifier ?? "com.whisper-glass.app"
        let myPID = ProcessInfo.processInfo.processIdentifier

        // Get the frontmost app that isn't us
        let apps = NSWorkspace.shared.runningApplications
        let frontmost = apps.first { app in
            app.isActive && app.processIdentifier != myPID
        }

        if let frontmost {
            return frontmost
        }

        // Fall back: find the most recently activated regular app
        return apps.first { app in
            app.activationPolicy == .regular
                && app.processIdentifier != myPID
                && app.bundleIdentifier != myBundleID
                && !app.isTerminated
        }
    }

    // MARK: - Paste Simulation

    private func simulatePaste() -> Bool {
        let vKeyCode: CGKeyCode = 0x09

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }
}
