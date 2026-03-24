# WhisperGlass — Architecture

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    WhisperGlass App                       │
│                                                          │
│  ┌──────────┐    ┌──────────────┐    ┌───────────────┐  │
│  │  Audio    │───▶│ Transcription│───▶│   UI Layer    │  │
│  │  Pipeline │    │   Engine     │    │ (Liquid Glass)│  │
│  └──────────┘    └──────┬───────┘    └───────┬───────┘  │
│                         │                     │          │
│                         ▼                     ▼          │
│                  ┌──────────────┐    ┌───────────────┐  │
│                  │  Transcript  │    │   Injection   │  │
│                  │    Store     │    │    Engine     │  │
│                  └──────────────┘    └───────────────┘  │
│                                                          │
│  ┌──────────┐    ┌──────────────┐    ┌───────────────┐  │
│  │  Hotkey  │    │   Settings   │    │  Onboarding   │  │
│  │  Manager │    │   Manager    │    │    Flow       │  │
│  └──────────┘    └──────────────┘    └───────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Directory Structure

```
WhisperGlass/
├── WhisperGlass.xcodeproj
├── Sources/
│   ├── App/
│   │   ├── WhisperGlassApp.swift          # @main entry, MenuBarExtra
│   │   └── AppDelegate.swift              # NSApplicationDelegate for panel management
│   │
│   ├── Audio/
│   │   ├── AudioCaptureEngine.swift       # AVAudioEngine mic capture
│   │   ├── AudioBufferRing.swift          # Ring buffer for chunked audio
│   │   ├── VoiceActivityDetector.swift    # Energy-based VAD gate
│   │   └── AudioDeviceManager.swift       # Input device enumeration
│   │
│   ├── Transcription/
│   │   ├── TranscriptionEngine.swift      # @Observable main engine
│   │   ├── WhisperBridge.swift             # SwiftWhisper setup & configuration
│   │   ├── TranscriptSegment.swift        # Segment data model
│   │   ├── SegmentMerger.swift            # Overlap deduplication
│   │   └── ModelManager.swift             # GGML model download & caching
│   │
│   ├── Injection/
│   │   ├── AccessibilityBridge.swift      # AXUIElement wrapper
│   │   ├── TextInjector.swift             # Injection strategy coordinator
│   │   ├── ClipboardInjector.swift        # Pasteboard + Cmd+V sim
│   │   ├── KeyboardSimulator.swift        # CGEvent keystroke sim
│   │   ├── TargetAppManager.swift         # Running app enumeration
│   │   ├── SmartFormatter.swift           # Text formatting & cleanup
│   │   └── HotkeyManager.swift           # Global hotkey registration
│   │
│   ├── UI/
│   │   ├── OverlayWindow.swift            # NSPanel floating window
│   │   ├── TranscriptView.swift           # Chat-bubble scroll view
│   │   ├── TranscriptBubble.swift         # Individual segment bubble
│   │   ├── PartialTextView.swift          # In-progress hypothesis
│   │   ├── ControlBar.swift               # Bottom toolbar
│   │   ├── TargetAppPicker.swift          # App selector dropdown
│   │   ├── SettingsView.swift             # Preferences (TabView)
│   │   └── Components/
│   │       ├── GlassPill.swift            # Reusable glass pill button
│   │       ├── PulsingIndicator.swift     # Recording indicator
│   │       └── ShimmerModifier.swift      # Hover shimmer effect
│   │
│   ├── Onboarding/
│   │   ├── OnboardingView.swift           # Multi-step first-run flow
│   │   ├── PermissionChecker.swift        # Mic + AX permission validation
│   │   └── ModelDownloadView.swift        # Model download progress
│   │
│   ├── Settings/
│   │   └── AppSettings.swift              # @Observable settings model
│   │
│   ├── Storage/
│   │   ├── TranscriptStore.swift          # SwiftData persistence
│   │   └── TranscriptExporter.swift       # Export to txt/srt/json
│   │
│   └── Models/
│       ├── SendMode.swift                 # Manual / AutoType / Clipboard
│       ├── InjectionStrategy.swift        # AXDirect / Clipboard / Keyboard
│       └── TranscriptionState.swift       # Idle / Listening / Transcribing / Paused
│
├── Tests/
│   ├── AudioTests/
│   │   └── AudioBufferRingTests.swift
│   ├── TranscriptionTests/
│   │   ├── SegmentMergerTests.swift
│   │   └── TranscriptionEngineTests.swift
│   ├── InjectionTests/
│   │   ├── SmartFormatterTests.swift
│   │   └── TextInjectorTests.swift
│   └── SettingsTests/
│       └── AppSettingsTests.swift
│
├── Resources/
│   ├── Assets.xcassets/                   # App icon, SF Symbol overrides
│   ├── WhisperGlass.entitlements          # Mic, AX, network (model download)
│   └── Info.plist
│
├── Package.swift                          # SPM for SwiftWhisper dependency
└── README.md
```

## Data Flow

```
Microphone
    │
    ▼
AudioCaptureEngine (AVAudioEngine, 16kHz mono)
    │
    ▼
AudioBufferRing (3s chunks, 0.5s overlap)
    │
    ├──▶ VoiceActivityDetector (skip silence)
    │
    ▼
TranscriptionEngine (@Observable)
    │
    ├──▶ WhisperBridge (whisper.cpp inference, optional CoreML acceleration)
    │       │
    │       ▼
    │    SegmentMerger (dedup overlapping results)
    │
    ├──▶ partialText: String      ──▶  PartialTextView (pulsing)
    ├──▶ segments: [Segment]      ──▶  TranscriptView (chat bubbles)
    │
    ▼
TextInjector (on user action or auto-type)
    │
    ├──▶ AccessibilityBridge   (AXUIElement → target app)
    ├──▶ ClipboardInjector     (NSPasteboard + Cmd+V)
    └──▶ KeyboardSimulator     (CGEvent fallback)
```

## Key Design Decisions

### 1. SwiftWhisper (whisper.cpp)

**Decision**: Use [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper) — a Swift wrapper around whisper.cpp.

**Rationale**:
- Mature, battle-tested C++ engine (whisper.cpp) with huge community
- SwiftWhisper provides clean Swift API over the C++ layer — no manual bridging needed
- CoreML acceleration supported via whisper.cpp's built-in CoreML backend
- GGML model format — download directly from Hugging Face, no vendor lock-in
- Lighter weight than WhisperKit, more control over inference parameters
- Well-documented API: `Whisper(fromFileURL:)` → `whisper.transcribe(audioFrames:)`

### 2. NSPanel over SwiftUI Window

**Decision**: Use `NSPanel` (AppKit) for the floating overlay, with SwiftUI content inside.

**Rationale**:
- `.nonactivatingPanel` style prevents stealing focus from target apps — critical for the injection workflow
- `.floating` level keeps it above other windows
- SwiftUI's `Window` doesn't support these panel behaviors
- Wrap SwiftUI views inside `NSHostingView` within the panel

### 3. Strategy Pattern for Text Injection

**Decision**: Three injection strategies with automatic fallback.

**Rationale**:
- AX Direct works for ~80% of apps but fails on some Electron apps
- Clipboard+Paste is reliable but clobbers user clipboard (save/restore)
- Keyboard simulation is slowest but most universal
- Auto-fallback chain: AX → Clipboard → Keyboard

### 4. @Observable over Combine

**Decision**: Use Swift's `@Observable` macro (Observation framework) instead of Combine.

**Rationale**:
- Modern Swift pattern, better SwiftUI integration
- Cleaner syntax, no `@Published` boilerplate
- Better performance — only triggers view updates for accessed properties
- macOS 14+ (Sonoma) minimum, which we exceed with Tahoe target

### 5. Disabled App Sandbox

**Decision**: Ship without App Sandbox.

**Rationale**:
- `AXUIElement` APIs require unsandboxed process to inject text into other apps
- Global hotkey monitoring (`addGlobalMonitorForEvents`) requires unsandboxed
- Trade-off: Cannot distribute via Mac App Store
- Distribution via: Developer ID notarized `.dmg`, Homebrew Cask, GitHub Releases
