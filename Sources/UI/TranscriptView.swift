import SwiftUI

// MARK: - Transcript View

/// Main scrollable transcript view displaying segments with auto-scroll
/// and a refined empty state.
public struct TranscriptView: View {
    private let segments: [TranscriptSegment]
    private let partialText: String

    @State private var isAutoScrollEnabled = true

    public init(
        segments: [TranscriptSegment],
        partialText: String
    ) {
        self.segments = segments
        self.partialText = partialText
    }

    public var body: some View {
        if segments.isEmpty && partialText.isEmpty {
            emptyStateView
        } else {
            transcriptScrollView
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                // Outer ring
                Circle()
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    .frame(width: 80, height: 80)

                // Inner filled circle
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 64, height: 64)

                Image(systemName: "waveform")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 6) {
                Text("Ready to listen")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 3) {
                    keyCapView("⌃")
                    keyCapView("⇧")
                    keyCapView("Space")
                    Text("to start")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func keyCapView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }

    // MARK: - Transcript Scroll

    private var transcriptScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(segments) { segment in
                        TranscriptBubble(segment: segment)
                            .id(segment.id)
                    }

                    if !partialText.isEmpty {
                        PartialTextView(text: partialText)
                            .id("partial-text-anchor")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(scrollDetector)
            }
            .onChange(of: segments.count) { _, _ in
                scrollToBottomIfNeeded(proxy: proxy)
            }
            .onChange(of: partialText) { _, _ in
                scrollToBottomIfNeeded(proxy: proxy)
            }
        }
    }

    // MARK: - Scroll Detection

    private var scrollDetector: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scrollArea")).maxY
                )
        }
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { maxY in
            let threshold: CGFloat = 50
            isAutoScrollEnabled = maxY < threshold
        }
    }

    private func scrollToBottomIfNeeded(proxy: ScrollViewProxy) {
        guard isAutoScrollEnabled else { return }

        let anchor = partialText.isEmpty
            ? segments.last?.id.uuidString ?? ""
            : "partial-text-anchor"

        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(anchor, anchor: .bottom)
        }
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("With Segments") {
    TranscriptView(
        segments: [
            TranscriptSegment(text: "Hello, how are you?", startTime: 0, endTime: 1.5),
            TranscriptSegment(text: "I'm doing great, thanks for asking.", startTime: 1.5, endTime: 3.0),
            TranscriptSegment(text: "What are we working on today?", startTime: 3.0, endTime: 5.0)
        ],
        partialText: "Let me think about..."
    )
    .frame(width: 340, height: 400)
}

#Preview("Empty State") {
    TranscriptView(segments: [], partialText: "")
        .frame(width: 340, height: 400)
}
#endif
