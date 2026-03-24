import AppKit
import os

/// Manages discovery and tracking of running applications that can receive injected text.
///
/// Automatically tracks the frontmost application (excluding WhisperGlass itself)
/// and observes application launch/quit events via NSWorkspace notifications.
@Observable
public final class TargetAppManager {

    private static let logger = Logger(
        subsystem: "com.whisper-glass",
        category: "TargetAppManager"
    )

    private static let whisperGlassBundleID = "com.whisper-glass.app"

    // MARK: - Public Properties

    /// All running applications that have visible windows and can receive text.
    public private(set) var availableApps: [TargetApp] = []

    /// The currently selected target application. In auto mode, this tracks the frontmost app.
    public var selectedApp: TargetApp?

    /// When `true`, automatically tracks the frontmost application as the target.
    public var autoTrackFrontmost: Bool = true {
        didSet {
            if autoTrackFrontmost {
                updateFrontmostApp()
            }
        }
    }

    // MARK: - Private State

    private var workspaceObservers: [NSObjectProtocol] = []

    // MARK: - Lifecycle

    public init() {
        refreshAvailableApps()
        startObserving()

        if autoTrackFrontmost {
            updateFrontmostApp()
        }
    }

    deinit {
        stopObserving()
    }

    // MARK: - Public Methods

    /// Refreshes the list of available target applications.
    public func refreshAvailableApps() {
        let runningApps = NSWorkspace.shared.runningApplications
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        availableApps = runningApps
            .filter { app in
                app.activationPolicy == .regular
                    && app.bundleIdentifier != nil
                    && app.bundleIdentifier != Self.whisperGlassBundleID
            }
            .map { app in
                TargetApp(
                    id: app.processIdentifier,
                    bundleIdentifier: app.bundleIdentifier ?? "",
                    name: app.localizedName ?? "Unknown",
                    isActive: app.processIdentifier == frontmostPID
                )
            }
            .sorted { lhs, rhs in
                // Developer tools first, then alphabetical
                if lhs.isDeveloperTool != rhs.isDeveloperTool {
                    return lhs.isDeveloperTool
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        Self.logger.info("Refreshed app list: \(self.availableApps.count) apps available")
    }

    /// Manually selects a target application by its process ID.
    public func selectApp(withPID pid: pid_t) {
        autoTrackFrontmost = false
        selectedApp = availableApps.first { $0.id == pid }
    }

    // MARK: - Private Observation

    private func startObserving() {
        let center = NSWorkspace.shared.notificationCenter

        let launchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAvailableApps()
        }

        let quitObserver = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppQuit(notification)
        }

        let activateObserver = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppActivated()
        }

        workspaceObservers = [launchObserver, quitObserver, activateObserver]
    }

    private func stopObserving() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            center.removeObserver(observer)
        }
        workspaceObservers = []
    }

    private func handleAppQuit(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication else {
            refreshAvailableApps()
            return
        }

        // If the quit app was our selected target, clear selection
        if selectedApp?.id == app.processIdentifier {
            selectedApp = nil
            Self.logger.info("Selected target app quit, clearing selection")
        }

        refreshAvailableApps()
    }

    private func handleAppActivated() {
        refreshAvailableApps()

        if autoTrackFrontmost {
            updateFrontmostApp()
        }
    }

    private func updateFrontmostApp() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.bundleIdentifier != Self.whisperGlassBundleID else {
            return
        }

        let frontmostTarget = TargetApp(
            id: frontmost.processIdentifier,
            bundleIdentifier: frontmost.bundleIdentifier ?? "",
            name: frontmost.localizedName ?? "Unknown",
            isActive: true
        )

        selectedApp = frontmostTarget
    }
}
