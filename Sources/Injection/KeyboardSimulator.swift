import Carbon
import CoreGraphics
import Foundation
import os

/// Injects text by simulating individual keystrokes via CGEvent.
///
/// This is the slowest injection strategy but works with virtually all applications.
public struct KeyboardSimulator: TextInjectionStrategy, Sendable {
    public let strategyType: InjectionStrategy = .keyboard

    private static let logger = Logger(
        subsystem: "com.whisper-glass",
        category: "KeyboardSimulator"
    )

    /// Delay between individual keystrokes in nanoseconds.
    private static let interKeystrokeDelay: UInt64 = 10_000_000 // 10ms

    public init() {}

    public func inject(text: String) async -> Bool {
        await simulateTyping(text)
    }

    /// Simulates typing the given text character by character via CGEvent.
    ///
    /// - Parameter text: The string to type.
    /// - Returns: `true` if all keystrokes were successfully posted.
    public func simulateTyping(_ text: String) async -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            Self.logger.error("Failed to create CGEventSource")
            return false
        }

        for character in text {
            let typed = simulateCharacter(character, source: source)
            if !typed {
                Self.logger.error("Failed to type character: \(String(character))")
                return false
            }
            try? await Task.sleep(nanoseconds: Self.interKeystrokeDelay)
        }

        Self.logger.debug("Keyboard simulation completed (\(text.count) characters)")
        return true
    }

    // MARK: - Private

    /// Simulates a single character keystroke.
    ///
    /// Uses CGEvent's Unicode string input for characters that don't map
    /// to simple virtual key codes.
    private func simulateCharacter(
        _ character: Character,
        source: CGEventSource
    ) -> Bool {
        let mapping = KeyCodeMapping.lookup(character)

        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: mapping.keyCode,
            keyDown: true
        ),
        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: mapping.keyCode,
            keyDown: false
        ) else {
            return false
        }

        if mapping.requiresShift {
            keyDown.flags = .maskShift
            keyUp.flags = .maskShift
        }

        // For characters not in our keycode map, use Unicode string input
        if mapping.useUnicodeInput {
            var utf16 = Array(String(character).utf16)
            keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }
}

// MARK: - Key Code Mapping

/// Maps characters to virtual key codes and modifier requirements.
public enum KeyCodeMapping {

    /// Result of looking up a character's key code.
    public struct Result: Sendable {
        public let keyCode: CGKeyCode
        public let requiresShift: Bool
        public let useUnicodeInput: Bool

        public init(keyCode: CGKeyCode, requiresShift: Bool, useUnicodeInput: Bool = false) {
            self.keyCode = keyCode
            self.requiresShift = requiresShift
            self.useUnicodeInput = useUnicodeInput
        }
    }

    /// US QWERTY key code map for common characters.
    private static let keyCodes: [Character: CGKeyCode] = [
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04,
        "g": 0x05, "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09,
        "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F,
        "y": 0x10, "t": 0x11, "u": 0x20, "i": 0x22, "p": 0x23,
        "l": 0x25, "j": 0x26, "k": 0x28, "n": 0x2D, "m": 0x2E,
        "o": 0x1F,
        "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
        "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,
        " ": 0x31, "\t": 0x30, "\n": 0x24,
        "-": 0x1B, "=": 0x18, "[": 0x21, "]": 0x1E,
        ";": 0x29, "'": 0x27, ",": 0x2B, ".": 0x2F,
        "/": 0x2C, "\\": 0x2A, "`": 0x32
    ]

    /// Characters that require the Shift modifier.
    private static let shiftedCharacters: [Character: Character] = [
        "A": "a", "B": "b", "C": "c", "D": "d", "E": "e",
        "F": "f", "G": "g", "H": "h", "I": "i", "J": "j",
        "K": "k", "L": "l", "M": "m", "N": "n", "O": "o",
        "P": "p", "Q": "q", "R": "r", "S": "s", "T": "t",
        "U": "u", "V": "v", "W": "w", "X": "x", "Y": "y", "Z": "z",
        "!": "1", "@": "2", "#": "3", "$": "4", "%": "5",
        "^": "6", "&": "7", "*": "8", "(": "9", ")": "0",
        "_": "-", "+": "=", "{": "[", "}": "]",
        ":": ";", "\"": "'", "<": ",", ">": ".",
        "?": "/", "|": "\\", "~": "`"
    ]

    /// Looks up the key code and modifiers for the given character.
    ///
    /// Falls back to Unicode input for characters not in the US QWERTY map.
    public static func lookup(_ character: Character) -> Result {
        // Check direct map (lowercase letters, digits, common punctuation)
        if let keyCode = keyCodes[character] {
            return Result(keyCode: keyCode, requiresShift: false)
        }

        // Check shifted characters
        if let baseChar = shiftedCharacters[character],
           let keyCode = keyCodes[baseChar] {
            return Result(keyCode: keyCode, requiresShift: true)
        }

        // Fallback: use Unicode string input with a dummy key code
        return Result(keyCode: 0x31, requiresShift: false, useUnicodeInput: true)
    }
}
