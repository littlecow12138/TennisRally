import Foundation

struct VisionModelCatalog: Equatable, Sendable {
    let id: String
    let displayName: String
    let formatLabel: String
    let approximateBytes: Int64
    let remoteURL: URL
    let fileName: String

    static let miniCPMV4 = VisionModelCatalog(
        id: "minicpm-v-4",
        displayName: "MiniCPM-V 4.0",
        formatLabel: "On-device vision · GGUF",
        approximateBytes: 2_100_000_000,
        remoteURL: URL(string: "https://huggingface.co/openbmb/MiniCPM-V-4-gguf/resolve/main/ggml-model-Q4_0.gguf")!,
        fileName: "minicpm-v4-ggml-model-Q4_0.gguf"
    )

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

enum VisionModelStoreError: LocalizedError {
    case alreadyDownloading
    case notDownloading

    var errorDescription: String? {
        switch self {
        case .alreadyDownloading: return "Download already in progress."
        case .notDownloading: return "No download in progress."
        }
    }
}
