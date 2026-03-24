# WhisperGlass v2 — Visual Indicator + Settings Redesign

## Context
Core dictation pipeline is working: hold ⌃⇧Space → speak → release → text pastes into focused app. Now need polish.

## Feature 1: Visual Recording Indicator

### Problem
User has no visual feedback that recording/transcription is happening. The menu bar icon changes but it's too subtle.

### Design: Floating Pill Indicator (like macOS Dictation)
A small, non-interactive floating pill that appears near the cursor or screen edge when recording. Disappears when done. Never steals focus.

**States:**
1. **Recording** — Small pill with animated waveform bars + "Listening..." label
2. **Transcribing** — Pill shows bouncing dots + "Transcribing..." label
3. **Done** — Brief green checkmark flash, then pill fades out
4. **Hidden** — No pill visible when idle

**Implementation:**
- `NSPanel` with `.nonactivatingPanel` + `.utilityWindow` style (never steals focus, no dock icon)
- `canBecomeKey = false`, `canBecomeMain = false` (purely visual, no interaction)
- `isMovableByWindowBackground = false`
- Level: `.floating` (above other windows)
- SwiftUI content hosted via `NSHostingView`
- Position: bottom-center of screen, or near cursor
- Size: ~200x36 pill
- Background: Liquid Glass (`.glassEffect`) on macOS 26, `.ultraThinMaterial` fallback
- Auto-hide after 1.5s on completion

**Animation (like open-wispr's StatusBarController):**
- Recording: 5 vertical bars with sinusoidal height animation (pre-rendered frames at 30fps)
- Transcribing: 3 dots bouncing with staggered delay
- Both use SwiftUI animation, not pre-rendered frames (simpler)

**Files:**
- `Sources/UI/IndicatorPanel.swift` — NSPanel subclass (non-activating, non-key)
- `Sources/UI/IndicatorView.swift` — SwiftUI pill with state-driven content
- `Sources/UI/WaveformAnimation.swift` — Animated waveform bars
- `Sources/UI/BouncingDotsView.swift` — Transcribing animation

**Integration:**
- AppDelegate creates IndicatorPanel on launch
- `startRecording()` → show indicator in `.recording` state
- `stopRecordingAndTranscribe()` → switch to `.transcribing` state
- After paste → switch to `.done` state → auto-hide after 1.5s

---

## Feature 2: Customizable Hotkeys in Settings

### Problem
Hotkey is hardcoded to ⌃⇧Space. Users need to change it.

### Design: Hotkey Recorder in Settings
A standard macOS key recorder field where the user presses their desired key combination and it's captured.

**Implementation:**
- `Sources/UI/HotkeyRecorderView.swift` — SwiftUI view wrapping an NSView that captures key events
- On focus: "Press your shortcut..." placeholder
- Captures keyDown event, extracts keyCode + modifierFlags
- Validates: must include at least one modifier (Ctrl, Shift, Cmd, or Option)
- Displays the captured shortcut as readable text (e.g., "⌃⇧Space")
- Saves to UserDefaults via AppSettings: `hotkeyKeyCode: UInt16`, `hotkeyModifiers: UInt64`
- AppDelegate reads from AppSettings on launch and when settings change
- Restart hotkey monitor when hotkey changes

**Settings Tab Updates:**
- Add "Hotkey" section to Settings with the recorder
- Show current hotkey
- "Reset to Default" button (⌃⇧Space)

**Files:**
- `Sources/UI/HotkeyRecorderView.swift` — Key capture view
- Update `Sources/Settings/AppSettings.swift` — Add hotkey properties
- Update `Sources/App/AppDelegate.swift` — Read hotkey from settings

---

## Feature 3: Liquid Glass Design System

### Problem
Current Settings window and onboarding use basic macOS chrome. Should adopt macOS 26 Liquid Glass.

### Design: Apply Liquid Glass Consistently
Use `@available(macOS 26, *)` checks throughout with `.ultraThinMaterial` fallback.

**Where to apply:**
1. **Indicator pill** — `.glassEffect(.regular)` background
2. **Settings window** — Glass-backed sections
3. **Onboarding window** — Glass cards for model selection, permission steps
4. **Menu bar dropdown** — System handles this automatically

**API usage:**
```swift
// macOS 26 Liquid Glass
if #available(macOS 26, *) {
    view.glassEffect(.regular, in: .capsule)
} else {
    view.background(.ultraThinMaterial)
        .clipShape(Capsule())
}
```

**Files to update:**
- `Sources/UI/IndicatorView.swift` — New (glass pill)
- `Sources/Onboarding/OnboardingView.swift` — Glass cards
- `Sources/Onboarding/ModelSelectionStep.swift` — Glass model cards
- `Sources/Onboarding/ModelDownloadView.swift` — Glass download card
- `Sources/App/SettingsView.swift` — Glass-backed form sections (if supported)

---

## Implementation Order

### Phase 1: Visual Indicator (highest impact)
1. Create IndicatorPanel (NSPanel, non-activating)
2. Create IndicatorView (SwiftUI pill with states)
3. Create WaveformAnimation + BouncingDotsView
4. Wire into AppDelegate recording lifecycle
5. Test: indicator appears/disappears correctly, never steals focus

### Phase 2: Hotkey Settings
1. Add hotkey properties to AppSettings
2. Create HotkeyRecorderView
3. Add hotkey section to SettingsView
4. Update AppDelegate to read/apply custom hotkey
5. Test: change hotkey, verify new hotkey works

### Phase 3: Liquid Glass Polish
1. Apply glass to indicator pill
2. Update onboarding views
3. Update settings if applicable
4. Test: looks correct on macOS 26, falls back gracefully on older

---

**WAITING FOR CONFIRMATION**: Proceed with this plan? (yes / no / modify)
