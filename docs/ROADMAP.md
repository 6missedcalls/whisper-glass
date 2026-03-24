# WhisperGlass — Roadmap & Release Planning

## Mac App Store Release

### Blocker: App Sandbox vs Accessibility
WhisperGlass **cannot ship on the Mac App Store** in its current form because:

1. **AXUIElement text injection** requires the app to be **unsandboxed** — sandboxed apps cannot use Accessibility APIs to control other apps
2. **NSEvent.addGlobalMonitorForEvents** requires Accessibility permission which is restricted in sandbox
3. **CGEvent posting** (Cmd+V simulation) is blocked in sandbox

### Distribution Options

| Channel | Feasible | Notes |
|---------|----------|-------|
| **Mac App Store** | No | Sandbox blocks all injection methods |
| **Developer ID + Notarization** | Yes | Sign with Apple Developer cert ($99/yr), notarize via `xcrun notarytool`, distribute as `.dmg` |
| **Homebrew Cask** | Yes | `brew install --cask whisper-glass` — popular for dev tools |
| **GitHub Releases** | Yes | Free, users accept Gatekeeper warning |
| **SetApp** | Maybe | Third-party store, allows unsandboxed apps |

### Steps for Developer ID Distribution
1. Enroll in Apple Developer Program ($99/year)
2. Create a Developer ID certificate in Xcode
3. Sign the app: `codesign --force --deep --sign "Developer ID Application: Your Name" WhisperGlass.app`
4. Create a DMG: `hdiutil create -volname WhisperGlass -srcfolder WhisperGlass.app -ov WhisperGlass.dmg`
5. Notarize: `xcrun notarytool submit WhisperGlass.dmg --apple-id you@email.com --team-id XXXXXXXXXX --password @keychain:AC_PASSWORD`
6. Staple: `xcrun stapler staple WhisperGlass.dmg`
7. Users download, drag to Applications, grant Accessibility on first launch

---

## Settings Page Plan

### Currently Exists (Sources/App/SettingsView.swift)
- General tab (launch at login, show in dock)
- Audio tab (mic picker, VAD sensitivity)
- Transcription tab (model picker, language, filler word filter)
- Appearance tab (opacity, font size, compact mode)
- Injection tab (send mode, code mode, newline threshold)
- Shortcuts tab (hotkey recorder)

### What Needs Work

**The settings window is wired but never shown because we removed the overlay.**
Need to re-enable it from the menu bar.

### Proposed Settings (Simplified)

Since the app is now a pure dictation tool (no overlay), simplify to 3 tabs:

#### Tab 1: General
- **Dictation hotkey** — Key recorder (current: ⌃⇧Space)
- **Hold vs Toggle mode** — Hold-to-talk (current) or press-to-start/press-to-stop
- **Launch at login** — Toggle
- **Show menu bar icon** — Toggle (maybe hide for minimal footprint)

#### Tab 2: Transcription
- **Model** — Picker with download buttons (Tiny, Base, Small, Large v3 Turbo)
- **Language** — Dropdown (Auto-detect + specific languages)
- **Remove filler words** — Toggle (um, uh, like, etc.)
- **Auto-punctuation** — Toggle (Whisper does this by default)

#### Tab 3: Audio
- **Input device** — Picker (system default + available mics)
- **Sensitivity** — Slider for VAD threshold (how loud before it registers)

---

## Voice Model Options

### Currently Supported
SwiftWhisper with local GGML models:
- `ggml-tiny.bin` (75 MB) — Fast, lower accuracy
- `ggml-base.bin` (142 MB) — Balanced
- `ggml-small.bin` (466 MB) — Good accuracy
- `ggml-large-v3-turbo.bin` (1.5 GB) — Best accuracy

### Future Model Options to Consider

| Model | Type | Pros | Cons |
|-------|------|------|------|
| **OpenAI Whisper API** | Cloud | Best accuracy, no local compute, supports all languages | Requires internet, API key, cost per minute, privacy concern |
| **Whisper.cpp large-v3** | Local | Maximum accuracy | 3GB download, slower on CPU |
| **Distil-Whisper** | Local | 2x faster than standard, 50% smaller | Slightly lower accuracy |
| **Apple Speech Framework** | Local | Built into macOS, no download, fast | Lower accuracy than Whisper, limited languages |
| **Deepgram Nova-3** | Cloud | Very fast, streaming capable | API key, cost, privacy |
| **Groq Whisper** | Cloud | Extremely fast inference | API key, limited availability |
| **MLX Whisper** | Local | Optimized for Apple Silicon via MLX | Requires MLX framework, newer |

### Recommended Next Steps for Models
1. **Add OpenAI Whisper API option** — Best accuracy, users bring their own API key
2. **Add Apple Speech Framework** — Zero download, instant fallback, built-in
3. **Keep local Whisper as default** — Privacy-first, no internet required

### Architecture for Multiple Models
```
Protocol: TranscriptionProvider
  - func transcribe(audioSamples: [Float]) async throws -> [TranscriptSegment]
  - var displayName: String
  - var requiresDownload: Bool
  - var requiresAPIKey: Bool

Implementations:
  - LocalWhisperProvider (current, SwiftWhisper)
  - AppleSpeechProvider (SFSpeechRecognizer)
  - OpenAIWhisperProvider (API call)
  - GroqWhisperProvider (API call)
```

Settings would show a provider picker, and API-based providers would have a field for the API key stored in Keychain.
