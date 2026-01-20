import Foundation
import CoreC
import Darwin

public final class Scanner {
    public init() {}

    public func scan(
        rootPath: String,
        options: ScanOptions,
        onEvent: @escaping @Sendable (ScanEvent) -> Void
    ) async throws -> ScanResult {
        let start = Date()
        let treeBuilder = TreeBuilder()
        let progressTracker = ProgressTracker(onEvent: onEvent, start: start)
        let workStream = WorkStream()
        let rootURL = URL(fileURLWithPath: rootPath)
        let rootName = rootURL.lastPathComponent.isEmpty ? rootURL.path : rootURL.lastPathComponent
        let rootNode = await treeBuilder.makeRoot(name: rootName, path: rootURL.path)
        await workStream.enqueue(DirectoryJob(id: rootNode.id, path: rootURL.path))

        try await withThrowingTaskGroup(of: Void.self) { group in
            let workerCount = max(1, options.concurrentWorkers)
            for _ in 0..<workerCount {
                group.addTask {
                    while let job = await workStream.next() {
                        try Task.checkCancellation()
                        await self.scanDirectory(
                            job: job,
                            options: options,
                            treeBuilder: treeBuilder,
                            workStream: workStream,
                            progressTracker: progressTracker,
                            onEvent: onEvent
                        )
                        await workStream.completeJob()
                    }
                }
            }
            try await group.waitForAll()
        }

        let root = await treeBuilder.snapshot(rootID: rootNode.id)
        let errors = await treeBuilder.errors
        let duration = Date().timeIntervalSince(start)
        return ScanResult(root: root, errors: errors, duration: duration)
    }

    private func scanDirectory(
        job: DirectoryJob,
        options: ScanOptions,
        treeBuilder: TreeBuilder,
        workStream: WorkStream,
        progressTracker: ProgressTracker,
        onEvent: @escaping @Sendable (ScanEvent) -> Void
    ) async {
        let dirfd = open(job.path, O_RDONLY)
        if dirfd == -1 {
            let error = ScanError(path: job.path, reason: String(cString: strerror(errno)))
            await treeBuilder.recordError(path: job.path, reason: error.reason)
            onEvent(.error(error))
            await progressTracker.incrementErrors()
            return
        }
        defer { close(dirfd) }

        let maxEntries = 1024
        var entries = Array(repeating: dv_entry(), count: maxEntries)
        var nameBuffer = Array(repeating: CChar(0), count: 256 * 1024)
        var currentParent = job.id

        await progressTracker.incrementDirectory()

        while true {
            var usedNameBuffer: Int32 = 0
            let rawCount = dv_read_dir(dirfd, &entries, Int32(maxEntries), &nameBuffer, nameBuffer.count, &usedNameBuffer)
            if rawCount < 0 {
                let error = ScanError(path: job.path, reason: String(cString: strerror(errno)))
                await treeBuilder.recordError(path: job.path, reason: error.reason)
                onEvent(.error(error))
                await progressTracker.incrementErrors()
                return
            }
            let count = Int(rawCount)
            if count == 0 {
                break
            }

            for index in 0..<count {
                let entry = entries[index]
                let nameStart = Int(entry.name_offset)
                let nameLen = Int(entry.name_length)
                if nameLen == 0 { continue }
                let name = String(decoding: nameBuffer[nameStart..<(nameStart + nameLen)], as: UTF8.self)
                if name == "." || name == ".." { continue }
                if !options.includeHidden && name.hasPrefix(".") {
                    continue
                }
                if options.excludeSystemMetadata && Self.isSystemMetadata(name: name) {
                    continue
                }

                let fullPath = job.path.appendingPathComponent(name)
                let kind = Self.kindFromEntry(entry)

                if kind == .symlink && !options.followSymlinks {
                    let node = await treeBuilder.addNode(
                        name: name,
                        fullPath: fullPath,
                        kind: kind,
                        metrics: ScanMetrics.zero,
                        parentID: currentParent
                    )
                    onEvent(.nodeDiscovered(node))
                    await progressTracker.incrementItem()
                    continue
                }

                let metrics = ScanMetrics(logicalBytes: entry.logical_size, allocatedBytes: entry.allocated_size)
                let node = await treeBuilder.addNode(
                    name: name,
                    fullPath: fullPath,
                    kind: kind,
                    metrics: metrics,
                    parentID: currentParent
                )

                onEvent(.nodeDiscovered(node))
                await progressTracker.incrementItem()

                if kind == .directory {
                    if options.includePackages == false {
                        var isDirectory: ObjCBool = false
                        if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory), isDirectory.boolValue {
                            if fullPath.hasSuffix(".app") || fullPath.hasSuffix(".framework") {
                                continue
                            }
                        }
                    }
                    await workStream.enqueue(DirectoryJob(id: node.id, path: fullPath))
                }
            }

            if usedNameBuffer < 0 {
                break
            }
        }

        let completedNode = await treeBuilder.markDirectoryComplete(id: currentParent)
        onEvent(.directoryCompleted(completedNode))
    }

    private static func kindFromEntry(_ entry: dv_entry) -> NodeKind {
        switch entry.file_type {
        case UInt8(DT_DIR):
            return .directory
        case UInt8(DT_REG):
            return .file
        case UInt8(DT_LNK):
            return .symlink
        default:
            return .other
        }
    }

    private static func isSystemMetadata(name: String) -> Bool {
        let excluded = [
            ".Spotlight-V100",
            ".fseventsd",
            ".Trashes",
            "System Volume Information"
        ]
        return excluded.contains(name)
    }
}

private struct DirectoryJob: Sendable {
    let id: UUID
    let path: String
}

private actor WorkStream {
    private var pendingJobs: [DirectoryJob] = []
    private var waiters: [CheckedContinuation<DirectoryJob?, Never>] = []
    private var outstandingJobs: Int = 0
    private var isClosed = false

    func enqueue(_ job: DirectoryJob) {
        guard !isClosed else { return }
        outstandingJobs += 1
        if let waiter = waiters.popLast() {
            waiter.resume(returning: job)
        } else {
            pendingJobs.append(job)
        }
    }

    func next() async -> DirectoryJob? {
        if !pendingJobs.isEmpty {
            return pendingJobs.removeFirst()
        }
        if isClosed {
            return nil
        }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func completeJob() {
        guard outstandingJobs > 0 else { return }
        outstandingJobs -= 1
        if outstandingJobs == 0 {
            close()
        }
    }

    private func close() {
        isClosed = true
        for waiter in waiters {
            waiter.resume(returning: nil)
        }
        waiters.removeAll()
    }
}

private actor TreeBuilder {
    private var nodes: [UUID: MutableNode] = [:]
    private(set) var errors: [ScanError] = []

    func makeRoot(name: String, path: String) -> ScanNode {
        let root = MutableNode(
            id: UUID(),
            name: name,
            fullPath: path,
            kind: .directory,
            metrics: .zero
        )
        nodes[root.id] = root
        return root.snapshot()
    }

    func addNode(
        name: String,
        fullPath: String,
        kind: NodeKind,
        metrics: ScanMetrics,
        parentID: UUID
    ) -> ScanNode {
        let node = MutableNode(id: UUID(), name: name, fullPath: fullPath, kind: kind, metrics: metrics)
        node.parentID = parentID
        nodes[node.id] = node
        if let parent = nodes[parentID] {
            parent.children.append(node)
            parent.childCount += 1
            if kind == .directory { parent.dirCount += 1 } else { parent.fileCount += 1 }
            if kind != .directory {
                propagateMetrics(metrics, from: parentID)
            }
        }
        return node.snapshot()
    }

    func markDirectoryComplete(id: UUID) -> ScanNode {
        guard let node = nodes[id] else {
            return ScanNode(name: "", fullPath: "", kind: .directory, metrics: .zero)
        }
        return node.snapshot()
    }

    func snapshot(rootID: UUID) -> ScanNode {
        guard let node = nodes[rootID] else {
            return ScanNode(name: "", fullPath: "", kind: .directory, metrics: .zero)
        }
        return node.snapshot(recursive: true)
    }

    func recordError(path: String, reason: String) {
        errors.append(ScanError(path: path, reason: reason))
    }

    private func propagateMetrics(_ metrics: ScanMetrics, from parentID: UUID) {
        var currentID: UUID? = parentID
        while let id = currentID, let node = nodes[id] {
            node.addMetrics(metrics)
            currentID = node.parentID
        }
    }
}

private final class MutableNode {
    let id: UUID
    let name: String
    let fullPath: String
    let kind: NodeKind
    var metrics: ScanMetrics
    var childCount: Int = 0
    var fileCount: Int = 0
    var dirCount: Int = 0
    var children: [MutableNode] = []
    var parentID: UUID?

    init(id: UUID, name: String, fullPath: String, kind: NodeKind, metrics: ScanMetrics) {
        self.id = id
        self.name = name
        self.fullPath = fullPath
        self.kind = kind
        self.metrics = metrics
    }

    func addMetrics(_ other: ScanMetrics) {
        metrics.add(other)
    }

    func snapshot(recursive: Bool = false) -> ScanNode {
        let kids = recursive ? children.map { $0.snapshot(recursive: true) } : []
        return ScanNode(
            id: id,
            name: name,
            fullPath: fullPath,
            kind: kind,
            metrics: metrics,
            childCount: childCount,
            fileCount: fileCount,
            dirCount: dirCount,
            children: kids
        )
    }
}

private actor ProgressTracker {
    private var scannedItems: Int = 0
    private var scannedDirectories: Int = 0
    private var errors: Int = 0
    private let onEvent: @Sendable (ScanEvent) -> Void
    private let start: Date

    init(onEvent: @escaping @Sendable (ScanEvent) -> Void, start: Date) {
        self.onEvent = onEvent
        self.start = start
    }

    func incrementItem() {
        scannedItems += 1
        emit()
    }

    func incrementDirectory() {
        scannedDirectories += 1
        emit()
    }

    func incrementErrors() {
        errors += 1
        emit()
    }

    private func emit() {
        let elapsed = Date().timeIntervalSince(start)
        onEvent(.progress(ScanProgress(scannedItems: scannedItems, scannedDirectories: scannedDirectories, errors: errors, elapsed: elapsed)))
    }
}

private extension String {
    func appendingPathComponent(_ component: String) -> String {
        (self as NSString).appendingPathComponent(component)
    }
}
