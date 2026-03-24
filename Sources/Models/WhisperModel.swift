import Foundation

/// Available Whisper GGML model configurations.
public enum WhisperModel: String, CaseIterable, Codable, Sendable, Identifiable {
    case tiny
    case base
    case small
    case largev3Turbo

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .tiny: "Tiny"
        case .base: "Base"
        case .small: "Small"
        case .largev3Turbo: "Large v3 Turbo"
        }
    }

    /// GGML model filename
    public var filename: String {
        switch self {
        case .tiny: "ggml-tiny.bin"
        case .base: "ggml-base.bin"
        case .small: "ggml-small.bin"
        case .largev3Turbo: "ggml-large-v3-turbo.bin"
        }
    }

    /// Approximate download size in bytes
    public var downloadSize: Int64 {
        switch self {
        case .tiny: 75_000_000
        case .base: 142_000_000
        case .small: 466_000_000
        case .largev3Turbo: 1_500_000_000
        }
    }

    /// Human-readable size string
    public var sizeLabel: String {
        switch self {
        case .tiny: "75 MB"
        case .base: "142 MB"
        case .small: "466 MB"
        case .largev3Turbo: "1.5 GB"
        }
    }

    /// Hugging Face download URL for the GGML model
    public var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)")!
    }

    /// Description of accuracy/speed tradeoff
    public var tradeoffDescription: String {
        switch self {
        case .tiny: "Fast & light — good for quick notes"
        case .base: "Balanced — good for general use"
        case .small: "Accurate — great for meetings"
        case .largev3Turbo: "Maximum accuracy — best quality"
        }
    }
}
