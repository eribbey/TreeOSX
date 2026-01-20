#if canImport(SwiftUI)
import SwiftUI
import Core

struct TreemapView: View {
    let nodes: [ScanNode]
    let metric: SizeMetric
    let sizeBase: SizeBase
    var onSelect: (ScanNode) -> Void

    private let layout = TreemapLayout()
    private let formatter = SizeFormatter()

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)
                let items = layout.layout(nodes: nodes, in: rect, metric: metric.keyPath)
                for item in items {
                    let color = colorForNode(item.node)
                    context.fill(Path(item.rect), with: .color(color))
                    context.stroke(Path(item.rect), with: .color(.white.opacity(0.2)), lineWidth: 1)

                    if item.rect.width > 60, item.rect.height > 28 {
                        let text = Text("\(item.node.name)\n\(formatter.string(from: item.node.metrics[keyPath: metric.keyPath], base: sizeBase))")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                        context.draw(text, in: item.rect.insetBy(dx: 4, dy: 4), anchor: .topLeading)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                let rect = CGRect(origin: .zero, size: geometry.size).insetBy(dx: 8, dy: 8)
                let items = layout.layout(nodes: nodes, in: rect, metric: metric.keyPath)
                if let hit = items.first(where: { $0.rect.contains(value.location) }) {
                    onSelect(hit.node)
                }
            })
        }
    }

    private func colorForNode(_ node: ScanNode) -> Color {
        switch node.kind {
        case .directory:
            return Color.blue.opacity(0.6)
        case .file:
            return Color.green.opacity(0.6)
        case .symlink:
            return Color.orange.opacity(0.6)
        case .other:
            return Color.gray.opacity(0.6)
        }
    }
}
#endif
