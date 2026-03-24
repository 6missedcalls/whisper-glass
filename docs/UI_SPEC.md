# WhisperGlass — UI Specification

## Design Philosophy

> A whisper of glass that floats above your workspace — present when needed, invisible when not.

WhisperGlass should feel like a natural extension of macOS Tahoe's Liquid Glass design language. It should never feel like a third-party app bolted onto the system. Every surface refracts, every control breathes, every transition flows.

---

## Window Hierarchy

```
┌─ Menu Bar ─────────────────────────────────────┐
│  [🎤] WhisperGlass                              │  MenuBarExtra (always present)
└────────────────────────────────────────────────┘

┌─ Floating Overlay (NSPanel) ───────────────────┐
│                                                  │  .floating level
│  ┌─ Transcript Area ─────────────────────────┐  │  .nonActivatingPanel
│  │                                            │  │
│  │  ┌─────────────────────────────────┐      │  │  Liquid Glass background
│  │  │ "Hey, can you refactor the      │      │  │
│  │  │  auth middleware to use JWT?"    │      │  │  Chat bubbles
│  │  └─────────────────────────────────┘      │  │
│  │                                            │  │
│  │  ┌─────────────────────────────────┐      │  │
│  │  │ "Also add rate limiting to the  │      │  │
│  │  │  login endpoint..."             │ ◀──  │  │  Partial (pulsing)
│  │  └─────────────────────────────────┘      │  │
│  │                                            │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  ┌─ Control Bar ─────────────────────────────┐  │  Glass toolbar
│  │  [⏺ Record]  [📱 VSCode ▾]  [⌨️ Auto]    │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## Overlay Window

### Dimensions
- **Default**: 360w x 480h points
- **Minimum**: 280w x 200h
- **Maximum**: 600w x 800h
- **Corner radius**: 20pt (matching Liquid Glass spec)

### Behavior
- Always on top (`.floating` level)
- Non-activating — clicking it does NOT steal focus from VSCode/Terminal
- Draggable from any non-interactive area
- Resizable from edges and corners
- Remembers position and size across launches
- Double-click title area to collapse to compact mode (control bar only)

### Glass Treatment
```swift
GlassEffectContainer {
    VStack(spacing: 0) {
        TranscriptView()
        ControlBar()
    }
}
.frame(minWidth: 280, minHeight: 200)
.glassEffect(.regular, in: .rect(cornerRadius: 20))
```

---

## Transcript Area

### Chat Bubble Design

Each finalized segment appears as a glass pill bubble:

```
┌──────────────────────────────────┐
│  "Refactor the auth middleware    │   .glassEffect(.regular)
│   to use JWT tokens instead of   │   .clipShape(RoundedRectangle(cornerRadius: 16))
│   session cookies"               │   padding: 12pt horizontal, 8pt vertical
│                          2:34 PM │   timestamp: .secondary, 11pt
└──────────────────────────────────┘
```

**Typography**:
- Body text: SF Pro, 14pt, `.primary` color
- Timestamp: SF Pro, 11pt, `.secondary` color, trailing aligned
- Partial text: SF Pro, 14pt, `.secondary` color, 60% opacity

**Animations**:
- New bubbles slide in from bottom with spring animation
- `transition: .move(edge: .bottom).combined(with: .opacity)`
- `animation: .spring(response: 0.4, dampingFraction: 0.8)`

### Partial Text (In-Progress)

The current hypothesis appears below the last bubble with:
- Lower opacity (0.6)
- Subtle pulsing animation (opacity 0.4 ↔ 0.7, 1.5s period)
- No glass background — just floating text
- Updates in real-time as Whisper refines its guess

### Scroll Behavior
- Auto-scrolls to bottom when new segments arrive
- User can scroll up to review; auto-scroll pauses until they scroll back to bottom
- `ScrollViewReader` with `scrollTo(id, anchor: .bottom)`

### Empty State
- Centered mic icon (SF Symbol: `mic.badge.plus`) with glass treatment
- "Press ⌥Space to start" subtitle
- Subtle breathing animation on the icon

---

## Control Bar

Fixed at the bottom of the overlay, glass-backed toolbar.

```
┌──────────────────────────────────────────┐
│  [● REC]   [📱 VSCode ▾]   [⌨️ Auto ▾]  │
└──────────────────────────────────────────┘
```

### Record Button
- **Idle**: Gray circle, "Record" label
- **Recording**: Red filled circle with pulse animation, "Recording" label
- **Paused**: Orange circle, "Paused" label
- SF Symbols: `record.circle`, `record.circle.fill`, `pause.circle.fill`
- Tap toggles between recording and paused
- Long-press stops and clears

### Target App Picker
- Dropdown showing running apps with text input capability
- Each row: App icon (16x16) + App name
- "Auto (Frontmost)" option at top
- Updates live as apps launch/quit
- Glass-backed popover

### Send Mode Picker
- Segmented control or dropdown:
  - `Manual` — "Send" button appears, user clicks to inject
  - `Auto-type` — Text auto-injects as segments finalize
  - `Clipboard` — Copies to clipboard only
- Icon-based for compactness

### Send Button (Manual Mode Only)
- Appears to the right of the mode picker when mode = Manual
- Glass pill with arrow icon: `arrow.up.circle.fill`
- Sends all unsent segments to target app
- Brief checkmark animation on success

---

## Menu Bar

### Icon States
- **Idle**: `mic` (outline)
- **Recording**: `mic.fill` with subtle red tint
- **Error**: `mic.slash` (permissions issue)

### Dropdown Menu
```
┌───────────────────────────┐
│  ⏺  Start Recording       │  (or "Stop Recording" when active)
│───────────────────────────│
│  "Last: refactor the..."  │  Preview of most recent segment
│───────────────────────────│
│  📱 Target: VSCode        │  Submenu to change target
│  ⌨️ Mode: Auto-type       │  Submenu to change mode
│───────────────────────────│
│  🔧 Settings...           │
│  ❓ About WhisperGlass     │
│───────────────────────────│
│  ⏻  Quit                  │
└───────────────────────────┘
```

---

## Settings Window

Standard macOS settings with `TabView` and glass-backed sections.

### Tabs

**General**
- Launch at login toggle
- Show in Dock toggle
- Menu bar icon style

**Audio**
- Input device picker
- Input level meter (live visualization)
- VAD sensitivity slider (Low / Medium / High)
- Noise gate threshold

**Transcription**
- Model picker (tiny / base / small / large-v3-turbo)
- Model download status / re-download button
- Language picker (Auto-detect + specific languages)
- Filler word filter toggle ("um", "uh", "like")

**Appearance**
- Window opacity slider (50% - 100%)
- Bubble style: Glass / Solid / Minimal
- Font size: Small (12pt) / Medium (14pt) / Large (16pt)
- Compact mode toggle (hides timestamps, tighter spacing)
- Theme: System / Light / Dark

**Injection**
- Default send mode
- Default target app
- Code mode toggle (disable auto-capitalize)
- Newline on pause (+ pause threshold slider)
- Clipboard restore toggle

**Shortcuts**
- Hotkey recorder for each action:
  - Toggle recording (default: ⌥Space)
  - Send transcript (default: ⌥Return)
  - Clear transcript (default: ⌥Delete)
  - Toggle overlay visibility (default: ⌥G)

---

## Onboarding Flow

Five-step wizard in a centered Liquid Glass window:

### Step 1 — Welcome
- App icon (large, glass-backed)
- "WhisperGlass" title
- "Real-time transcription with Liquid Glass elegance"
- [Get Started →]

### Step 2 — Microphone
- Mic icon animation
- "WhisperGlass needs microphone access to hear you"
- [Allow Microphone] — triggers system permission dialog
- Shows green checkmark when granted

### Step 3 — Accessibility
- Keyboard icon animation
- "To type into VSCode and other apps, WhisperGlass needs Accessibility access"
- [Open System Settings] — deep-link to Privacy > Accessibility
- "Add WhisperGlass to the list and enable it"
- Auto-detects when permission is granted (polls `AXIsProcessTrusted()`)

### Step 4 — Choose Model
- Model comparison cards (glass-backed):
  - Tiny: "Fast & Light — 75MB"
  - Base: "Balanced — 142MB"
  - Large: "Maximum Accuracy — 1.5GB"
- Download progress bar with percentage
- "You can change this later in Settings"

### Step 5 — Ready
- Quick reference card showing hotkeys
- "You're all set!"
- [Start Transcribing] — opens overlay, starts recording

---

## Color Palette

All colors adapt to light/dark mode automatically via Liquid Glass.

| Element | Light Mode | Dark Mode |
|---------|-----------|-----------|
| Glass background | System ultraThinMaterial | System ultraThinMaterial |
| Bubble glass | `.glassEffect(.regular)` | `.glassEffect(.regular)` |
| Primary text | `.primary` | `.primary` |
| Secondary text | `.secondary` | `.secondary` |
| Recording indicator | `Color.red` | `Color.red` |
| Send button | `Color.accentColor` | `Color.accentColor` |
| Success flash | `Color.green` | `Color.green` |

---

## Iconography

All icons use SF Symbols for native consistency:

| Action | Symbol |
|--------|--------|
| Record | `record.circle` / `record.circle.fill` |
| Pause | `pause.circle.fill` |
| Stop | `stop.circle.fill` |
| Send | `arrow.up.circle.fill` |
| Clear | `trash.circle` |
| Settings | `gearshape` |
| Mic (menu bar) | `mic` / `mic.fill` / `mic.slash` |
| Target app | `app.badge.checkmark` |
| Auto-type | `keyboard` |
| Clipboard | `doc.on.clipboard` |
| Manual | `hand.tap` |
