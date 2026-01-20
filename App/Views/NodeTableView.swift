import SwiftUI
import Core
import AppKit

struct NodeTableView: View {
    let nodes: [ScanNode]
    let metric: SizeMetric
    let sizeBase: SizeBase
    let parentMetrics: ScanMetrics

    private let formatter = SizeFormatter()
    @State private var sortOrder: [KeyPathComparator<ScanNode>] = [
        .init(\.metrics.logicalBytes, order: .reverse)
    ]

    var body: some View {
        Table(sortedNodes, sortOrder: $sortOrder) {
            TableColumn("Name") { node in
                HStack {
                    Image(systemName: iconName(for: node.kind))
                    Text(node.name)
                }
                .contextMenu {
                    Button("Reveal in Finder") { reveal(node) }
                    Button("Copy Path") { copyPath(node) }
                }
            }
            TableColumn("Type") { node in
                Text(node.kind.rawValue.capitalized)
            }
            TableColumn("Logical Size") { node in
                Text(formatter.string(from: node.metrics.logicalBytes, base: sizeBase))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            TableColumn("Allocated Size") { node in
                Text(formatter.string(from: node.metrics.allocatedBytes, base: sizeBase))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            TableColumn("% of Parent") { node in
                Text(percentString(node))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var sortedNodes: [ScanNode] {
        nodes.sorted(using: sortOrder)
    }

    private func percentString(_ node: ScanNode) -> String {
        let denominator = metric == .logical ? parentMetrics.logicalBytes : parentMetrics.allocatedBytes
        guard denominator > 0 else { return "0%" }
        let numerator = metric == .logical ? node.metrics.logicalBytes : node.metrics.allocatedBytes
        let percent = Double(numerator) / Double(denominator) * 100
        return String(format: "%.1f%%", percent)
    }

    private func iconName(for kind: NodeKind) -> String {
        switch kind {
        case .directory: return "folder"
        case .file: return "doc"
        case .symlink: return "link"
        case .other: return "questionmark"
        }
    }

    private func reveal(_ node: ScanNode) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.fullPath)])
    }

    private func copyPath(_ node: ScanNode) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(node.fullPath, forType: .string)
    }
}
