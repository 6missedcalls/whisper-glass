import Foundation
import os

// MARK: - UserDefaults Keys

private enum SettingsKey {
    static let selectedModel = "wg_selectedModel"
    static let language = "wg_language"
    static let autoDetectLanguage = "wg_autoDetectLanguage"
    static let sendMode = "wg_sendMode"
    static let filterFillerWords = "wg_filterFillerWords"
    static let codeMode = "wg_codeMode"
    static let windowOpacity = "wg_windowOpacity"
    static let fontSize = "wg_fontSize"
    static let compactMode = "wg_compactMode"
    static let launchAtLogin = "wg_launchAtLogin"
    static let showInDock = "wg_showInDock"
    static let newlineOnPauseThreshold = "wg_newlineOnPauseThreshold"
    static let hotkeyKeyCode = "wg_hotkeyKeyCode"
    static let hotkeyModifiers = "wg_hotkeyModifiers"
}

// MARK: - Defaults

private enum SettingsDefault {
    static let selectedModel = WhisperModel.base.rawValue
    static let language = "en"
    static let autoDetectLanguage = true
    static let sendMode = SendMode.autoType.rawValue
    static let filterFillerWords = true
    static let codeMode = false
    static let windowOpacity = 0.95
    static let fontSize = 14.0
    static let compactMode = false
    static let launchAtLogin = false
    static let showInDock = true
    static let newlineOnPauseThreshold = 2.0
    static let hotkeyKeyCode: UInt16 = 49  // Space
    // Control + Shift bitmask: CGEventFlags.maskControl (0x40000) | CGEventFlags.maskShift (0x20000)
    static let hotkeyModifiers: UInt64 = 0x60000
}

// MARK: - AppSettings

/// Central settings store for WhisperGlass preferences.
/// Uses UserDefaults for persistence. All reads go through computed properties
/// to ensure type safety and default values.
public final class AppSettings: @unchecked Sendable {

    private static let logger = Logger(
        subsystem: "com.whisper-glass",
        category: "AppSettings"
    )

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    // MARK: - Register Defaults

    private func registerDefaults() {
        defaults.register(defaults: [
            SettingsKey.selectedModel: SettingsDefault.selectedModel,
            SettingsKey.language: SettingsDefault.language,
            SettingsKey.autoDetectLanguage: SettingsDefault.autoDetectLanguage,
            SettingsKey.sendMode: SettingsDefault.sendMode,
            SettingsKey.filterFillerWords: SettingsDefault.filterFillerWords,
            SettingsKey.codeMode: SettingsDefault.codeMode,
            SettingsKey.windowOpacity: SettingsDefault.windowOpacity,
            SettingsKey.fontSize: SettingsDefault.fontSize,
            SettingsKey.compactMode: SettingsDefault.compactMode,
            SettingsKey.launchAtLogin: SettingsDefault.launchAtLogin,
            SettingsKey.showInDock: SettingsDefault.showInDock,
            SettingsKey.newlineOnPauseThreshold: SettingsDefault.newlineOnPauseThreshold,
            SettingsKey.hotkeyKeyCode: Int(SettingsDefault.hotkeyKeyCode),
            SettingsKey.hotkeyModifiers: Int(SettingsDefault.hotkeyModifiers),
        ])
    }

    // MARK: - Model

    public var selectedModelRawValue: String {
        get { defaults.string(forKey: SettingsKey.selectedModel) ?? SettingsDefault.selectedModel }
        set { defaults.set(newValue, forKey: SettingsKey.selectedModel) }
    }

    public var selectedModel: WhisperModel {
        get { WhisperModel(rawValue: selectedModelRawValue) ?? .base }
        set { selectedModelRawValue = newValue.rawValue }
    }

    // MARK: - Language

    public var language: String {
        get { defaults.string(forKey: SettingsKey.language) ?? SettingsDefault.language }
        set { defaults.set(newValue, forKey: SettingsKey.language) }
    }

    public var autoDetectLanguage: Bool {
        get { defaults.bool(forKey: SettingsKey.autoDetectLanguage) }
        set { defaults.set(newValue, forKey: SettingsKey.autoDetectLanguage) }
    }

    // MARK: - Send Mode

    public var sendModeRawValue: String {
        get { defaults.string(forKey: SettingsKey.sendMode) ?? SettingsDefault.sendMode }
        set { defaults.set(newValue, forKey: SettingsKey.sendMode) }
    }

    public var sendMode: SendMode {
        get { SendMode(rawValue: sendModeRawValue) ?? .manual }
        set { sendModeRawValue = newValue.rawValue }
    }

    // MARK: - Transcription Options

    public var filterFillerWords: Bool {
        get { defaults.bool(forKey: SettingsKey.filterFillerWords) }
        set { defaults.set(newValue, forKey: SettingsKey.filterFillerWords) }
    }

    public var codeMode: Bool {
        get { defaults.bool(forKey: SettingsKey.codeMode) }
        set { defaults.set(newValue, forKey: SettingsKey.codeMode) }
    }

    // MARK: - Appearance

    public var windowOpacity: Double {
        get { defaults.double(forKey: SettingsKey.windowOpacity) }
        set { defaults.set(newValue, forKey: SettingsKey.windowOpacity) }
    }

    public var fontSize: Double {
        get { defaults.double(forKey: SettingsKey.fontSize) }
        set { defaults.set(newValue, forKey: SettingsKey.fontSize) }
    }

    public var compactMode: Bool {
        get { defaults.bool(forKey: SettingsKey.compactMode) }
        set { defaults.set(newValue, forKey: SettingsKey.compactMode) }
    }

    // MARK: - System

    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: SettingsKey.launchAtLogin) }
        set { defaults.set(newValue, forKey: SettingsKey.launchAtLogin) }
    }

    public var showInDock: Bool {
        get { defaults.bool(forKey: SettingsKey.showInDock) }
        set { defaults.set(newValue, forKey: SettingsKey.showInDock) }
    }

    public var newlineOnPauseThreshold: Double {
        get { defaults.double(forKey: SettingsKey.newlineOnPauseThreshold) }
        set { defaults.set(newValue, forKey: SettingsKey.newlineOnPauseThreshold) }
    }

    // MARK: - Hotkey

    public var hotkeyKeyCode: UInt16 {
        get { UInt16(clamping: defaults.integer(forKey: SettingsKey.hotkeyKeyCode)) }
        set { defaults.set(Int(newValue), forKey: SettingsKey.hotkeyKeyCode) }
    }

    public var hotkeyModifiers: UInt64 {
        get {
            let stored = defaults.object(forKey: SettingsKey.hotkeyModifiers)
            guard let value = stored as? Int else {
                return SettingsDefault.hotkeyModifiers
            }
            return UInt64(value)
        }
        set { defaults.set(Int(newValue), forKey: SettingsKey.hotkeyModifiers) }
    }

    /// Human-readable description of the current hotkey (e.g., "⌃⇧Space")
    public var hotkeyDescription: String {
        let modifierString = Self.modifierSymbols(from: hotkeyModifiers)
        let keyName = Self.keyCodeName(for: hotkeyKeyCode)
        return modifierString + keyName
    }

    /// Resets the hotkey to the default ⌃⇧Space binding.
    public func resetHotkeyToDefault() {
        hotkeyKeyCode = SettingsDefault.hotkeyKeyCode
        hotkeyModifiers = SettingsDefault.hotkeyModifiers
    }

    // MARK: - Hotkey Display Helpers

    /// Converts a modifier bitmask (CGEventFlags raw value) to symbol string.
    /// Order: ⌃ Control, ⌥ Option, ⇧ Shift, ⌘ Command (matching macOS convention).
    public static func modifierSymbols(from flags: UInt64) -> String {
        var symbols = ""
        // CGEventFlags: maskControl = 0x40000, maskAlternate = 0x80000,
        //               maskShift = 0x20000, maskCommand = 0x100000
        if flags & 0x40000 != 0 { symbols += "⌃" }
        if flags & 0x80000 != 0 { symbols += "⌥" }
        if flags & 0x20000 != 0 { symbols += "⇧" }
        if flags & 0x100000 != 0 { symbols += "⌘" }
        return symbols
    }

    /// Converts a virtual key code to a human-readable display name.
    public static func keyCodeName(for keyCode: UInt16) -> String {
        keyCodeDisplayNames[keyCode] ?? "Key\(keyCode)"
    }

    // swiftlint:disable:next identifier_name
    private static let keyCodeDisplayNames: [UInt16: String] = [
        // Letters (QWERTY layout)
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H",
        5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
        21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
        31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
        47: ".", 50: "`",
        // Special keys
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete",
        53: "Escape", 71: "Clear", 76: "Enter",
        // Arrow keys
        123: "←", 124: "→", 125: "↓", 126: "↑",
        // Function keys
        122: "F1", 120: "F2", 99: "F3", 118: "F4",
        96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    // MARK: - Derived Properties

    /// Effective language to use — returns `nil` when auto-detect is enabled,
    /// signaling the Whisper engine should detect language automatically.
    public var effectiveLanguage: String? {
        autoDetectLanguage ? nil : language
    }

    /// Whether the current model is a large variant that requires more resources.
    public var isLargeModel: Bool {
        selectedModel == .largev3Turbo
    }
}
