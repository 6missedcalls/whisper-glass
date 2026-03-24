import AppKit
import SwiftUI

// MARK: - Overlay Panel

/// A floating panel for the transcript overlay.
///
/// Key design decisions (from Cindori's floating panel guide):
/// - `isFloatingPanel = true` enables proper floating behavior
/// - `canBecomeKey` AND `canBecomeMain` must both return `true`
///   for SwiftUI buttons and text inputs to receive events
/// - `isMovableByWindowBackground` is set on the panel, but buttons
///   still receive clicks because NSPanel routes hits to controls first
/// - Uses NSVisualEffectView for proper vibrancy without SwiftUI glass tint
public final class OverlayPanel: NSPanel {

    // MARK: - UserDefaults Keys

    private enum StorageKey {
        static let frameX = "WhisperGlass.overlay.frameX"
        static let frameY = "WhisperGlass.overlay.frameY"
        static let frameWidth = "WhisperGlass.overlay.frameWidth"
        static let frameHeight = "WhisperGlass.overlay.frameHeight"
    }

    // MARK: - Constants

    private enum Defaults {
        static let minWidth: CGFloat = 320
        static let minHeight: CGFloat = 280
        static let defaultWidth: CGFloat = 340
        static let defaultHeight: CGFloat = 520
    }

    // MARK: - Initialization

    private init(
        contentRect: NSRect,
        styleMask: NSPanel.StyleMask
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        configurePanel()
        restorePosition()
    }

    // MARK: - Factory

    public static func create(contentView: NSView) -> OverlayPanel {
        let frame = NSRect(
            x: 0,
            y: 0,
            width: Defaults.defaultWidth,
            height: Defaults.defaultHeight
        )

        let styleMask: NSPanel.StyleMask = [
            .nonactivatingPanel,
            .titled,
            .closable,
            .resizable,
            .fullSizeContentView
        ]

        let panel = OverlayPanel(
            contentRect: frame,
            styleMask: styleMask
        )

        // NSVisualEffectView gives proper system vibrancy without
        // the wallpaper color tint that SwiftUI .glassEffect causes.
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active

        contentView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor)
        ])

        panel.contentView = visualEffect
        return panel
    }

    // MARK: - Configuration

    private func configurePanel() {
        // Floating behavior
        isFloatingPanel = true
        level = .floating
        collectionBehavior.insert(.fullScreenAuxiliary)

        // Appearance
        backgroundColor = .clear
        isOpaque = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden

        // Interaction — canBecomeKey/Main + NOT movableByBackground
        // is the key combination. isMovableByWindowBackground eats
        // mouse events that should go to SwiftUI buttons inside NSHostingView.
        isMovableByWindowBackground = false
        becomesKeyOnlyIfNeeded = false
        acceptsMouseMovedEvents = true

        // Lifecycle
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        minSize = NSSize(
            width: Defaults.minWidth,
            height: Defaults.minHeight
        )
    }

    // MARK: - Position Persistence

    private func restorePosition() {
        let defaults = UserDefaults.standard

        guard defaults.object(forKey: StorageKey.frameX) != nil else {
            center()
            return
        }

        let restoredFrame = NSRect(
            x: defaults.double(forKey: StorageKey.frameX),
            y: defaults.double(forKey: StorageKey.frameY),
            width: max(defaults.double(forKey: StorageKey.frameWidth), Defaults.minWidth),
            height: max(defaults.double(forKey: StorageKey.frameHeight), Defaults.minHeight)
        )

        setFrame(restoredFrame, display: true)
    }

    public func savePosition() {
        let defaults = UserDefaults.standard
        let currentFrame = frame

        defaults.set(currentFrame.origin.x, forKey: StorageKey.frameX)
        defaults.set(currentFrame.origin.y, forKey: StorageKey.frameY)
        defaults.set(currentFrame.size.width, forKey: StorageKey.frameWidth)
        defaults.set(currentFrame.size.height, forKey: StorageKey.frameHeight)
    }

    // MARK: - Overrides

    /// Both canBecomeKey AND canBecomeMain must be true for SwiftUI
    /// buttons, pickers, and text fields inside the panel to work.
    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }

    override public func resignMain() {
        super.resignMain()
        savePosition()
    }
}
