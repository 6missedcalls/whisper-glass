import Foundation

/// Defines how transcribed text is delivered to the target application.
public enum SendMode: String, CaseIterable, Codable, Sendable {
    /// User manually clicks "Send" or presses hotkey to inject text
    case manual

    /// Text auto-injects into target app as each segment finalizes
    case autoType

    /// Text is copied to clipboard only — user pastes manually
    case clipboard

    public var label: String {
        switch self {
        case .manual: "Manual"
        case .autoType: "Auto-type"
        case .clipboard: "Clipboard"
        }
    }

    public var systemImage: String {
        switch self {
        case .manual: "hand.tap"
        case .autoType: "keyboard"
        case .clipboard: "doc.on.clipboard"
        }
    }
}
