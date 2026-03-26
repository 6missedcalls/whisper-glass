import AppKit
import AVFoundation
import ApplicationServices
import SwiftUI
import WhisperGlassCore
import os

// MARK: - App Delegate

/// Pure menu bar dictation app:
/// - Hold ⌃⇧Space: record while held, transcribe on release, paste into focused app
/// - .accessory activation policy (never steals focus)
/// - Record to file → release key → transcribe → clipboard paste
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    // MARK: - Core Components

    let appSettings = AppSettings()
    let transcriptionEngine = TranscriptionEngine()
    let audioDeviceManager = AudioDeviceManager()

    // MARK: - Recording State

    private var captureSessionRef: AVCaptureSession?
    private var captureRecorder: CaptureRecorder?
    private var currentRecordingURL: URL?
    @Published var isRecording = false

    // MARK: - UI

    private var indicatorPanel: IndicatorPanel?
    private var accessibilityWindow: NSWindow?

    // MARK: - Event Monitors

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var usingEventTap = false

    // MARK: - Onboarding

    private var onboardingWindow: NSWindow?
    private static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    // MARK: - Lifecycle

    // Debug log file — fputs to stderr is invisible when launched via 'open'
    private static let debugLog: UnsafeMutablePointer<FILE>? = {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("whisper-glass-debug.log").path
        return fopen(path, "w")
    }()

    static func log(_ msg: String) {
        fputs("[WG] \(msg)\n", stderr)
        if let f = debugLog {
            fputs("[WG] \(msg)\n", f)
            fflush(f)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Self.log("App started (.accessory policy)")

        indicatorPanel = IndicatorPanel.create()

        if shouldShowOnboarding {
            NSApp.setActivationPolicy(.regular)
            showOnboarding()
        } else {
            loadSavedModel()
        }

        ensureAccessibilityAndStartMonitor()
    }

    // MARK: - Accessibility

    private func ensureAccessibilityAndStartMonitor() {
        let trusted = AXIsProcessTrusted()
        let bundleID = Bundle.main.bundleIdentifier ?? "nil"
        let pid = ProcessInfo.processInfo.processIdentifier
        Self.log("AX check: trusted=\(trusted), bundleID=\(bundleID), pid=\(pid)")

        if trusted {
            startHotkeyMonitor()
            return
        }

        Self.log("Accessibility not granted — showing permission window")

        // Show an in-app permission window that directs the user to
        // System Settings. Polls at 300ms and auto-closes once granted.
        let promptView = AccessibilityPromptView { [weak self] in
            Self.log("Accessibility: granted")
            self?.accessibilityWindow?.close()
            self?.accessibilityWindow = nil
            NSApp.setActivationPolicy(.accessory)
            self?.startHotkeyMonitor()
        }

        let hostView = NSHostingView(rootView: promptView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostView
        window.title = "WhisperGlass"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        accessibilityWindow = window
    }

    // MARK: - Hotkey Monitor

    private func startHotkeyMonitor() {
        let targetKeyCode = appSettings.hotkeyKeyCode
        let requiredMods = appSettings.hotkeyModifiers & 0x00FF0000

        Self.log("Hotkey: \(appSettings.hotkeyDescription) (key=\(targetKeyCode), mods=0x\(String(requiredMods, radix: 16)))")

        // Try CGEventTap first — it can SUPPRESS the key event so the
        // focused app doesn't play the alert sound for unrecognized shortcuts.
        if tryStartEventTap(keyCode: targetKeyCode, mods: requiredMods) {
            Self.log("Using CGEventTap (suppresses alert sound)")
            usingEventTap = true
        } else {
            // Fall back to NSEvent global monitor (listen-only, can't suppress)
            Self.log("CGEventTap unavailable, using NSEvent fallback (alert sound may play)")
            startNSEventMonitor(keyCode: targetKeyCode, mods: requiredMods)
        }

        // Local monitor for when our app has focus
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event in
            guard event.keyCode == targetKeyCode else { return event }
            let m = UInt64(event.modifierFlags.rawValue) & 0x00FF0000

            if event.type == .keyDown && m & requiredMods == requiredMods && !(self?.isRecording ?? false) {
                self?.startRecording()
                return nil
            } else if event.type == .keyUp && (self?.isRecording ?? false) {
                self?.stopRecordingAndTranscribe()
                return nil
            }
            return event
        }
    }

    /// CGEventTap in ACTIVE mode — intercepts and suppresses our hotkey
    /// so the focused app never sees it (no alert sound).
    private func tryStartEventTap(keyCode: UInt16, mods: UInt64) -> Bool {
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
            if !CGPreflightListenEventAccess() { return false }
        }

        let context = HotkeyContext(keyCode: keyCode, mods: mods, delegate: self)
        let contextPtr = Unmanaged.passRetained(context).toOpaque()

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let ctx = Unmanaged<HotkeyContext>.fromOpaque(userInfo).takeUnretainedValue()

                let kc = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                guard kc == ctx.keyCode else { return Unmanaged.passUnretained(event) }

                let flags = UInt64(event.flags.rawValue) & 0x00FF0000
                let modsMatch = flags & ctx.mods == ctx.mods
                let type = event.type

                // Only suppress events that belong to OUR hotkey combo.
                // keyDown: must match both keyCode AND modifiers.
                // keyUp: only suppress if we're actively recording (our combo started it).
                //        Otherwise pass through — other shortcuts (⌘Space for Spotlight,
                //        etc.) share keyCode 49 and need their keyUp delivered.
                if type == .keyDown && modsMatch {
                    if !ctx.delegate.isRecording {
                        DispatchQueue.main.async { ctx.delegate.startRecording() }
                    }
                    return nil // SUPPRESS
                } else if type == .keyUp && ctx.delegate.isRecording {
                    DispatchQueue.main.async { ctx.delegate.stopRecordingAndTranscribe() }
                    return nil // SUPPRESS
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: contextPtr
        ) else {
            Unmanaged<HotkeyContext>.fromOpaque(contextPtr).release()
            return false
        }

        eventTap = tap
        eventTapSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        if let src = eventTapSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func startNSEventMonitor(keyCode: UInt16, mods: UInt64) {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event in
            guard event.keyCode == keyCode else { return }
            let m = UInt64(event.modifierFlags.rawValue) & 0x00FF0000

            if event.type == .keyDown && m & mods == mods && !(self?.isRecording ?? false) {
                DispatchQueue.main.async { self?.startRecording() }
            } else if event.type == .keyUp && (self?.isRecording ?? false) {
                DispatchQueue.main.async { self?.stopRecordingAndTranscribe() }
            }
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }

        // macOS Tahoe (26+) requires explicit mic authorization BEFORE
        // AVAudioEngine will deliver audio buffers. Without this, the engine
        // starts silently but the tap callback never fires (0 frames).
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard micStatus == .authorized else {
            if micStatus == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    if granted {
                        DispatchQueue.main.async { self?.startRecording() }
                    }
                }
            } else {
                Self.log("Mic permission denied — cannot record")
            }
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wg-\(UUID().uuidString).wav")

        do {
            // Use AVCaptureSession instead of AVAudioEngine for recording.
            // AVAudioEngine has a well-documented bug where Bluetooth devices
            // (AirPods) deliver 0 frames. AVCaptureSession handles Bluetooth
            // audio input correctly and respects the system default mic.
            //
            // Record in the device's NATIVE format for best quality.
            // Conversion to 16kHz mono happens after recording when reading.
            let captureSession = AVCaptureSession()
            guard let mic = AVCaptureDevice.default(for: .audio),
                  let micInput = try? AVCaptureDeviceInput(device: mic) else {
                Self.log("ERROR: Cannot access microphone")
                return
            }
            captureSession.addInput(micInput)

            let audioOutput = AVCaptureAudioDataOutput()
            // nil settings = deliver in device's native format (best quality)
            audioOutput.audioSettings = nil

            Self.log("Mic: \(mic.localizedName)")

            let recorder = CaptureRecorder(url: url)
            audioOutput.setSampleBufferDelegate(recorder, queue: DispatchQueue(label: "com.whisper-glass.capture"))
            captureSession.addOutput(audioOutput)

            captureSession.startRunning()
            self.captureRecorder = recorder
            self.captureSessionRef = captureSession
            currentRecordingURL = url
            isRecording = true
            indicatorPanel?.show(state: .recording)

            Self.log("Recording started → \(url.lastPathComponent)")
        } catch {
            Self.log("ERROR starting recording: \(error)")
        }
    }

    func stopRecordingAndTranscribe() {
        guard isRecording else { return }

        // Stop capture session
        captureSessionRef?.stopRunning()
        captureSessionRef = nil
        captureRecorder = nil
        isRecording = false

        guard let url = currentRecordingURL else { return }
        currentRecordingURL = nil

        indicatorPanel?.updateState(.transcribing)
        Self.log("Recording stopped")

        // Transcribe on background, paste on main
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            do {
                // Read recorded file in native format, convert to 16kHz mono Float32
                let audioFile = try AVAudioFile(forReading: url)
                let srcFormat = audioFile.processingFormat
                let frameCount = AVAudioFrameCount(audioFile.length)

                AppDelegate.log("File: \(frameCount) frames, \(srcFormat.sampleRate)Hz, \(srcFormat.channelCount)ch")

                guard frameCount > 800 else {  // minimum ~50ms of audio
                    AppDelegate.log("Recording too short (\(frameCount) frames)")
                    try? FileManager.default.removeItem(at: url)
                    await MainActor.run { self.indicatorPanel?.hide() }
                    return
                }

                guard let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: frameCount) else {
                    await MainActor.run { self.indicatorPanel?.hide() }
                    return
                }
                try audioFile.read(into: srcBuffer)

                // High-quality conversion to 16kHz mono Float32 for Whisper
                let whisperFormat = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: 16000,
                    channels: 1,
                    interleaved: false
                )!

                let outFrameCount = AVAudioFrameCount(Double(frameCount) * 16000.0 / srcFormat.sampleRate) + 1
                guard let outBuffer = AVAudioPCMBuffer(pcmFormat: whisperFormat, frameCapacity: outFrameCount) else {
                    await MainActor.run { self.indicatorPanel?.hide() }
                    return
                }

                let converter = AVAudioConverter(from: srcFormat, to: whisperFormat)!
                var convError: NSError?
                var inputConsumed = false
                converter.convert(to: outBuffer, error: &convError) { _, outStatus in
                    if inputConsumed {
                        outStatus.pointee = .endOfStream
                        return nil
                    }
                    inputConsumed = true
                    outStatus.pointee = .haveData
                    return srcBuffer
                }

                guard convError == nil else {
                    AppDelegate.log("Conversion error: \(convError!)")
                    try? FileManager.default.removeItem(at: url)
                    await MainActor.run { self.indicatorPanel?.hide() }
                    return
                }

                guard let floatData = outBuffer.floatChannelData?[0] else {
                    await MainActor.run { self.indicatorPanel?.hide() }
                    return
                }
                let samples = Array(UnsafeBufferPointer(start: floatData, count: Int(outBuffer.frameLength)))
                let duration = Double(samples.count) / 16000.0

                AppDelegate.log("Transcribing \(String(format: "%.1f", duration))s...")

                // Transcribe
                let segments = try await self.transcriptionEngine.transcribeAudio(samples)

                // Filter junk
                let junk = ["[BLANK_AUDIO]", "[MUSIC]", "[SILENCE]", "(silence)", "[NO_SPEECH]"]
                let raw = segments
                    .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { t in !t.isEmpty && !junk.contains(where: { t.contains($0) }) }
                    .joined(separator: " ")

                // Collapse runs of whitespace into single spaces
                let text = raw.replacingOccurrences(
                    of: "\\s+", with: " ", options: .regularExpression
                ).trimmingCharacters(in: .whitespaces)

                AppDelegate.log("Result: \"\(text)\"")

                if !text.isEmpty {
                    await MainActor.run {
                        self.insertText(text)
                        self.indicatorPanel?.updateState(.done)
                        // Auto-hide after 1.5s
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.indicatorPanel?.hide()
                        }
                    }
                } else {
                    await MainActor.run { self.indicatorPanel?.hide() }
                }

                try? FileManager.default.removeItem(at: url)

            } catch {
                AppDelegate.log("ERROR: \(error)")
                await MainActor.run { self.indicatorPanel?.hide() }
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Text Insertion (open-wispr approach)

    private func insertText(_ text: String) {
        let pasteboard = NSPasteboard.general
        let saved = savePasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Brief delay to let modifier keys (⌃⇧) fully release after the
        // hotkey before posting Cmd+V — prevents stray modifiers from
        // leaking into the paste event or the target app inserting a space.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.simulatePaste()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.restorePasteboard(pasteboard, items: saved)
            }
        }
        Self.log("Pasted \(text.count) chars")
    }

    private func savePasteboard(_ pb: NSPasteboard) -> [[(NSPasteboard.PasteboardType, Data)]] {
        guard let items = pb.pasteboardItems else { return [] }
        return items.map { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        }
    }

    private func restorePasteboard(_ pb: NSPasteboard, items: [[(NSPasteboard.PasteboardType, Data)]]) {
        pb.clearContents()
        guard !items.isEmpty else { return }
        pb.writeObjects(items.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entries { item.setData(data, forType: type) }
            return item
        })
    }

    private func simulatePaste() {
        // Use a clean event source so stray modifier state (⌃⇧ from the
        // hotkey) doesn't bleed into the Cmd+V paste event.
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else {
            Self.log("CGEvent paste failed")
            return
        }
        // Explicitly set ONLY Cmd — no Control, Shift, or Option
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    // MARK: - Toggle (menu bar)

    func toggleRecording() {
        if isRecording {
            stopRecordingAndTranscribe()
        } else {
            startRecording()
        }
    }

    // MARK: - Model

    private func loadSavedModel() {
        let mm = ModelManager()
        let raw = UserDefaults.standard.string(forKey: "WhisperGlass.downloadedModel") ?? "base"
        let model = WhisperModel(rawValue: raw) ?? .base

        guard mm.isModelDownloaded(model) else {
            Self.log("No model found")
            return
        }

        Self.log("Loading \(model.displayName)...")
        Task {
            do {
                try await transcriptionEngine.loadModel(model)
                Self.log("Model ready")
            } catch {
                Self.log("Model error: \(error)")
            }
        }
    }

    // MARK: - Onboarding

    private var shouldShowOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: Self.hasCompletedOnboardingKey)
    }

    private func showOnboarding() {
        let view = OnboardingView { [weak self] in self?.handleOnboardingComplete() }
        let hv = NSHostingView(rootView: view)
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.contentView = hv
        w.title = "Welcome to WhisperGlass"
        w.center()
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = w
    }

    private func handleOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: Self.hasCompletedOnboardingKey)
        onboardingWindow?.close()
        onboardingWindow = nil
        NSApp.setActivationPolicy(.accessory)
        loadSavedModel()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

}

// MARK: - AVCaptureSession Audio Recorder

/// Writes AVCaptureSession audio buffers to a WAV file in the device's native format.
/// AVCaptureSession handles Bluetooth (AirPods) correctly unlike AVAudioEngine.
/// The file is created lazily from the first buffer's format description.
final class CaptureRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let url: URL
    private var file: AVAudioFile?
    private var framesWritten: Int = 0

    init(url: URL) {
        self.url = url
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc),
              let format = AVAudioFormat(streamDescription: asbd) else { return }

        // Create file lazily using the actual device format
        if file == nil {
            do {
                file = try AVAudioFile(forWriting: url, settings: format.settings)
                AppDelegate.log("Recording format: \(format.sampleRate)Hz, \(format.channelCount)ch")
            } catch {
                AppDelegate.log("Failed to create audio file: \(error)")
                return
            }
        }

        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        // Copy sample data into PCM buffer
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let length = CMBlockBufferGetDataLength(blockBuffer)
        let destPtr: UnsafeMutableRawPointer
        if format.isInterleaved {
            guard let channelData = pcmBuffer.floatChannelData else { return }
            destPtr = UnsafeMutableRawPointer(channelData[0])
        } else {
            guard let channelData = pcmBuffer.floatChannelData else { return }
            destPtr = UnsafeMutableRawPointer(channelData[0])
        }
        CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: destPtr)

        do {
            try file?.write(from: pcmBuffer)
            framesWritten += frameCount
        } catch {
            AppDelegate.log("Capture write error: \(error)")
        }
    }
}

// MARK: - Hotkey Context (passed to CGEventTap C callback)

private final class HotkeyContext {
    let keyCode: UInt16
    let mods: UInt64
    unowned let delegate: AppDelegate

    init(keyCode: UInt16, mods: UInt64, delegate: AppDelegate) {
        self.keyCode = keyCode
        self.mods = mods
        self.delegate = delegate
    }
}
