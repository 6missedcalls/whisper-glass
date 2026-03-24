import Foundation

/// Strategy for injecting text into a target application.
/// Ordered by preference — each strategy falls back to the next on failure.
public enum InjectionStrategy: String, CaseIterable, Sendable {
    /// Direct insertion via Accessibility API (AXUIElement)
    /// Works for ~80% of apps including most native and Electron apps
    case axDirect

    /// Copy to pasteboard + simulate Cmd+V
    /// Reliable but temporarily clobbers user clipboard (save/restore)
    case clipboard

    /// Simulate individual keystrokes via CGEvent
    /// Slowest but most universal fallback
    case keyboard

    public var label: String {
        switch self {
        case .axDirect: "Accessibility"
        case .clipboard: "Clipboard"
        case .keyboard: "Keyboard"
        }
    }

    /// Returns the next fallback strategy, or nil if this is the last resort.
    public var fallback: InjectionStrategy? {
        switch self {
        case .axDirect: .clipboard
        case .clipboard: .keyboard
        case .keyboard: nil
        }
    }
}
