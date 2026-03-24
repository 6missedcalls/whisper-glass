# Mac App Store — Why It's Blocked (and Workarounds)

## The Core Problem: App Sandbox

The Mac App Store **requires** App Sandbox. WhisperGlass needs three capabilities that the sandbox blocks:

| What We Do | API Used | Sandbox Compatible? | Why |
|------------|----------|-------------------|-----|
| Type text into other apps | `AXUIElement` / `kAXSelectedTextAttribute` | **No** | Sandbox prevents controlling other apps via Accessibility |
| Simulate Cmd+V paste | `CGEvent.post(tap: .cghidEventTap)` | **No** | Sandbox blocks posting events to other apps |
| Global hotkey (suppress sound) | `CGEvent.tapCreate(.defaultTap)` | **No** | Active event taps blocked in sandbox |
| Global hotkey (listen only) | `NSEvent.addGlobalMonitorForEvents` | **Partial** | Works but can't suppress events, and requires entitlement |
| Record microphone | `AVAudioEngine` | **Yes** | Microphone entitlement available in sandbox |
| Run Whisper locally | `SwiftWhisper` | **Yes** | Local computation is fine |

## What Apple Allows in Sandbox

Apple provides these sandbox entitlements:
- `com.apple.security.device.audio-input` — Microphone ✅
- `com.apple.security.network.client` — Outbound network (model download) ✅
- `com.apple.security.files.user-selected.read-write` — File access ✅

But there is **no entitlement** for:
- Controlling other apps via Accessibility
- Posting keyboard events to other apps
- Active CGEventTaps

## Could We Make It Work?

### Option A: Clipboard-Only (No Paste Simulation)
- Instead of auto-pasting, just copy transcribed text to clipboard
- User manually Cmd+V's into their app
- **Feasible for App Store** but terrible UX — defeats the whole purpose

### Option B: Accessibility Exception
- Apple grants exceptions for assistive technology apps
- Would need to apply via `com.apple.security.temporary-exception.apple-events`
- **Very unlikely to be approved** for a dictation app (not traditional assistive tech)

### Option C: macOS Services Menu
- Register a system Service that receives text
- Other apps can invoke it via Services menu
- **Feasible** but clunky — user has to manually trigger it

### Option D: NSUserActivity / Shortcuts
- Expose transcription as a Shortcut action
- Other apps can use the Shortcut
- **Feasible** but indirect — not real-time dictation

## Recommendation

**Don't target the Mac App Store.** Distribute via:

1. **Developer ID + Notarization** (best for users)
   - Sign with your Developer ID certificate
   - Notarize the DMG
   - Users download, drag to Applications, grant Accessibility once
   - This is how most pro macOS tools work (Alfred, Raycast, Bartender, etc.)

2. **Homebrew Cask** (best for developers)
   - Submit to homebrew-cask
   - `brew install --cask whisper-glass`

## Immediate Benefit: Stable Signing

Since you have a paid Developer account, we should sign with your Developer ID NOW.
This permanently fixes the "AX permission breaks on every rebuild" problem:

```bash
# Find your Developer ID
security find-identity -v -p codesigning | grep "Developer ID"

# Sign with it (replace with your actual identity)
codesign --force --deep --sign "Developer ID Application: Your Name (TEAMID)" /Applications/WhisperGlass.app
```

The Developer ID signature is **stable** — rebuilding and re-signing with the same cert keeps the same identity, so TCC/Accessibility permission survives.
