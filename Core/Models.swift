import Foundation

public enum NodeKind: String, Codable, Sendable {
    case file
    case directory
    case symlink
    case other
}

public struct ScanMetrics: Codable, Sendable {
    public var logicalBytes: UInt64
    public var allocatedBytes: UInt64

    public static let zero = ScanMetrics(logicalBytes: 0, allocatedBytes: 0)

    public mutating func add(_ other: ScanMetrics) {
        logicalBytes &+= other.logicalBytes
        allocatedBytes &+= other.allocatedBytes
    }
}

public struct ScanOptions: Sendable {
    public var includeHidden: Bool
    public var includePackages: Bool
    public var excludeSystemMetadata: Bool
    public var followSymlinks: Bool
    public var concurrentWorkers: Int

    public init(
        includeHidden: Bool = true,
        includePackages: Bool = true,
        excludeSystemMetadata: Bool = true,
        followSymlinks: Bool = false,
        concurrentWorkers: Int = max(2, ProcessInfo.processInfo.activeProcessorCount)
    ) {
        self.includeHidden = includeHidden
        self.includePackages = includePackages
        self.excludeSystemMetadata = excludeSystemMetadata
        self.followSymlinks = followSymlinks
        self.concurrentWorkers = concurrentWorkers
    }
}

public struct ScanNode: Identifiable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var fullPath: String
    public var kind: NodeKind
    public var metrics: ScanMetrics
    public var childCount: Int
    public var fileCount: Int
    public var dirCount: Int
    public var children: [ScanNode]

    public init(
        id: UUID = UUID(),
        name: String,
        fullPath: String,
        kind: NodeKind,
        metrics: ScanMetrics,
        childCount: Int = 0,
        fileCount: Int = 0,
        dirCount: Int = 0,
        children: [ScanNode] = []
    ) {
        self.id = id
        self.name = name
        self.fullPath = fullPath
        self.kind = kind
        self.metrics = metrics
        self.childCount = childCount
        self.fileCount = fileCount
        self.dirCount = dirCount
        self.children = children
    }
}

public enum ScanEvent: Sendable {
    case progress(ScanProgress)
    case nodeDiscovered(ScanNode)
    case directoryCompleted(ScanNode)
    case error(ScanError)
}

public struct ScanProgress: Sendable {
    public var scannedItems: Int
    public var scannedDirectories: Int
    public var errors: Int
    public var elapsed: TimeInterval

    public init(scannedItems: Int, scannedDirectories: Int, errors: Int, elapsed: TimeInterval) {
        self.scannedItems = scannedItems
        self.scannedDirectories = scannedDirectories
        self.errors = errors
        self.elapsed = elapsed
    }
}

public struct ScanError: Identifiable, Sendable {
    public var id = UUID()
    public var path: String
    public var reason: String

    public init(path: String, reason: String) {
        self.path = path
        self.reason = reason
    }
}

public struct ScanResult: Sendable {
    public var root: ScanNode
    public var errors: [ScanError]
    public var duration: TimeInterval

    public init(root: ScanNode, errors: [ScanError], duration: TimeInterval) {
        self.root = root
        self.errors = errors
        self.duration = duration
    }
}
