import Foundation
import SwiftUI
import Core

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var rootNode: ScanNode?
    @Published var currentNode: ScanNode?
    @Published var progress: ScanProgress = ScanProgress(scannedItems: 0, scannedDirectories: 0, errors: 0, elapsed: 0)
    @Published var errors: [ScanError] = []
    @Published var isScanning = false
    @Published var selectedMetric: SizeMetric = .logical
    @Published var sizeBase: SizeBase = .base2
    @Published var searchText: String = ""
    @Published var statusMessage: String = ""

    private let scanner = Scanner()
    private let snapshotStore = SnapshotStore()
    private var scanTask: Task<Void, Never>?

    func startScan(path: String) {
        scanTask?.cancel()
        isScanning = true
        statusMessage = "Scanning \(path)"
        errors.removeAll()
        if let snapshot = snapshotStore.loadLatest(for: path) {
            rootNode = snapshot.root
            currentNode = snapshot.root
        }

        scanTask = Task {
            do {
                let options = ScanOptions()
                let result = try await scanner.scan(rootPath: path, options: options) { [weak self] event in
                    Task { @MainActor in
                        self?.handle(event: event)
                    }
                }
                rootNode = result.root
                currentNode = result.root
                errors = result.errors
                snapshotStore.save(snapshot: ScanSnapshot(root: result.root, createdAt: Date(), path: path))
                statusMessage = "Completed in \(String(format: "%.1f", result.duration))s"
            } catch {
                statusMessage = "Scan failed: \(error.localizedDescription)"
            }
            isScanning = false
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
        statusMessage = "Scan cancelled"
    }

    func zoom(to node: ScanNode) {
        currentNode = node
    }

    func zoomOut() {
        guard let root = rootNode else { return }
        if currentNode?.id == root.id { return }
        let path = currentNode?.fullPath ?? ""
        if let parent = findParent(of: currentNode, in: root) {
            currentNode = parent
        } else {
            currentNode = root
        }
        statusMessage = "Viewing \(path)"
    }

    var filteredChildren: [ScanNode] {
        guard let node = currentNode else { return [] }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return node.children
        }
        return node.children.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func handle(event: ScanEvent) {
        switch event {
        case .progress(let progress):
            self.progress = progress
        case .nodeDiscovered(let node):
            if rootNode == nil, node.fullPath == currentNode?.fullPath {
                rootNode = node
            }
        case .directoryCompleted:
            break
        case .error(let error):
            errors.append(error)
        }
    }

    private func findParent(of node: ScanNode?, in root: ScanNode) -> ScanNode? {
        guard let node else { return nil }
        for child in root.children {
            if child.id == node.id {
                return root
            }
            if let found = findParent(of: node, in: child) {
                return found
            }
        }
        return nil
    }
}
