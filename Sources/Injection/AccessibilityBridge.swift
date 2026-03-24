import ApplicationServices
import os

/// Wraps macOS Accessibility API (AXUIElement) for text injection.
///
/// All methods perform synchronous AX calls that may block.
/// Callers MUST invoke from a background thread or actor context — never from MainActor.
public enum AccessibilityBridge {

    private static let logger = Logger(
        subsystem: "com.whisper-glass",
        category: "AccessibilityBridge"
    )

    // MARK: - Trusted Check

    /// Returns whether the current process has Accessibility permissions.
    public static func isProcessTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user for Accessibility permissions if not already granted.
    public static func requestTrustIfNeeded() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Focused Element

    /// Returns the currently focused AXUIElement from the system-wide element.
    ///
    /// - Returns: The focused element, or `nil` if none is focused or AX is unavailable.
    public static func getFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )

        guard appResult == .success, let app = focusedApp else {
            logger.warning("Failed to get focused application: \(appResult.rawValue)")
            return nil
        }

        // swiftlint:disable:next force_cast
        let appElement = app as! AXUIElement
        var focusedElement: AnyObject?
        let elementResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard elementResult == .success, let element = focusedElement else {
            logger.warning("Failed to get focused UI element: \(elementResult.rawValue)")
            return nil
        }

        return (element as! AXUIElement)
    }

    // MARK: - Text Insertion

    /// Inserts text into the given AXUIElement by replacing the current selection.
    ///
    /// Uses `kAXSelectedTextAttribute` to overwrite any selected text (or insert at cursor).
    ///
    /// - Parameters:
    ///   - text: The string to insert.
    ///   - element: The target AXUIElement (typically a text field).
    /// - Returns: `true` if the insertion succeeded.
    public static func insertText(_ text: String, into element: AXUIElement) -> Bool {
        let cfText = text as CFString
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            cfText
        )

        if result != .success {
            logger.error("AX text insertion failed with code: \(result.rawValue)")
            return false
        }

        logger.debug("AX text insertion succeeded (\(text.count) characters)")
        return true
    }

    /// Checks whether the given element supports text insertion via AX.
    ///
    /// - Parameter element: The AXUIElement to check.
    /// - Returns: `true` if `kAXSelectedTextAttribute` is settable on the element.
    public static func isTextInsertionSupported(for element: AXUIElement) -> Bool {
        var settable: DarwinBoolean = false
        let result = AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &settable
        )
        return result == .success && settable.boolValue
    }
}
