import SwiftUI
import WhisperGlassCore

// MARK: - Settings View

struct SettingsView: View {

    let appSettings: AppSettings
    let audioDeviceManager: AudioDeviceManager

    var body: some View {
        TabView {
            GeneralTab(appSettings: appSettings)
                .tabItem { Label("General", systemImage: "gear") }

            AudioTab(audioDeviceManager: audioDeviceManager)
                .tabItem { Label("Audio", systemImage: "waveform") }

            TranscriptionTab(appSettings: appSettings)
                .tabItem { Label("Transcription", systemImage: "text.bubble") }
        }
        .frame(width: 420, height: 300)
    }
}

// MARK: - General

private struct GeneralTab: View {
    let appSettings: AppSettings

    @State private var launchAtLogin = false
    @State private var hotkeyKeyCode: UInt16 = 49
    @State private var hotkeyModifiers: UInt64 = 0x60000

    var body: some View {
        Form {
            Section("Dictation Shortcut") {
                HStack {
                    Text("Hotkey")
                    Spacer()
                    HotkeyRecorderView(
                        keyCode: $hotkeyKeyCode,
                        modifiers: $hotkeyModifiers
                    )
                }
                .onChange(of: hotkeyKeyCode) { _, val in appSettings.hotkeyKeyCode = val }
                .onChange(of: hotkeyModifiers) { _, val in appSettings.hotkeyModifiers = val }

                Text("Hold to record, release to transcribe and paste")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Reset to Default (⌃⇧Space)") {
                    appSettings.resetHotkeyToDefault()
                    hotkeyKeyCode = appSettings.hotkeyKeyCode
                    hotkeyModifiers = appSettings.hotkeyModifiers
                }
                .font(.caption)
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, val in appSettings.launchAtLogin = val }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = appSettings.launchAtLogin
            hotkeyKeyCode = appSettings.hotkeyKeyCode
            hotkeyModifiers = appSettings.hotkeyModifiers
        }
    }
}

// MARK: - Audio

private struct AudioTab: View {
    let audioDeviceManager: AudioDeviceManager

    @State private var selectedDeviceId: String?

    var body: some View {
        Form {
            Section("Input Device") {
                if audioDeviceManager.availableDevices.isEmpty {
                    Text("No audio input devices found")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Microphone", selection: $selectedDeviceId) {
                        Text("System Default")
                            .tag(nil as String?)

                        ForEach(audioDeviceManager.availableDevices) { device in
                            HStack {
                                Text(device.name)
                                if device.isDefault {
                                    Text("(Default)")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .tag(device.id as String?)
                        }
                    }
                    .onChange(of: selectedDeviceId) { _, val in
                        audioDeviceManager.preferredDeviceId = val
                    }
                }

                Button("Refresh Devices") {
                    audioDeviceManager.refreshDevices()
                }
                .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            selectedDeviceId = audioDeviceManager.preferredDeviceId
        }
    }
}

// MARK: - Transcription

private struct TranscriptionTab: View {
    let appSettings: AppSettings

    @State private var selectedModel: WhisperModel = .base
    @State private var language: String = "en"
    @State private var filterFillerWords = true

    var body: some View {
        Form {
            Section("Model") {
                Picker("Whisper Model", selection: $selectedModel) {
                    ForEach(WhisperModel.allCases) { model in
                        Text("\(model.displayName) (\(model.sizeLabel))")
                            .tag(model)
                    }
                }
                .onChange(of: selectedModel) { _, val in appSettings.selectedModel = val }
            }

            Section("Language") {
                TextField("Language Code", text: $language)
                    .onChange(of: language) { _, val in appSettings.language = val }
                Text("Use \"en\" for English, \"auto\" for auto-detect")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Processing") {
                Toggle("Remove Filler Words", isOn: $filterFillerWords)
                    .onChange(of: filterFillerWords) { _, val in appSettings.filterFillerWords = val }
                Text("Removes \"um\", \"uh\", \"like\", etc.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            selectedModel = appSettings.selectedModel
            language = appSettings.language
            filterFillerWords = appSettings.filterFillerWords
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    SettingsView(appSettings: AppSettings(), audioDeviceManager: AudioDeviceManager())
}
#endif
