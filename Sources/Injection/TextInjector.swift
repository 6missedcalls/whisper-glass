import Foundation
import os

/// A strategy that can inject text into a target application.
public protocol TextInjectionStrategy: Sendable {
    /// The injection strategy type this implementation represents.
    var strategyType: InjectionStrategy { get }

    /// Attempts to inject the given text.
    ///
    /// - Parameter text: The string to inject.
    /// - Returns: `true` if injection succeeded.
    func inject(text: String) async -> Bool
}

/// Result of a text injection attempt, including which strategy was used.
public struct InjectionResult: Sendable, Equatable {
    /// Whether the injection succeeded.
    public let success: Bool

    /// The strategy that was used (either the one that succeeded or the last attempted).
    public let strategy: InjectionStrategy

    public init(success: Bool, strategy: InjectionStrategy) {
        self.success = success
        self.strategy = strategy
    }
}

/// Coordinates text injection using a strategy pattern with automatic fallback.
///
/// Tries strategies in order: axDirect -> clipboard -> keyboard.
/// If a preferred strategy is specified, starts from that strategy and falls back.
public final class TextInjector: Sendable {

    private static let logger = Logger(
        subsystem: "com.whisper-glass",
        category: "TextInjector"
    )

    private let strategies: [InjectionStrategy: TextInjectionStrategy]

    /// Creates a new TextInjector with the given strategy implementations.
    ///
    /// - Parameter strategies: A dictionary mapping strategy types to their implementations.
    public init(strategies: [InjectionStrategy: TextInjectionStrategy]) {
        self.strategies = strategies
    }

    /// Creates a TextInjector with the default strategy chain.
    public convenience init() {
        let strategyMap: [InjectionStrategy: TextInjectionStrategy] = [
            .axDirect: AXDirectStrategy(),
            .clipboard: ClipboardInjector(),
            .keyboard: KeyboardSimulator()
        ]
        self.init(strategies: strategyMap)
    }

    /// Attempts to inject text, starting with the preferred strategy and falling back.
    ///
    /// - Parameters:
    ///   - text: The text to inject into the target application.
    ///   - strategy: The preferred strategy to try first. Defaults to `.axDirect`.
    /// - Returns: A tuple of (success, strategyUsed).
    public func inject(
        text: String,
        using strategy: InjectionStrategy? = nil
    ) async -> (Bool, InjectionStrategy) {
        let startStrategy = strategy ?? .axDirect
        return await attemptInjection(text: text, strategy: startStrategy)
    }

    // MARK: - Private

    private func attemptInjection(
        text: String,
        strategy: InjectionStrategy
    ) async -> (Bool, InjectionStrategy) {
        guard let implementation = strategies[strategy] else {
            Self.logger.warning("No implementation for strategy: \(strategy.label)")
            if let fallback = strategy.fallback {
                return await attemptInjection(text: text, strategy: fallback)
            }
            return (false, strategy)
        }

        Self.logger.info("Attempting injection via \(strategy.label)")

        let success = await implementation.inject(text: text)

        if success {
            Self.logger.info("Injection succeeded via \(strategy.label)")
            return (true, strategy)
        }

        Self.logger.warning("Injection failed via \(strategy.label), trying fallback")

        guard let fallback = strategy.fallback else {
            Self.logger.error("All injection strategies exhausted")
            return (false, strategy)
        }

        return await attemptInjection(text: text, strategy: fallback)
    }
}

// MARK: - AX Direct Strategy

/// Injects text directly via the Accessibility API.
public struct AXDirectStrategy: TextInjectionStrategy {
    public let strategyType: InjectionStrategy = .axDirect

    private static let logger = Logger(
        subsystem: "com.whisper-glass",
        category: "AXDirectStrategy"
    )

    public init() {}

    public func inject(text: String) async -> Bool {
        guard AccessibilityBridge.isProcessTrusted() else {
            Self.logger.warning("Process is not accessibility trusted")
            return false
        }

        guard let element = AccessibilityBridge.getFocusedElement() else {
            Self.logger.warning("No focused element available")
            return false
        }

        guard AccessibilityBridge.isTextInsertionSupported(for: element) else {
            Self.logger.warning("Focused element does not support text insertion")
            return false
        }

        return AccessibilityBridge.insertText(text, into: element)
    }
}
