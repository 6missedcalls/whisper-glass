import Foundation

/// Represents a running application that can receive injected text.
public struct TargetApp: Identifiable, Sendable, Equatable, Hashable {
    public let id: pid_t
    public let bundleIdentifier: String
    public let name: String
    public let isActive: Bool

    public init(
        id: pid_t,
        bundleIdentifier: String,
        name: String,
        isActive: Bool = false
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.isActive = isActive
    }

    /// Returns a new TargetApp with updated active state.
    public func withActiveState(_ active: Bool) -> TargetApp {
        TargetApp(
            id: id,
            bundleIdentifier: bundleIdentifier,
            name: name,
            isActive: active
        )
    }

    /// Well-known developer tool bundle identifiers for priority sorting.
    public var isDeveloperTool: Bool {
        let devBundles = [
            "com.microsoft.VSCode",
            "com.todesktop.230313mzl4w4u92",  // Cursor
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "com.apple.dt.Xcode",
            "dev.warp.Warp-Stable",
            "co.zeit.hyper",
            "com.github.atom"
        ]
        return devBundles.contains(bundleIdentifier)
    }
}
