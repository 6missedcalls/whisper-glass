import SwiftUI

// MARK: - Partial Text View

/// Displays in-progress hypothesis text with a pulsing opacity animation.
/// Shows the live transcription before it becomes a finalized segment.
public struct PartialTextView: View {
    private let text: String

    @State private var isPulsing = false

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .opacity(isPulsing ? 0.7 : 0.4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .animation(
                    .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .onAppear {
                    isPulsing = true
                }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack {
        PartialTextView(text: "Transcribing something right now...")
        PartialTextView(text: "")
    }
    .padding()
    .frame(width: 360)
}
#endif
