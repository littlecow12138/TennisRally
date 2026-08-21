import Foundation

struct VisionModelArtifact: Equatable, Sendable {
    let fileName: String
    let remoteURL: URL
}

struct VisionModelCatalog: Equatable, Sendable {
    let id: String
    let displayName: String
    let formatLabel: String
    let approximateBytes: Int64
    let artifacts: [VisionModelArtifact]

    static let miniCPMV4 = VisionModelCatalog(
        id: "minicpm-v-4",
        displayName: "MiniCPM-V 4.0",
        formatLabel: "On-device vision · GGUF",
        // Spec/comps show ~2.1 GB for the vision pack (LLM INT4 + mmproj).
        approximateBytes: 2_100_000_000,
        artifacts: [
            VisionModelArtifact(
                fileName: "minicpm-v4-ggml-model-Q4_0.gguf",
                remoteURL: URL(string: "https://huggingface.co/openbmb/MiniCPM-V-4-gguf/resolve/main/ggml-model-Q4_0.gguf")!
            ),
            VisionModelArtifact(
                fileName: "minicpm-v4-mmproj-model-f16.gguf",
                remoteURL: URL(string: "https://huggingface.co/openbmb/MiniCPM-V-4-gguf/resolve/main/mmproj-model-f16.gguf")!
            )
        ]
    )

    var llmFileName: String { artifacts[0].fileName }
    var mmprojFileName: String { artifacts[1].fileName }

    var approximateSizeLabel: String {
        let gb = Double(approximateBytes) / 1_000_000_000
        return String(format: "%.1f GB", gb)
    }
}

enum VisionModelStatus: Equatable {
    case notDownloaded
    case downloading(progress: Double, downloadedBytes: Int64, totalBytes: Int64)
    case ready
    case failed(message: String)

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }

    var progressFraction: Double {
        if case let .downloading(progress, _, _) = self {
            return min(1, max(0, progress))
        }
        return 0
    }
}

protocol VisionModelDownloading: AnyObject {
    func download(
        from url: URL,
        to destination: URL,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws
    func cancel()
}

protocol IdleTimerControlling {
    func setIdleTimerDisabled(_ disabled: Bool)
}

@MainActor
protocol VisionModelReadiness: AnyObject {
    var isReady: Bool { get }
}

@MainActor
protocol VisionModelLocating: VisionModelReadiness {
    var llmModelURL: URL { get }
    var mmprojModelURL: URL { get }
}
