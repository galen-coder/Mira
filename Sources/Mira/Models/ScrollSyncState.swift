import Foundation

enum ScrollSyncSide {
    case editor
    case preview
}

final class ScrollSyncState: ObservableObject {
    @Published private(set) var source: ScrollSyncSide?
    @Published private(set) var ratio = 0.0
    @Published private(set) var revision = 0

    func update(from source: ScrollSyncSide, ratio: Double) {
        self.source = source
        self.ratio = min(max(ratio, 0), 1)
        revision += 1
    }
}
