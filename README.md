<div align="center">

# WhisperGlass

### Real-time speech-to-text that types for you.

A native macOS menu bar app that transcribes your voice and injects text directly into any application — powered by [Whisper](https://github.com/openai/whisper), running entirely on-device.

[![macOS](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple&logoColor=white)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)](#)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](#license)
[![Whisper](https://img.shields.io/badge/Whisper-whisper.cpp-6B7280?style=flat-square)](#how-it-works)

**No cloud. No API keys. No data leaves your Mac.**

---

<!--
<img src="https://raw.githubusercontent.com/6missedcalls/whisper-glass/main/assets/demo.gif" alt="WhisperGlass Demo" width="640" />
Uncomment when a demo GIF is available.
-->

</div>

## Why WhisperGlass?

macOS dictation is limited — it requires internet, offers no app targeting, and gives you no control over the output. WhisperGlass fixes all of that:

- **100% local** — Whisper runs on your hardware via [whisper.cpp](https://github.com/ggerganov/whisper.cpp). Nothing is sent anywhere.
- **Types into any app** — Transcribed text is injected directly into the focused application via Accessibility APIs, clipboard paste, or keyboard simulation.
- **Always one hotkey away** — Press `Ctrl+Shift+Space` to start/stop dictation from anywhere.
- **Choose your model** — Trade speed for accuracy with four model sizes, downloaded on demand.

---

## Features

| | Feature | Details |
|---|---|---|
| **Dictation** | Hold-to-talk or toggle | Press the global hotkey to start, release (or press again) to stop |
| **Text Injection** | 3 strategies with auto-fallback | Accessibility API > Clipboard+Paste > Keyboard simulation |
| **Voice Activity Detection** | Skip silence automatically | Only transcribes when you're actually speaking |
| **Smart Formatting** | Punctuation & capitalization | Whisper handles grammar; SmartFormatter cleans up the rest |
| **Transcript History** | Full session logs | Browse, search, and export past transcriptions (TXT, SRT, JSON) |
| **Onboarding** | Guided first-run setup | Walks through permissions, model download, and hotkey configuration |
| **Liquid Glass UI** | Native macOS Tahoe design | Floating non-activating panel with glass effects and smooth animations |

---

## Models

WhisperGlass downloads models on first use from Hugging Face. Pick the one that fits your hardware:

| Model | Size | Speed | Accuracy | Best For |
|-------|------|-------|----------|----------|
| **Tiny** | 75 MB | Fastest | Good | Quick notes, older Macs |
| **Base** | 142 MB | Fast | Better | General daily use |
| **Small** | 466 MB | Moderate | Great | Meetings & long-form |
| **Large v3 Turbo** | 1.5 GB | Slower | Best | Maximum accuracy |

All models run on-device using Apple Neural Engine acceleration when available.

---

## Quick Start

### Prerequisites

- macOS Sonoma 14.0 or later
- Xcode Command Line Tools (`xcode-select --install`)
- Microphone access
- Accessibility permission (for text injection)

### Build & Run

```bash
git clone https://github.com/6missedcalls/whisper-glass.git
cd whisper-glass
./scripts/run.sh
```

This builds, assembles a signed `.app` bundle, and launches it. Signing identity is auto-detected from your keychain — no configuration needed.

For a release build installed to `/Applications`:

```bash
./scripts/deploy.sh
```

### First Launch

1. Grant **Microphone** access when prompted
2. Grant **Accessibility** permission in System Settings > Privacy & Security
3. Choose a Whisper model to download
4. Press `Ctrl+Shift+Space` and start talking

---

## How It Works

```
  Microphone
      |
      v
  AudioCaptureEngine          16kHz mono PCM via AVAudioEngine
      |
      v
  AudioBufferRing             3-second chunks with 0.5s overlap
      |
      v
  VoiceActivityDetector       Skips silence, forwards speech
      |
      v
  TranscriptionEngine         Async chunk queue
      |
      +---> WhisperBridge      whisper.cpp inference (on-device)
      |         |
      |         v
      |    SegmentMerger       Deduplicates overlapping results
      |
      v
  TextInjector                Injects into the active application
      |
      +---> AccessibilityBridge    AXUIElement (direct insertion)
      +---> ClipboardInjector      NSPasteboard + Cmd+V
      +---> KeyboardSimulator      CGEvent keystroke fallback
```

---

## Architecture

```
Sources/
├── App/             Entry point, menu bar, app delegate
├── Audio/           Mic capture, buffer ring, VAD
├── Transcription/   Whisper bridge, model manager, segment merger
├── Injection/       Text injection strategies, hotkey manager
├── UI/              Overlay panel, transcript view, glass components
├── Onboarding/      First-run setup flow
├── Settings/        User preferences
├── Storage/         SwiftData persistence, transcript export
└── Models/          Data models and enums
```

**Key design decisions:**
- **NSPanel** instead of SwiftUI Window — non-activating panel prevents stealing focus
- **Strategy pattern** for injection — automatic AX > Clipboard > Keyboard fallback
- **No App Sandbox** — required for Accessibility APIs and global hotkeys
- **@Observable** over Combine — modern Swift concurrency patterns

---

## Distribution

WhisperGlass requires Accessibility API access and cannot be sandboxed, so **Mac App Store is not an option**. Available distribution channels:

| Channel | Status |
|---------|--------|
| GitHub Releases | Available now |
| Homebrew Cask | Planned |
| Developer ID + Notarization (DMG) | Planned |

---

## Requirements

| Requirement | Minimum |
|---|---|
| macOS | Sonoma 14.0+ |
| CPU | Apple Silicon recommended |
| RAM | 8 GB (16 GB for Large model) |
| Disk | ~200 MB (app + Base model) |

---

## Contributing

Contributions are welcome. Please open an issue first to discuss what you'd like to change.

```bash
# Run the test suite
swift test
```

---

## License

MIT

---

<div align="center">

Built with Swift, [whisper.cpp](https://github.com/ggerganov/whisper.cpp), and [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper).

</div>
