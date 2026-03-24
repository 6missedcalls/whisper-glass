import AppKit
import CoreGraphics
import os

/// Global hotkey manager. Tries CGEventTap first (requires Input Monitoring),
/// falls back to NSEvent.addGlobalMonitorForEvents (requires Accessibility).
public final class HotkeyManager {

    private static let logger = Logger(
        subsystem: "com.whisper-glass",
        category: "HotkeyManager"
    )

    private struct HotkeyBinding {
        let action: HotkeyAction
        let keyCode: UInt16
        let cgFlags: CGEventFlags
        let nsFlags: NSEvent.ModifierFlags
        let handler: () -> Void
    }

    // MARK: - State

    private var bindings: [HotkeyAction: HotkeyBinding] = [:]
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isMonitoring = false
    private var usingCGEventTap = false

    // MARK: - Lifecycle

    public init() {}

    deinit {
        stopMonitoring()
    }

    // MARK: - Registration

    public func register(action: HotkeyAction, handler: @escaping () -> Void) {
        let binding = HotkeyBinding(
            action: action,
            keyCode: action.defaultKeyCode,
            cgFlags: [.maskControl, .maskShift],
            nsFlags: [.control, .shift],
            handler: handler
        )

        bindings[action] = binding
        fputs("[WG-HK] Registered: \(action.defaultModifierDescription) for \(action.label)\n", stderr)

        if !isMonitoring {
            startMonitoring()
        }
    }

    public func unregisterAll() {
        bindings.removeAll()
        stopMonitoring()
    }

    // MARK: - Monitoring

    public func startMonitoring() {
        guard !isMonitoring else { return }

        // Try CGEventTap first (more reliable)
        if startCGEventTap() {
            usingCGEventTap = true
            fputs("[WG-HK] Using CGEventTap (Input Monitoring granted)\n", stderr)
        } else {
            // Fall back to NSEvent global monitor
            startNSEventMonitor()
            usingCGEventTap = false
            fputs("[WG-HK] Using NSEvent global monitor (fallback)\n", stderr)
        }

        // Always add local monitor for when app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleNSEvent(event) == true {
                return nil
            }
            return event
        }

        isMonitoring = true
    }

    public func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }

        eventTap = nil
        runLoopSource = nil
        globalMonitor = nil
        localMonitor = nil
        isMonitoring = false
    }

    // MARK: - CGEventTap

    private func startCGEventTap() -> Bool {
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
            if !CGPreflightListenEventAccess() {
                fputs("[WG-HK] Input Monitoring not granted\n", stderr)
                return false
            }
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, _, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                manager.handleCGEvent(event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            fputs("[WG-HK] CGEvent.tapCreate failed\n", stderr)
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    // MARK: - NSEvent Fallback

    private func startNSEventMonitor() {
        // Track modifier state separately since global keyDown events
        // don't always include modifier flags
        var trackedModifiers: NSEvent.ModifierFlags = []

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { [weak self] event in
            if event.type == .flagsChanged {
                trackedModifiers = event.modifierFlags
                return
            }
            // Use tracked modifiers as fallback when event flags are empty
            self?.handleNSEvent(event, trackedModifiers: trackedModifiers)
        }
    }

    // MARK: - Event Handling

    private func handleCGEvent(_ event: CGEvent) {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let relevantFlags: CGEventFlags = [.maskControl, .maskShift, .maskCommand, .maskAlternate]
        let eventMods = flags.intersection(relevantFlags)

        for binding in bindings.values {
            let bindingMods = binding.cgFlags.intersection(relevantFlags)
            if keyCode == binding.keyCode && eventMods == bindingMods {
                fputs("[WG-HK] TRIGGERED (CGEvent): \(binding.action.label)\n", stderr)
                DispatchQueue.main.async { binding.handler() }
                return
            }
        }
    }

    @discardableResult
    private func handleNSEvent(_ event: NSEvent, trackedModifiers: NSEvent.ModifierFlags? = nil) -> Bool {
        let relevantMask: NSEvent.ModifierFlags = [.shift, .control, .option, .command]
        var eventMods = event.modifierFlags.intersection(relevantMask)

        // Fall back to tracked modifiers if event flags are empty
        if eventMods.isEmpty, let tracked = trackedModifiers {
            eventMods = tracked.intersection(relevantMask)
        }

        for binding in bindings.values {
            let bindingMods = binding.nsFlags.intersection(relevantMask)
            if event.keyCode == binding.keyCode && eventMods == bindingMods {
                fputs("[WG-HK] TRIGGERED (NSEvent): \(binding.action.label)\n", stderr)
                binding.handler()
                return true
            }
        }
        return false
    }
}
