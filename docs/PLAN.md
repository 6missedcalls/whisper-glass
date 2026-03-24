# WhisperGlass — Implementation Plan

> Real-time speech transcription with Liquid Glass UI and cross-app text injection for macOS Tahoe

## Requirements Restatement

Build a native macOS app (macOS Tahoe 26+) that:

1. **Captures microphone audio** and transcribes it in real-time using on-device Whisper (SwiftWhisper / whisper.cpp + CoreML)
2. **Displays transcription** in a floating, always-on-top overlay with Apple's Liquid Glass aesthetic — chat-bubble layout, fluid animations, refined typography
3. **Injects transcribed text** into developer tools (VSCode, Terminal/Claude Code, Codex CLI, any text field) via the macOS Accessibility API (`AXUIElement`) or clipboard-paste fallback
4. **Lives in the menu bar** with global hotkey toggle, minimal footprint, and a beautiful Liquid Glass control panel

---

## Phase 0 — Project Scaffold & Tooling

**Goal**: Xcode project, Swift Package dependencies, CI basics.

| Task | Details |
|------|---------|
| Create Xcode project | macOS App, SwiftUI lifecycle, deployment target macOS 26.0 |
| Add Swift Package deps | `SwiftWhisper` (whisper.cpp Swift wrapper), no other heavy deps needed |
| Entitlements | Microphone access, Accessibility (AX) access, App Sandbox **disabled** (required for AX injection) |
| Code signing | Developer ID for distribution outside App Store (AX requires non-sandboxed) |
| Directory structure | See [ARCHITECTURE.md](./ARCHITECTURE.md) |

**Deliverables**: Empty app launches, dependencies resolve, entitlements configured.

---

## Phase 1 — Audio Capture Pipeline

**Goal**: Capture mic audio in real-time, buffer it for Whisper consumption.

### 1.1 — Microphone Permission & Device Selection

- Request microphone access via `AVCaptureDevice.requestAccess(for: .audio)`
- Enumerate audio input devices with `AVCaptureDevice.DiscoverySession`
- Allow user to select preferred mic in Settings (default: system default)
- Store selection in `UserDefaults`

### 1.2 — Audio Capture Engine

- Use `AVAudioEngine` with an input node tap
- Configure format: 16kHz mono Float32 (Whisper's native format)
- Use `AVAudioConverter` if hardware sample rate differs
- Ring buffer implementation for sliding-window audio chunks
- Voice Activity Detection (VAD): energy-threshold gate to skip silence
  - Implement RMS-based energy gate (whisper.cpp has basic VAD support via `--vad` flag)

### 1.3 — Audio Session Management

- Handle interruptions (calls, other apps claiming mic)
- Handle route changes (headset plugged in, Bluetooth switch)
- Graceful start/stop without audio glitches

**Files**:
```
Sources/Audio/AudioCaptureEngine.swift      — AVAudioEngine wrapper
Sources/Audio/AudioBufferRing.swift         — Ring buffer for chunked audio
Sources/Audio/VoiceActivityDetector.swift   — VAD gate
Sources/Audio/AudioDeviceManager.swift      — Device enumeration & selection
```

**Risks**:
- **MEDIUM**: Sample rate mismatch between hardware and Whisper (16kHz). Mitigation: `AVAudioConverter`.
- **LOW**: Mic permission denied. Mitigation: Clear permission prompt + Settings deep-link.

---

## Phase 2 — On-Device Whisper Transcription

**Goal**: Feed audio buffers to SwiftWhisper (whisper.cpp), get streaming text back.

### 2.1 — SwiftWhisper Integration

- Initialize `Whisper` with a GGML model file (`.bin` format from Hugging Face)
- Models: `ggml-tiny.bin`, `ggml-base.bin`, `ggml-small.bin`, `ggml-large-v3-turbo.bin`
- Model downloaded on first launch from Hugging Face, cached in Application Support
- Model size selector in Settings (tiny → large-v3-turbo) for speed/accuracy tradeoff
- Enable CoreML acceleration via whisper.cpp's `--use-coreml` flag for Neural Engine offload

### 2.2 — Streaming Transcription Loop

- Sliding window: 3-second audio chunks with 0.5s overlap
- Feed chunks to `Whisper.transcribe(audioFrames:)` on a dedicated background queue
- Merge overlapping results using timestamp alignment
- Emit partial (in-progress) and final (committed) segments
- Language auto-detection or user-specified language

### 2.3 — Transcription State Machine

```
States: .idle → .listening → .transcribing → .paused
Events: startRecording, audioChunkReady, transcriptionResult, pause, resume, stop
```

- `@Observable` class `TranscriptionEngine` publishes:
  - `segments: [TranscriptSegment]` — finalized text
  - `partialText: String` — in-progress hypothesis
  - `isListening: Bool`
  - `currentLanguage: String`

### 2.4 — Performance Targets

| Metric | Target |
|--------|--------|
| Latency (chunk → text) | < 500ms on M1, < 300ms on M3+ |
| Memory footprint | < 500MB (large-v3-turbo), < 200MB (tiny) |
| CPU/Neural Engine usage | < 30% sustained |

**Files**:
```
Sources/Transcription/TranscriptionEngine.swift    — Main engine (@Observable)
Sources/Transcription/WhisperBridge.swift           — SwiftWhisper initialization & config
Sources/Transcription/TranscriptSegment.swift      — Data model for segments
Sources/Transcription/SegmentMerger.swift          — Overlap deduplication
Sources/Transcription/ModelManager.swift           — Download GGML models from Hugging Face, cache
```

**Risks**:
- **HIGH**: First-launch model download is 1-3GB. Mitigation: Progress UI, background download, start with `tiny` model.
- **MEDIUM**: Latency spikes during thermal throttling. Mitigation: Adaptive chunk sizing, model fallback.
- **LOW**: Language detection flaky for short utterances. Mitigation: Allow manual language lock.

---

## Phase 3 — Liquid Glass UI

**Goal**: Beautiful floating overlay with Apple's Liquid Glass design language.

### 3.1 — Floating Overlay Window

- `NSPanel` with `.nonactivatingPanel` style (doesn't steal focus from target app)
- `.floating` window level (always on top)
- Draggable via title bar region
- Resizable with min/max constraints
- Remembers position/size across launches (`UserDefaults`)
- Rounded corners matching Liquid Glass spec

### 3.2 — Glass Effect Container

- Wrap main content in `GlassEffectContainer` (macOS Tahoe API)
- Apply `.glassEffect()` modifier to panels, controls, and chrome
- Use `.regularMaterial` / `.thinMaterial` vibrancy as fallback for pre-Tahoe
- Light-bending (lensing) effect on the overlay background
- Specular highlights that respond to mouse position / window movement

### 3.3 — Chat Bubble Transcript View

- `ScrollViewReader` + `LazyVStack` for efficient rendering of long transcripts
- Auto-scroll to bottom on new segments
- Each segment rendered as a glass bubble:
  ```swift
  TranscriptBubble(segment)
      .glassEffect(.regular)
      .padding(.horizontal, 12)
  ```
- Partial (in-progress) text shown with a pulsing opacity animation
- Timestamps shown on hover or as subtle side labels
- Speaker diarization labels when available (future)

### 3.4 — Control Bar

- Bottom-pinned Liquid Glass toolbar:
  - Record / Pause / Stop toggle (SF Symbols with spring animation)
  - Target app selector (dropdown showing running apps with text fields)
  - Send mode toggle: `Manual` / `Auto-type` / `Clipboard`
  - Language indicator
  - Model indicator (tiny/base/large)
- Glowing mic indicator when actively recording (red pulse)

### 3.5 — Menu Bar Presence

- `MenuBarExtra` with a mic icon (filled when recording)
- Dropdown shows:
  - Quick toggle record
  - Recent transcript snippet
  - Open main window
  - Settings
  - Quit

### 3.6 — Animations & Polish

- Spring animations for bubble appearance (`transition: .asymmetric`)
- Smooth scroll with `withAnimation(.easeOut)`
- Liquid Glass shimmer on hover over controls
- Subtle haptic-like scale feedback on buttons (`.scaleEffect` on press)
- Typing indicator animation (three dots) while Whisper processes

**Files**:
```
Sources/UI/WhisperGlassApp.swift              — @main App, MenuBarExtra
Sources/UI/OverlayWindow.swift                — NSPanel configuration
Sources/UI/TranscriptView.swift               — Main chat-bubble scroll view
Sources/UI/TranscriptBubble.swift             — Individual segment bubble
Sources/UI/PartialTextView.swift              — In-progress hypothesis display
Sources/UI/ControlBar.swift                   — Bottom toolbar
Sources/UI/TargetAppPicker.swift              — App selector dropdown
Sources/UI/SettingsView.swift                 — Preferences window
Sources/UI/Components/GlassPill.swift         — Reusable glass pill button
Sources/UI/Components/PulsingIndicator.swift  — Recording indicator
Sources/UI/Components/ShimmerModifier.swift   — Hover shimmer effect
```

**Risks**:
- **HIGH**: Liquid Glass APIs are macOS Tahoe 26+ only. Mitigation: `@available` checks, vibrancy fallback for Ventura/Sonoma.
- **MEDIUM**: `NSPanel` focus behavior with Accessibility injection is tricky. Mitigation: Extensive testing with target apps.
- **LOW**: ScrollView performance with thousands of segments. Mitigation: `LazyVStack`, segment compaction for old entries.

---

## Phase 4 — Cross-App Text Injection

**Goal**: Send transcribed text into VSCode, Terminal, Claude Code, Codex, or any focused text field.

### 4.1 — Accessibility API Bridge

- `AXUIElementCreateSystemWide()` → `kAXFocusedUIElementAttribute` → get focused text field
- Insert text via `AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute, text)`
- Must run **off main thread** (AX calls block on main thread = freeze)
- Requires user to grant Accessibility permission in System Settings

### 4.2 — Target App Manager

- Enumerate running apps via `NSWorkspace.shared.runningApplications`
- Filter to apps with visible windows that accept text input
- Show app icon + name in the TargetAppPicker
- "Auto" mode: inject into whatever app is frontmost (excluding WhisperGlass itself)
- "Pinned" mode: always inject into a specific app regardless of focus

### 4.3 — Injection Strategies (Priority Order)

| Strategy | How | When |
|----------|-----|------|
| **AX Direct Insert** | `kAXSelectedTextAttribute` on focused element | Works for most native + Electron apps (VSCode, terminals) |
| **Clipboard + Paste** | Copy to pasteboard → simulate `Cmd+V` via `CGEvent` | Fallback when AX insert fails |
| **Keyboard Simulation** | `CGEvent` key-down/key-up for each character | Last resort, handles apps that block paste |

### 4.4 — Send Modes

- **Manual**: User clicks "Send" or presses hotkey to inject accumulated text
- **Auto-type (Live Dictation)**: Each finalized segment auto-injects as it's transcribed — feels like real-time dictation into the target app
- **Clipboard Only**: Just copies to clipboard, user pastes manually

### 4.5 — Smart Formatting

- Auto-capitalize sentence starts
- Auto-punctuation (Whisper already does this well)
- Optional: strip filler words ("um", "uh", "like")
- Newline insertion on long pauses (configurable threshold)
- Code mode: disable auto-capitalize, preserve exact Whisper output

### 4.6 — Global Hotkeys

- `⌥Space` — Toggle recording on/off (configurable)
- `⌥Return` — Send current transcript to target app
- `⌥⌫` — Clear current transcript
- Implemented via `NSEvent.addGlobalMonitorForEvents` + `CGEvent` tap
- Hotkey customization in Settings

**Files**:
```
Sources/Injection/AccessibilityBridge.swift     — AXUIElement wrapper
Sources/Injection/TextInjector.swift            — Strategy pattern for injection
Sources/Injection/ClipboardInjector.swift       — Pasteboard + Cmd+V
Sources/Injection/KeyboardSimulator.swift       — CGEvent keystroke sim
Sources/Injection/TargetAppManager.swift        — Running app enumeration
Sources/Injection/SmartFormatter.swift          — Text cleanup & formatting
Sources/Injection/HotkeyManager.swift           — Global hotkey registration
```

**Risks**:
- **CRITICAL**: App Sandbox must be **disabled** for AX injection to work. This means no Mac App Store distribution — must use Developer ID or direct download.
- **HIGH**: Some Electron apps (VSCode) have inconsistent AX support. Mitigation: Clipboard+Paste fallback auto-triggers on AX failure.
- **MEDIUM**: macOS may prompt for Accessibility permission repeatedly after updates. Mitigation: Clear onboarding flow, permission check on launch.
- **MEDIUM**: `CGEvent` keyboard simulation may be blocked by apps with secure input (password fields). Mitigation: Detect secure input fields, warn user.

---

## Phase 5 — Settings & Persistence

**Goal**: Comprehensive but clean settings panel.

### 5.1 — Settings Sections

| Section | Options |
|---------|---------|
| **Audio** | Input device, noise gate threshold, VAD sensitivity |
| **Transcription** | Model size, language, auto-detect toggle, filler word filter |
| **Appearance** | Window opacity, bubble style, font size, compact/expanded mode |
| **Injection** | Default send mode, target app, formatting options, code mode |
| **Hotkeys** | Customize all global shortcuts |
| **Advanced** | Log level, export transcript, reset to defaults |

### 5.2 — Data Persistence

- `@AppStorage` / `UserDefaults` for all settings
- Transcript history: SQLite via SwiftData (macOS 14+) or flat JSON files
- Export transcript as `.txt`, `.srt` (subtitles), or `.json`

**Files**:
```
Sources/Settings/AppSettings.swift        — @Observable settings model
Sources/Settings/SettingsView.swift        — Settings window (TabView)
Sources/Storage/TranscriptStore.swift      — SwiftData persistence
Sources/Storage/TranscriptExporter.swift   — Export formats
```

---

## Phase 6 — Onboarding & Permissions

**Goal**: First-run experience that guides users through required permissions.

### 6.1 — Onboarding Flow

1. **Welcome** — App purpose, quick preview animation
2. **Microphone** — Request mic permission with explanation
3. **Accessibility** — Guide user to System Settings > Privacy > Accessibility, with deep-link button
4. **Model Download** — Select model size, show download progress
5. **Quick Tutorial** — Show hotkeys, demonstrate send modes
6. **Ready** — Drop into main overlay

### 6.2 — Permission Health Check

- On every launch, verify mic + accessibility permissions
- If revoked, show non-intrusive banner with re-enable instructions
- `AXIsProcessTrusted()` check for accessibility status

**Files**:
```
Sources/Onboarding/OnboardingView.swift         — Multi-step onboarding
Sources/Onboarding/PermissionChecker.swift       — Runtime permission validation
Sources/Onboarding/ModelDownloadView.swift       — Download progress UI
```

---

## Phase 7 — Testing & Polish

### 7.1 — Unit Tests

- `AudioBufferRing` — correct chunking, overflow handling
- `SegmentMerger` — deduplication accuracy
- `SmartFormatter` — capitalization, filler removal
- `AppSettings` — persistence round-trip
- **Target: 80%+ coverage on non-UI code**

### 7.2 — Integration Tests

- `TranscriptionEngine` — end-to-end audio → text with test WAV files
- `TextInjector` — AX injection into a test app
- `HotkeyManager` — hotkey registration and callback

### 7.3 — Manual Testing Matrix

| Target App | AX Direct | Clipboard | Keyboard Sim |
|------------|-----------|-----------|--------------|
| Terminal.app | Test | Test | Test |
| iTerm2 | Test | Test | Test |
| VSCode | Test | Test | Test |
| Cursor | Test | Test | Test |
| Xcode | Test | Test | Test |
| TextEdit | Test | Test | Test |
| Safari (address bar) | Test | Test | Test |

### 7.4 — Performance Testing

- Memory profiling with Instruments (Allocations)
- CPU/Neural Engine profiling (Time Profiler + CoreML Instrument)
- Thermal throttling behavior under sustained use
- Battery impact measurement

---

## Dependency Summary

| Dependency | Purpose | Version |
|------------|---------|---------|
| [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper) | On-device Whisper via whisper.cpp | Latest (SPM) |
| AVFoundation (system) | Audio capture | macOS 26 SDK |
| ApplicationServices (system) | Accessibility API | macOS 26 SDK |
| SwiftUI + Liquid Glass (system) | UI framework | macOS 26 SDK |
| SwiftData (system) | Transcript persistence | macOS 14+ |

**No other third-party dependencies.** Everything else is system frameworks.

---

## Risk Summary

| Risk | Severity | Mitigation |
|------|----------|------------|
| No Mac App Store (sandbox disabled) | CRITICAL | Distribute via Developer ID, Homebrew cask, or GitHub Releases |
| First-launch model download (1-3GB) | HIGH | Progress UI, default to `tiny` model, background download |
| Liquid Glass requires macOS Tahoe 26 | HIGH | `@available` checks, vibrancy fallback path |
| Electron app AX inconsistency | HIGH | Auto-fallback to clipboard strategy |
| AX permission UX friction | MEDIUM | Guided onboarding with deep-links |
| Thermal throttling on sustained use | MEDIUM | Adaptive model selection, chunk size tuning |
| Secure input field blocking | MEDIUM | Detect and warn user |

---

## Complexity Assessment

| Area | Complexity | Effort |
|------|-----------|--------|
| Audio pipeline | Medium | Phase 1 |
| SwiftWhisper integration | Medium | Phase 2 |
| Liquid Glass UI | High | Phase 3 |
| Cross-app injection | High | Phase 4 |
| Settings & persistence | Low | Phase 5 |
| Onboarding | Low | Phase 6 |
| Testing | Medium | Phase 7 |

**Overall Complexity: HIGH**

---

## Recommended Implementation Order

```
Phase 0 (Scaffold)        ████░░░░░░░░░░░░░░░░  Day 1
Phase 1 (Audio)           ████████░░░░░░░░░░░░  Days 2-3
Phase 2 (Transcription)   ████████████░░░░░░░░  Days 4-6
Phase 3 (Liquid Glass UI) ████████████████░░░░  Days 7-11
Phase 4 (App Injection)   ██████████████████░░  Days 12-15
Phase 5 (Settings)        ███████████████████░  Days 16-17
Phase 6 (Onboarding)      ████████████████████  Days 18-19
Phase 7 (Testing)         ████████████████████  Days 19-22
```

---

**WAITING FOR CONFIRMATION**: Proceed with this plan? (yes / no / modify)
