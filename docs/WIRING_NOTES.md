# Integration Wiring Notes

After all 3 agents complete, AppDelegate needs these changes:

## Indicator Panel
- Create IndicatorPanel in applicationDidFinishLaunching (after onboarding)
- startRecording() → indicatorPanel.show(state: .recording)
- stopRecordingAndTranscribe() → indicatorPanel.updateState(.transcribing)
- After successful paste → indicatorPanel.updateState(.done), then hide after 1.5s
- On error → hide immediately

## Custom Hotkeys
- Read hotkeyKeyCode and hotkeyModifiers from AppSettings in startHotkeyMonitor()
- Replace hardcoded keyCode=49 and requiredMods with values from settings
- When settings change, restart the hotkey monitor

## Menu Bar Update
- Show current hotkey description in the menu bar hint text
