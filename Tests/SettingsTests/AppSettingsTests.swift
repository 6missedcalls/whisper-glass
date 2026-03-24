import Testing
import Foundation
@testable import WhisperGlassCore

@Suite("AppSettings")
struct AppSettingsTests {

    /// Creates an isolated UserDefaults instance for each test to prevent leaking state.
    private func makeSettings() -> AppSettings {
        let suiteName = "com.whisper-glass.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return AppSettings(defaults: defaults)
    }

    // MARK: - Default Values

    @Test("Default selectedModel is base")
    func defaultSelectedModel() {
        let settings = makeSettings()
        #expect(settings.selectedModel == .base)
        #expect(settings.selectedModelRawValue == "base")
    }

    @Test("Default language is en")
    func defaultLanguage() {
        let settings = makeSettings()
        #expect(settings.language == "en")
    }

    @Test("Default autoDetectLanguage is true")
    func defaultAutoDetectLanguage() {
        let settings = makeSettings()
        #expect(settings.autoDetectLanguage == true)
    }

    @Test("Default sendMode is autoType")
    func defaultSendMode() {
        let settings = makeSettings()
        #expect(settings.sendMode == .autoType)
    }

    @Test("Default filterFillerWords is true")
    func defaultFilterFillerWords() {
        let settings = makeSettings()
        #expect(settings.filterFillerWords == true)
    }

    @Test("Default codeMode is false")
    func defaultCodeMode() {
        let settings = makeSettings()
        #expect(settings.codeMode == false)
    }

    @Test("Default windowOpacity is 0.95")
    func defaultWindowOpacity() {
        let settings = makeSettings()
        #expect(settings.windowOpacity == 0.95)
    }

    @Test("Default fontSize is 14")
    func defaultFontSize() {
        let settings = makeSettings()
        #expect(settings.fontSize == 14.0)
    }

    @Test("Default compactMode is false")
    func defaultCompactMode() {
        let settings = makeSettings()
        #expect(settings.compactMode == false)
    }

    @Test("Default launchAtLogin is false")
    func defaultLaunchAtLogin() {
        let settings = makeSettings()
        #expect(settings.launchAtLogin == false)
    }

    @Test("Default showInDock is true")
    func defaultShowInDock() {
        let settings = makeSettings()
        #expect(settings.showInDock == true)
    }

    @Test("Default newlineOnPauseThreshold is 2.0")
    func defaultNewlineOnPauseThreshold() {
        let settings = makeSettings()
        #expect(settings.newlineOnPauseThreshold == 2.0)
    }

    // MARK: - Selected Model Computed Property

    @Test("selectedModel computed property maps from rawValue")
    func selectedModelFromRawValue() {
        let settings = makeSettings()

        for model in WhisperModel.allCases {
            settings.selectedModelRawValue = model.rawValue
            #expect(settings.selectedModel == model)
        }
    }

    @Test("selectedModel setter updates rawValue")
    func selectedModelSetter() {
        let settings = makeSettings()

        settings.selectedModel = .small
        #expect(settings.selectedModelRawValue == "small")

        settings.selectedModel = .largev3Turbo
        #expect(settings.selectedModelRawValue == "largev3Turbo")
    }

    @Test("Invalid selectedModel rawValue falls back to base")
    func invalidSelectedModelFallback() {
        let settings = makeSettings()
        settings.selectedModelRawValue = "nonexistent"
        #expect(settings.selectedModel == .base)
    }

    // MARK: - Send Mode Round-Trip

    @Test("sendMode round-trip through rawValue")
    func sendModeRoundTrip() {
        let settings = makeSettings()

        for mode in SendMode.allCases {
            settings.sendMode = mode
            #expect(settings.sendMode == mode)
            #expect(settings.sendModeRawValue == mode.rawValue)
        }
    }

    @Test("Invalid sendMode rawValue falls back to manual")
    func invalidSendModeFallback() {
        let settings = makeSettings()
        settings.sendModeRawValue = "invalid"
        #expect(settings.sendMode == .manual)
    }

    // MARK: - Derived Properties

    @Test("effectiveLanguage returns nil when autoDetect is on")
    func effectiveLanguageAutoDetect() {
        let settings = makeSettings()
        settings.autoDetectLanguage = true
        #expect(settings.effectiveLanguage == nil)
    }

    @Test("effectiveLanguage returns language when autoDetect is off")
    func effectiveLanguageManual() {
        let settings = makeSettings()
        settings.autoDetectLanguage = false
        settings.language = "es"
        #expect(settings.effectiveLanguage == "es")
    }

    @Test("isLargeModel returns true only for largev3Turbo")
    func isLargeModel() {
        let settings = makeSettings()

        settings.selectedModel = .tiny
        #expect(settings.isLargeModel == false)

        settings.selectedModel = .base
        #expect(settings.isLargeModel == false)

        settings.selectedModel = .small
        #expect(settings.isLargeModel == false)

        settings.selectedModel = .largev3Turbo
        #expect(settings.isLargeModel == true)
    }
}
