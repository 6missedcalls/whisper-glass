import AVFoundation
import Combine
import Foundation
import os

/// Represents an available audio input device.
public struct AudioInputDevice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let isDefault: Bool

    public init(id: String, name: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
    }
}

/// Manages enumeration and selection of audio input devices.
///
/// Observes device connect/disconnect events and publishes updates
/// to the available device list.
@Observable
public final class AudioDeviceManager {
    private static let logger = Logger(
        subsystem: "com.whisper-glass.audio",
        category: "AudioDeviceManager"
    )

    // MARK: - Observable state

    public private(set) var availableDevices: [AudioInputDevice] = []
    public var preferredDeviceId: String?

    // MARK: - Private state

    private var deviceObserver: NSObjectProtocol?

    public init() {
        refreshDevices()
        setupDeviceObserver()
    }

    deinit {
        if let observer = deviceObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// The currently selected device, falling back to the default system device.
    public var selectedDevice: AudioInputDevice? {
        if let preferredId = preferredDeviceId {
            return availableDevices.first { $0.id == preferredId }
        }
        return defaultDevice
    }

    /// The system default audio input device.
    public var defaultDevice: AudioInputDevice? {
        availableDevices.first { $0.isDefault }
            ?? availableDevices.first
    }

    /// Selects a device by its identifier.
    ///
    /// - Parameter deviceId: The unique identifier of the device to select.
    /// - Throws: `AudioError.deviceNotFound` if no device matches the ID.
    public func selectDevice(id deviceId: String) throws {
        guard availableDevices.contains(where: { $0.id == deviceId }) else {
            throw AudioError.deviceNotFound(id: deviceId)
        }
        preferredDeviceId = deviceId
        Self.logger.info("Selected audio device: \(deviceId)")
    }

    /// Refreshes the list of available audio input devices.
    public func refreshDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )

        let defaultDeviceId = AVCaptureDevice.default(for: .audio)?.uniqueID

        let devices = discoverySession.devices.map { device in
            AudioInputDevice(
                id: device.uniqueID,
                name: device.localizedName,
                isDefault: device.uniqueID == defaultDeviceId
            )
        }

        availableDevices = devices

        Self.logger.info("Found \(devices.count) audio input device(s)")

        if let preferred = preferredDeviceId,
           !devices.contains(where: { $0.id == preferred }) {
            Self.logger.warning("Preferred device \(preferred) no longer available, resetting")
            preferredDeviceId = nil
        }
    }

    // MARK: - Private

    private func setupDeviceObserver() {
        deviceObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasConnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Self.logger.debug("Device connected notification received")
            self?.refreshDevices()
        }

        // Also observe disconnection
        NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Self.logger.debug("Device disconnected notification received")
            self?.refreshDevices()
        }
    }
}
