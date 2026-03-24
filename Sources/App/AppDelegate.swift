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

    private static let axPromptedKey = "WhisperGlass.axPrompted"

    private func ensureAccessibilityAndStartMonitor() {
        let trusted = AXIsProcessTrusted()
        let bundleID = Bundle.main.bundleIdentifier ?? "nil"
        let pid = ProcessInfo.processInfo.processIdentifier
        Self.log("AX check: trusted=\(trusted), bundleID=\(bundleID), pid=\(pid)")

        if !trusted {
            // Always prompt with the dialog — it's the only reliable way
            // to get the app added to the Accessibility list
            Self.log("Prompting for Accessibility...")
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            let result = AXIsProcessTrustedWithOptions(opts)
            Self.log("AXIsProcessTrustedWithOptions returned: \(result)")

            // Poll until granted
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                var count = 0
                while !AXIsProcessTrusted() {
                    Thread.sleep(forTimeInterval: 1.0)
                    count += 1
                    if count % 5 == 0 {
                        Self.log("Still waiting for AX... (\(count)s)")
                    }
                }
                Self.log("Accessibility: granted after \(count)s")
                DispatchQueue.main.async {
                    self?.startHotkeyMonitor()
                }
            }
        } else {
            startHotkeyMonitor()
        }
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

                // Suppress ALL keyDown/keyUp for our hotkey combo
                // to prevent the alert sound in the focused app
                if type == .keyDown && modsMatch {
                    if !ctx.delegate.isRecording {
                        DispatchQueue.main.async { ctx.delegate.startRecording() }
                    }
                    return nil // SUPPRESS
                } else if type == .keyUp && kc == ctx.keyCode {
                    // Suppress keyUp for Space when we were recording
                    // (modifiers may have already been released)
                    if ctx.delegate.isRecording {
                        DispatchQueue.main.async { ctx.delegate.stopRecordingAndTranscribe() }
                    }
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
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode

            // Use AVCaptureSession instead of AVAudioEngine for recording.
            // AVAudioEngine has a well-documented bug where Bluetooth devices
            // (AirPods) deliver 0 frames. AVCaptureSession handles Bluetooth
            // audio input correctly and respects the system default mic.
            let captureSession = AVCaptureSession()
            guard let mic = AVCaptureDevice.default(for: .audio),
                  let micInput = try? AVCaptureDeviceInput(device: mic) else {
                Self.log("ERROR: Cannot access microphone")
                return
            }
            captureSession.addInput(micInput)

            let audioOutput = AVCaptureAudioDataOutput()
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: false
            ]

            let whisperFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16000,
                channels: 1,
                interleaved: true
            )!
            let file = try AVAudioFile(forWriting: url, settings: whisperFormat.settings)

            Self.log("Mic: \(mic.localizedName), capture session")

            let recorder = CaptureRecorder(file: file)
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
                // Read recorded file (already 16kHz mono Float32 from AVCaptureSession)
                let audioFile = try AVAudioFile(forReading: url)
                let frameCount = AVAudioFrameCount(audioFile.length)

                AppDelegate.log("File: \(frameCount) frames")

                guard frameCount > 800 else {  // minimum ~50ms of audio
                    AppDelegate.log("Recording too short (\(frameCount) frames)")
                    try? FileManager.default.removeItem(at: url)
                    await MainActor.run { self.indicatorPanel?.hide() }
                    return
                }

                // Read all frames — file is already in Whisper format (16kHz mono Float32)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount) else {
                    await MainActor.run { self.indicatorPanel?.hide() }
                    return
                }
                try audioFile.read(into: buffer)

                guard let floatData = buffer.floatChannelData?[0] else { return }
                let samples = Array(UnsafeBufferPointer(start: floatData, count: Int(buffer.frameLength)))
                let duration = Double(samples.count) / 16000.0

                AppDelegate.log("Transcribing \(String(format: "%.1f", duration))s...")

                // Transcribe
                let segments = try await self.transcriptionEngine.transcribeAudio(samples)

                // Filter junk
                let junk = ["[BLANK_AUDIO]", "[MUSIC]", "[SILENCE]", "(silence)", "[NO_SPEECH]"]
                let text = segments
                    .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { t in !t.isEmpty && !junk.contains(where: { t.contains($0) }) }
                    .joined(separator: " ")

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
        simulatePaste()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.restorePasteboard(pasteboard, items: saved)
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
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else {
            fputs("[WG] CGEvent paste failed\n", stderr)
            return
        }
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

/// Writes AVCaptureSession audio buffers to an AVAudioFile.
/// AVCaptureSession handles Bluetooth (AirPods) correctly unlike AVAudioEngine.
final class CaptureRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let file: AVAudioFile
    private var framesWritten: Int = 0

    init(file: AVAudioFile) {
        self.file = file
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        let length = CMBlockBufferGetDataLength(blockBuffer)
        var data = Data(count: length)
        data.withUnsafeMutableBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else { return }
            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: ptr)
        }

        // Convert CMSampleBuffer to AVAudioPCMBuffer
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else { return }

        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard let format = AVAudioFormat(streamDescription: asbd),
              let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }

        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        if let channelData = pcmBuffer.floatChannelData {
            data.withUnsafeBytes { rawBuffer in
                guard let src = rawBuffer.baseAddress else { return }
                memcpy(channelData[0], src, length)
            }
        }

        do {
            try file.write(from: pcmBuffer)
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
