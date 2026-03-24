import SwiftUI

// MARK: - Model Selection Step

/// Step 4 of onboarding: lets the user pick a Whisper model and download it.
/// Uses ModelManager to perform real downloads from Hugging Face.
struct ModelSelectionStep: View {
    @Binding var selectedModel: WhisperModel
    @Binding var downloadState: ModelDownloadState

    private let modelManager = ModelManager()
    @State private var downloadTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose a Model")
                .font(.title2.weight(.semibold))

            Text("Select a Whisper model based on your speed and accuracy needs.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(WhisperModel.allCases) { model in
                        modelCard(for: model)
                    }
                }
            }

            ModelDownloadView(
                model: selectedModel,
                downloadState: downloadState,
                onDownload: { startDownload() },
                onCancel: { cancelDownload() }
            )
        }
        .onAppear {
            // If model is already downloaded, mark as completed
            if modelManager.isModelDownloaded(selectedModel) {
                downloadState = .completed
            }
        }
    }

    // MARK: - Model Card

    private func modelCard(for model: WhisperModel) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedModel = model
                // Check if this model is already downloaded
                if modelManager.isModelDownloaded(model) {
                    downloadState = .completed
                } else {
                    downloadState = .notStarted
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.subheadline.weight(.medium))
                    Text(model.tradeoffDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Text(model.sizeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if modelManager.isModelDownloaded(model) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                if selectedModel == model {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedModel == model ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        selectedModel == model ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Real Download

    private func startDownload() {
        downloadState = .downloading(progress: 0.0)

        downloadTask = Task { @MainActor in
            do {
                let _ = try await modelManager.downloadModel(
                    selectedModel,
                    onProgress: { progress in
                        Task { @MainActor in
                            downloadState = .downloading(progress: progress)
                        }
                    }
                )

                // Save which model was downloaded for the app to load
                UserDefaults.standard.set(
                    selectedModel.rawValue,
                    forKey: "WhisperGlass.downloadedModel"
                )

                downloadState = .completed
            } catch {
                if !Task.isCancelled {
                    downloadState = .failed(message: error.localizedDescription)
                }
            }
        }
    }

    private func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadState = .notStarted
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    @Previewable @State var model: WhisperModel = .base
    @Previewable @State var state: ModelDownloadState = .notStarted
    ModelSelectionStep(selectedModel: $model, downloadState: $state)
        .padding()
        .frame(width: 450, height: 500)
}
#endif
