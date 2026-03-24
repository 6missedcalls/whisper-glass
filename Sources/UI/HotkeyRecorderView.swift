import SwiftUI
import AppKit

// MARK: - HotkeyRecorderView

/// A SwiftUI control that captures a global keyboard shortcut.
/// Displays the current shortcut and enters a recording mode on click,
/// capturing the next key + modifier combination.
public struct HotkeyRecorderView: View {

    @Binding var keyCode: UInt16
    @Binding var modifiers: UInt64

    @State private var isRecording = false
    @State private var validationError: String?

    public init(keyCode: Binding<UInt16>, modifiers: Binding<UInt64>) {
        self._keyCode = keyCode
        self._modifiers = modifiers
    }

    public var body: some View {
        HStack(spacing: 8) {
            recordButton
            clearButton
        }
    }

    // MARK: - Record Button

    private var recordButton: some View {
        ZStack {
            // Hidden key capture view (only active when recording)
            if isRecording {
                KeyCaptureRepresentable(
                    onKeyDown: handleKeyCaptured,
                    onCancel: stopRecording
                )
                .frame(width: 0, height: 0)
                .opacity(0)
            }

            Button(action: toggleRecording) {
                HStack {
                    Text(displayText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(isRecording ? .primary : .secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(minWidth: 160)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording
                              ? Color.accentColor.opacity(0.08)
                              : Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isRecording ? Color.accentColor : Color.primary.opacity(0.15),
                            lineWidth: isRecording ? 1.5 : 0.5
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Clear Button

    private var clearButton: some View {
        Button(action: resetToDefault) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.tertiary)
                .font(.system(size: 14))
        }
        .buttonStyle(.plain)
        .help("Reset to default shortcut")
    }

    // MARK: - Display

    private var displayText: String {
        if isRecording {
            return "Press shortcut..."
        }
        if let error = validationError {
            return error
        }
        let modSymbols = AppSettings.modifierSymbols(from: modifiers)
        let keyName = AppSettings.keyCodeName(for: keyCode)
        return modSymbols + keyName
    }

    // MARK: - Actions

    private func toggleRecording() {
        isRecording = !isRecording
        validationError = nil
    }

    private func stopRecording() {
        isRecording = false
    }

    private func resetToDefault() {
        keyCode = 49        // Space
        modifiers = 0x60000 // Control + Shift
        validationError = nil
        isRecording = false
    }

    private func handleKeyCaptured(capturedKeyCode: UInt16, capturedModifiers: UInt64) {
        let hasModifier = hasRequiredModifier(capturedModifiers)

        guard hasModifier else {
            validationError = "Add ⌃, ⌥, ⇧, or ⌘"
            isRecording = false
            return
        }

        keyCode = capturedKeyCode
        modifiers = capturedModifiers
        validationError = nil
        isRecording = false
    }

    private func hasRequiredModifier(_ flags: UInt64) -> Bool {
        let control: UInt64 = 0x40000
        let option: UInt64 = 0x80000
        let shift: UInt64 = 0x20000
        let command: UInt64 = 0x100000
        return (flags & (control | option | shift | command)) != 0
    }
}

// MARK: - KeyCaptureRepresentable

/// NSViewRepresentable that creates a hidden NSView to capture keyboard events.
/// Becomes first responder immediately and forwards keyDown events.
private struct KeyCaptureRepresentable: NSViewRepresentable {

    let onKeyDown: (_ keyCode: UInt16, _ modifiers: UInt64) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyDown = onKeyDown
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
        nsView.onCancel = onCancel
        // Request first responder on each update to ensure capture
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

// MARK: - KeyCaptureNSView

/// Hidden NSView that captures keyboard events when it becomes first responder.
private final class KeyCaptureNSView: NSView {

    var onKeyDown: ((_ keyCode: UInt16, _ modifiers: UInt64) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        // Escape cancels recording without changing the shortcut
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        let relevantModifiers = extractRelevantModifiers(from: event.modifierFlags)
        onKeyDown?(event.keyCode, relevantModifiers)
    }

    override func resignFirstResponder() -> Bool {
        onCancel?()
        return super.resignFirstResponder()
    }

    /// Extracts only the modifier flags we care about, mapped to CGEventFlags raw values
    /// for consistency with AppSettings storage format.
    private func extractRelevantModifiers(from flags: NSEvent.ModifierFlags) -> UInt64 {
        var result: UInt64 = 0
        if flags.contains(.control) { result |= 0x40000 }    // CGEventFlags.maskControl
        if flags.contains(.option) { result |= 0x80000 }     // CGEventFlags.maskAlternate
        if flags.contains(.shift) { result |= 0x20000 }      // CGEventFlags.maskShift
        if flags.contains(.command) { result |= 0x100000 }   // CGEventFlags.maskCommand
        return result
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Default State") {
    HotkeyRecorderPreview()
        .padding()
        .frame(width: 300)
}

private struct HotkeyRecorderPreview: View {
    @State private var keyCode: UInt16 = 49
    @State private var modifiers: UInt64 = 0x60000

    var body: some View {
        HotkeyRecorderView(keyCode: $keyCode, modifiers: $modifiers)
    }
}
#endif
