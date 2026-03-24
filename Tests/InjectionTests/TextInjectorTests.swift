import Foundation
import Testing
@testable import WhisperGlassCore

// MARK: - Mock Strategies

/// A mock injection strategy that returns a configurable success/failure result.
struct MockInjectionStrategy: TextInjectionStrategy, @unchecked Sendable {
    let strategyType: InjectionStrategy
    let shouldSucceed: Bool
    private(set) var injectCallCount: Int = 0

    init(strategyType: InjectionStrategy, shouldSucceed: Bool) {
        self.strategyType = strategyType
        self.shouldSucceed = shouldSucceed
    }

    func inject(text: String) async -> Bool {
        shouldSucceed
    }
}

/// Tracks which strategies were attempted and in what order.
final class StrategyTracker: @unchecked Sendable {
    private(set) var attemptedStrategies: [InjectionStrategy] = []
    private let lock = NSLock()

    func record(_ strategy: InjectionStrategy) {
        lock.lock()
        attemptedStrategies.append(strategy)
        lock.unlock()
    }

    var attempts: [InjectionStrategy] {
        lock.lock()
        defer { lock.unlock() }
        return attemptedStrategies
    }
}

/// A tracking mock that records when it was called.
struct TrackingMockStrategy: TextInjectionStrategy, @unchecked Sendable {
    let strategyType: InjectionStrategy
    let shouldSucceed: Bool
    let tracker: StrategyTracker

    func inject(text: String) async -> Bool {
        tracker.record(strategyType)
        return shouldSucceed
    }
}

// MARK: - Tests

@Suite("TextInjector")
struct TextInjectorTests {

    @Test("Falls back from axDirect to clipboard when axDirect fails")
    func fallbackToClipboard() async {
        let tracker = StrategyTracker()

        let strategies: [InjectionStrategy: TextInjectionStrategy] = [
            .axDirect: TrackingMockStrategy(
                strategyType: .axDirect,
                shouldSucceed: false,
                tracker: tracker
            ),
            .clipboard: TrackingMockStrategy(
                strategyType: .clipboard,
                shouldSucceed: true,
                tracker: tracker
            ),
            .keyboard: TrackingMockStrategy(
                strategyType: .keyboard,
                shouldSucceed: true,
                tracker: tracker
            )
        ]

        let injector = TextInjector(strategies: strategies)
        let (success, strategy) = await injector.inject(text: "hello")

        #expect(success == true)
        #expect(strategy == .clipboard)
        #expect(tracker.attempts == [.axDirect, .clipboard])
    }

    @Test("Falls back through entire chain to keyboard")
    func fallbackToKeyboard() async {
        let tracker = StrategyTracker()

        let strategies: [InjectionStrategy: TextInjectionStrategy] = [
            .axDirect: TrackingMockStrategy(
                strategyType: .axDirect,
                shouldSucceed: false,
                tracker: tracker
            ),
            .clipboard: TrackingMockStrategy(
                strategyType: .clipboard,
                shouldSucceed: false,
                tracker: tracker
            ),
            .keyboard: TrackingMockStrategy(
                strategyType: .keyboard,
                shouldSucceed: true,
                tracker: tracker
            )
        ]

        let injector = TextInjector(strategies: strategies)
        let (success, strategy) = await injector.inject(text: "hello")

        #expect(success == true)
        #expect(strategy == .keyboard)
        #expect(tracker.attempts == [.axDirect, .clipboard, .keyboard])
    }

    @Test("Returns false when all strategies fail")
    func allStrategiesFail() async {
        let strategies: [InjectionStrategy: TextInjectionStrategy] = [
            .axDirect: MockInjectionStrategy(strategyType: .axDirect, shouldSucceed: false),
            .clipboard: MockInjectionStrategy(strategyType: .clipboard, shouldSucceed: false),
            .keyboard: MockInjectionStrategy(strategyType: .keyboard, shouldSucceed: false)
        ]

        let injector = TextInjector(strategies: strategies)
        let (success, _) = await injector.inject(text: "hello")

        #expect(success == false)
    }

    @Test("Reports which strategy succeeded - axDirect")
    func reportsAxDirectSuccess() async {
        let strategies: [InjectionStrategy: TextInjectionStrategy] = [
            .axDirect: MockInjectionStrategy(strategyType: .axDirect, shouldSucceed: true),
            .clipboard: MockInjectionStrategy(strategyType: .clipboard, shouldSucceed: true),
            .keyboard: MockInjectionStrategy(strategyType: .keyboard, shouldSucceed: true)
        ]

        let injector = TextInjector(strategies: strategies)
        let (success, strategy) = await injector.inject(text: "hello")

        #expect(success == true)
        #expect(strategy == .axDirect)
    }

    @Test("Reports which strategy succeeded - clipboard")
    func reportsClipboardSuccess() async {
        let strategies: [InjectionStrategy: TextInjectionStrategy] = [
            .axDirect: MockInjectionStrategy(strategyType: .axDirect, shouldSucceed: false),
            .clipboard: MockInjectionStrategy(strategyType: .clipboard, shouldSucceed: true),
            .keyboard: MockInjectionStrategy(strategyType: .keyboard, shouldSucceed: true)
        ]

        let injector = TextInjector(strategies: strategies)
        let (success, strategy) = await injector.inject(text: "hello")

        #expect(success == true)
        #expect(strategy == .clipboard)
    }

    @Test("Uses preferred strategy when specified")
    func usesPreferredStrategy() async {
        let tracker = StrategyTracker()

        let strategies: [InjectionStrategy: TextInjectionStrategy] = [
            .axDirect: TrackingMockStrategy(
                strategyType: .axDirect,
                shouldSucceed: true,
                tracker: tracker
            ),
            .clipboard: TrackingMockStrategy(
                strategyType: .clipboard,
                shouldSucceed: true,
                tracker: tracker
            ),
            .keyboard: TrackingMockStrategy(
                strategyType: .keyboard,
                shouldSucceed: true,
                tracker: tracker
            )
        ]

        let injector = TextInjector(strategies: strategies)
        let (success, strategy) = await injector.inject(text: "hello", using: .clipboard)

        #expect(success == true)
        #expect(strategy == .clipboard)
        // Should only attempt clipboard, not axDirect
        #expect(tracker.attempts == [.clipboard])
    }

    @Test("Preferred strategy falls back on failure")
    func preferredStrategyFallback() async {
        let tracker = StrategyTracker()

        let strategies: [InjectionStrategy: TextInjectionStrategy] = [
            .axDirect: TrackingMockStrategy(
                strategyType: .axDirect,
                shouldSucceed: true,
                tracker: tracker
            ),
            .clipboard: TrackingMockStrategy(
                strategyType: .clipboard,
                shouldSucceed: false,
                tracker: tracker
            ),
            .keyboard: TrackingMockStrategy(
                strategyType: .keyboard,
                shouldSucceed: true,
                tracker: tracker
            )
        ]

        let injector = TextInjector(strategies: strategies)
        let (success, strategy) = await injector.inject(text: "hello", using: .clipboard)

        #expect(success == true)
        #expect(strategy == .keyboard)
        #expect(tracker.attempts == [.clipboard, .keyboard])
    }

    @Test("InjectionResult equality")
    func injectionResultEquality() {
        let result1 = InjectionResult(success: true, strategy: .axDirect)
        let result2 = InjectionResult(success: true, strategy: .axDirect)
        let result3 = InjectionResult(success: false, strategy: .clipboard)

        #expect(result1 == result2)
        #expect(result1 != result3)
    }
}
