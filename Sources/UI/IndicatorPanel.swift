import AppKit
import SwiftUI

// MARK: - Indicator Panel

/// A non-activating floating panel that shows the recording indicator.
///
/// This panel is designed to NEVER steal focus from the user's active
/// application. Unlike OverlayPanel (which needs key/main status for
/// interactive controls), this panel is purely visual — no buttons,
/// no text fields, no interaction required.
///
/// Key design decisions:
/// - `canBecomeKey = false` and `canBecomeMain = false` prevent
///   focus theft entirely
/// - `.nonactivatingPanel` style ensures the panel does not activate
///   its owning application
/// - Positioned at bottom-center of the main screen
public final class IndicatorPanel: NSPanel {

    // MARK: - Constants

    private enum Layout {
        static let panelSize = NSSize(width: 200, height: 56)
        static let bottomOffset: CGFloat = 60
        static let fadeOutDuration: TimeInterval = 0.2
    }

    // MARK: - State

    private let stateHolder = IndicatorStateHolder()
    private var hostingView: NSHostingView<IndicatorView>?

    // MARK: - Initialization

    private init(contentRect: NSRect, styleMask: NSPanel.StyleMask) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        configurePanel()
    }

    // MARK: - Factory

    /// Creates a new indicator panel ready for display.
    public static func create() -> IndicatorPanel {
        let styleMask: NSPanel.StyleMask = [
            .nonactivatingPanel,
            .utilityWindow,
            .fullSizeContentView
        ]

        // Start with a reasonable size — will auto-fit to content
        let frame = NSRect(x: 0, y: 0, width: 200, height: 56)

        let panel = IndicatorPanel(
            contentRect: frame,
            styleMask: styleMask
        )

        let hosting = NSHostingView(rootView: IndicatorView(stateHolder: panel.stateHolder))
        panel.contentView = hosting
        panel.hostingView = hosting

        return panel
    }

    // MARK: - Configuration

    private func configurePanel() {
        // Floating behavior — always on top, never activates
        isFloatingPanel = true
        level = .floating
        collectionBehavior.insert(.fullScreenAuxiliary)
        collectionBehavior.insert(.canJoinAllSpaces)

        // Appearance — transparent frame, content draws its own shape
        backgroundColor = .clear
        isOpaque = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        hasShadow = true

        // Remove standard window buttons
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        // Interaction — purely visual, never steals focus
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
    }

    // MARK: - Positioning

    private func positionAtBottomCenter() {
        guard let screen = NSScreen.main else { return }

        let size = Layout.panelSize
        let newFrame = NSRect(
            x: screen.visibleFrame.midX - (size.width / 2),
            y: screen.visibleFrame.minY + Layout.bottomOffset,
            width: size.width,
            height: size.height
        )
        setFrame(newFrame, display: true)
    }

    // MARK: - Public API

    /// Shows the panel with the given state, positioned at bottom-center.
    public func show(state: IndicatorState) {
        // Order on screen FIRST, then update state — avoids the
        // NSHostingView constraint crash on off-screen windows.
        positionAtBottomCenter()
        alphaValue = 1.0
        orderFrontRegardless()
        updateState(state)
    }

    /// Hides the panel with a fade-out animation.
    public func hide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Layout.fadeOutDuration
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.stateHolder.current = .hidden
            self?.orderOut(nil)
            self?.alphaValue = 1.0
        }
    }

    /// Updates the indicator content without changing visibility.
    public func updateState(_ state: IndicatorState) {
        stateHolder.current = state
    }

    // MARK: - Overrides

    /// Prevents this panel from ever becoming the key window.
    override public var canBecomeKey: Bool { false }

    /// Prevents this panel from ever becoming the main window.
    override public var canBecomeMain: Bool { false }
}
