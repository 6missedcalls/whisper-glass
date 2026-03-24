import SwiftUI

// MARK: - Glass Pill Button

/// A reusable glass-styled capsule button with icon and label.
public struct GlassPill: View {
    private let label: String
    private let systemImage: String
    private let action: () -> Void

    @State private var isPressed = false

    public init(
        label: String,
        systemImage: String,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))

                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .adaptiveGlass(cornerRadius: 2)
        }
        .buttonStyle(GlassPillButtonStyle())
    }
}

// MARK: - Button Style

private struct GlassPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(
                .spring(response: 0.25, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HStack {
        GlassPill(label: "Send", systemImage: "arrow.up.circle.fill") {}
        GlassPill(label: "Clear", systemImage: "trash") {}
    }
    .padding()
    .frame(width: 300, height: 100)
}
#endif
