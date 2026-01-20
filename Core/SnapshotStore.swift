import Foundation

public struct ScanSnapshot: Codable {
    public var root: ScanNode
    public var createdAt: Date
    public var path: String

    public init(root: ScanNode, createdAt: Date, path: String) {
        self.root = root
        self.createdAt = createdAt
        self.path = path
    }
}

public final class SnapshotStore {
    private let baseURL: URL

    public init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        self.baseURL = base?.appendingPathComponent("DiskViz", isDirectory: true) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    public func loadLatest(for path: String) -> ScanSnapshot? {
        let url = snapshotURL(for: path)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ScanSnapshot.self, from: data)
    }

    public func save(snapshot: ScanSnapshot) {
        let url = snapshotURL(for: snapshot.path)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: url)
        }
    }

    private func snapshotURL(for path: String) -> URL {
        let safeName = path.replacingOccurrences(of: "/", with: "_")
        return baseURL.appendingPathComponent("snapshot_\(safeName).json")
    }
}
