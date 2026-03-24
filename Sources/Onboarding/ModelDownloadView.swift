import SwiftUI

// MARK: - Download State

/// Represents the lifecycle of a model download.
public enum ModelDownloadState: Equatable {
    case notStarted
    case downloading(progress: Double)
    case completed
    case failed(message: String)

    public static func == (lhs: ModelDownloadState, rhs: ModelDownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted): true
        case (.downloading(let a), .downloading(let b)): a == b
        case (.completed, .completed): true
        case (.failed(let a), .failed(let b)): a == b
        default: false
        }
    }
}

// MARK: - Model Download View

/// Displays download progress for a selected Whisper model.
/// Shows a glass card with model info, progress bar, and action buttons.
public struct ModelDownloadView: View {
    private let model: WhisperModel
    private let onDownload: () -> Void
    private let onCancel: () -> Void

    private let downloadState: ModelDownloadState

    public init(
        model: WhisperModel,
        downloadState: ModelDownloadState,
        onDownload: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.model = model
        self.downloadState = downloadState
        self.onDownload = onDownload
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 16) {
            headerSection
            progressSection
            actionSection
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.headline)

                Text(model.sizeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        Group {
            switch downloadState {
            case .notStarted:
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)

            case .downloading:
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)

            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressSection: some View {
        switch downloadState {
        case .notStarted:
            Text(model.tradeoffDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .downloading(let progress):
            VStack(spacing: 8) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)

                Text(percentageLabel(for: progress))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

        case .completed:
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
                Text("Ready")
                    .foregroundStyle(.green)
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)

        case .failed(let message):
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionSection: some View {
        switch downloadState {
        case .notStarted, .failed:
            Button(action: onDownload) {
                Label("Download", systemImage: "arrow.down.to.line")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .downloading:
            Button(role: .cancel, action: onCancel) {
                Label("Cancel", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

        case .completed:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private func percentageLabel(for progress: Double) -> String {
        let clamped = min(max(progress, 0), 1)
        let percent = Int(clamped * 100)
        return "\(percent)%"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Not Started") {
    ModelDownloadView(
        model: .small,
        downloadState: .notStarted,
        onDownload: {},
        onCancel: {}
    )
    .padding()
    .frame(width: 400)
}

#Preview("Downloading") {
    ModelDownloadView(
        model: .small,
        downloadState: .downloading(progress: 0.45),
        onDownload: {},
        onCancel: {}
    )
    .padding()
    .frame(width: 400)
}

#Preview("Completed") {
    ModelDownloadView(
        model: .small,
        downloadState: .completed,
        onDownload: {},
        onCancel: {}
    )
    .padding()
    .frame(width: 400)
}
#endif
