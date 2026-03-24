# WhisperGlass — Technology Stack

## Core Technologies

| Technology | Purpose | Why This Choice |
|-----------|---------|-----------------|
| **Swift 6** | Primary language | Type safety, structured concurrency, macOS native |
| **SwiftUI + Liquid Glass** | UI framework | Apple's latest glass morphism APIs, declarative UI |
| **AppKit (NSPanel)** | Floating overlay | Non-activating panel behavior, focus control |
| **SwiftWhisper (whisper.cpp)** | Speech-to-text | Mature C++ engine, Swift wrapper, GGML models, CoreML support |
| **AVFoundation** | Audio capture | System framework, reliable mic access |
| **ApplicationServices** | Text injection | AXUIElement API for cross-app text insertion |
| **SwiftData** | Persistence | Modern Swift ORM, transcript history |

## Apple Liquid Glass APIs

### Available in macOS Tahoe 26+

```swift
// Glass effect on any view
Text("Hello")
    .glassEffect(.regular)

// Container that enables glass effects for children
GlassEffectContainer {
    VStack {
        // Child views can use .glassEffect()
    }
}

// Glass effect with custom configuration
view.glassEffect(
    .regular,
    in: .capsule,
    isEnabled: true
)
```

### Key Modifiers

| Modifier | Purpose |
|----------|---------|
| `.glassEffect(.regular)` | Standard Liquid Glass material |
| `.glassEffect(.prominent)` | Higher contrast glass |
| `GlassEffectContainer` | Parent container enabling glass for children |
| `.glassEffectUnion(id:)` | Merge multiple glass regions into one |

### Fallback for Pre-Tahoe

```swift
extension View {
    @ViewBuilder
    func adaptiveGlass() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular)
        } else {
            self.background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
```

## SwiftWhisper (whisper.cpp) Integration

### Setup

```swift
import SwiftWhisper

// Load GGML model from local file
let modelURL = Bundle.main.url(forResource: "ggml-base", withExtension: "bin")!
let whisper = try Whisper(fromFileURL: modelURL)

// Configure parameters
whisper.params.language = .english
whisper.params.translate = false
```

### Transcription

```swift
// audioFrames: [Float] — 16kHz mono PCM samples
let segments = try await whisper.transcribe(audioFrames: audioFrames)

for segment in segments {
    // segment.text — transcribed text
    // segment.startTime — start timestamp (ms)
    // segment.endTime — end timestamp (ms)
}
```

### Delegate for Streaming Updates

```swift
class TranscriptionDelegate: WhisperDelegate {
    func whisper(_ whisper: Whisper, didProcessNewSegments segments: [Segment], atIndex index: Int) {
        // Called as new segments are recognized — use for real-time partial updates
    }

    func whisper(_ whisper: Whisper, didCompleteWithSegments segments: [Segment]) {
        // Called when full transcription of a chunk completes
    }
}

whisper.delegate = delegate
```

### GGML Model Options

Models are downloaded from Hugging Face (`ggerganov/whisper.cpp` repo) in GGML format:

| Model | File | Size | Speed (M1) | Accuracy | Use Case |
|-------|------|------|-----------|----------|----------|
| `tiny` | `ggml-tiny.bin` | ~75MB | ~10x realtime | Good | Quick notes, low power |
| `base` | `ggml-base.bin` | ~142MB | ~7x realtime | Better | General use |
| `small` | `ggml-small.bin` | ~466MB | ~4x realtime | Great | Meetings, dictation |
| `large-v3-turbo` | `ggml-large-v3-turbo.bin` | ~1.5GB | ~2x realtime | Best | Maximum accuracy |

### CoreML Acceleration (Optional)

whisper.cpp supports CoreML for encoder acceleration on Apple Silicon. To use:
1. Generate CoreML model from GGML: `whisper.cpp/models/generate-coreml-model.sh base`
2. Place `.mlmodelc` alongside the `.bin` file
3. whisper.cpp auto-detects and uses CoreML when available
4. Provides ~2-3x speedup on Neural Engine

## Accessibility API Reference

### Text Injection Flow

```swift
import ApplicationServices

// 1. Get system-wide AX element
let systemWide = AXUIElementCreateSystemWide()

// 2. Get focused element in frontmost app
var focusedElement: AnyObject?
AXUIElementCopyAttributeValue(
    systemWide,
    kAXFocusedUIElementAttribute as CFString,
    &focusedElement
)

// 3. Insert text at cursor position
guard let element = focusedElement else { return }
AXUIElementSetAttributeValue(
    element as! AXUIElement,
    kAXSelectedTextAttribute as CFString,
    text as CFTypeRef
)
```

### Important Constraints

- **Must run off main thread** — AX calls on main thread freeze the app
- **Requires Accessibility permission** — System Settings > Privacy > Accessibility
- **App Sandbox must be disabled** — sandboxed apps cannot use AX on other apps
- **Some apps block AX writes** — secure input fields, some Electron configurations

### Clipboard Fallback

```swift
import AppKit
import Carbon

// Save current clipboard
let savedItems = NSPasteboard.general.pasteboardItems

// Set new text
NSPasteboard.general.clearContents()
NSPasteboard.general.setString(text, forType: .string)

// Simulate Cmd+V
let source = CGEventSource(stateID: .hidSystemState)
let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
cmdDown?.flags = .maskCommand
cmdDown?.post(tap: .cghidEventTap)

let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
cmdUp?.flags = .maskCommand
cmdUp?.post(tap: .cghidEventTap)

// Restore clipboard after brief delay
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    NSPasteboard.general.clearContents()
    savedItems?.forEach { NSPasteboard.general.writeObjects([$0]) }
}
```

## Global Hotkeys

```swift
// Monitor global key events (requires unsandboxed)
NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
    if event.modifierFlags.contains(.option) && event.keyCode == 49 { // ⌥Space
        toggleRecording()
    }
}
```

## Distribution

| Channel | Requirement | Notes |
|---------|-------------|-------|
| **Developer ID + Notarization** | Apple Developer account ($99/yr) | `.dmg` direct download |
| **Homebrew Cask** | Public GitHub repo | `brew install --cask whisper-glass` |
| **GitHub Releases** | Free | Unsigned, users must allow in Gatekeeper |
| ~~Mac App Store~~ | ~~Sandbox required~~ | **Not possible** (AX requires unsandboxed) |

## Minimum System Requirements

| Requirement | Value |
|-------------|-------|
| macOS version | macOS Tahoe 26 (Liquid Glass), fallback to Sonoma 14 |
| Chip | Apple Silicon (M1+) required for Neural Engine |
| RAM | 8GB minimum, 16GB recommended for large models |
| Disk | ~2GB for app + large-v3-turbo model |
| Permissions | Microphone, Accessibility |
