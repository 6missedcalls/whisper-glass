import SwiftUI

// MARK: - Transcript Bubble

/// Displays a single transcript segment as a subtle card.
/// No heavy glass — just a light background fill for visual separation.
public struct TranscriptBubble: View {
    private let segment: TranscriptSegment

    public init(segment: TranscriptSegment) {
        self.segment = segment
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(segment.text)
                .font(.system(size: 13.5))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Text(formattedTimestamp)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .transition(
            .move(edge: .bottom)
            .combined(with: .opacity)
        )
    }

    private var formattedTimestamp: String {
        segment.createdAt.formatted(
            .dateTime.hour().minute().second()
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 10) {
        TranscriptBubble(
            segment: TranscriptSegment(
                text: "Hello, this is a test transcript segment.",
                startTime: 0.0,
                endTime: 2.5
            )
        )
        TranscriptBubble(
            segment: TranscriptSegment(
                text: "Another segment with more text to show wrapping behavior in the bubble.",
                startTime: 2.5,
                endTime: 5.0
            )
        )
    }
    .padding(16)
    .frame(width: 340)
}
#endif
