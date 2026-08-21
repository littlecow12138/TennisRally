import Foundation
import Network

@MainActor
final class CellularNetworkMonitor: ObservableObject {
    @Published private(set) var isConstrainedOrExpensive = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ai.tennismrally.network")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConstrainedOrExpensive = path.isExpensive || path.isConstrained || path.usesInterfaceType(.cellular)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
