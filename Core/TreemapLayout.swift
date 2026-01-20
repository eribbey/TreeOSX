import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#else
public typealias CGFloat = Double

public struct CGRect: Sendable {
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: CGFloat { x }
    public var minY: CGFloat { y }
}
#endif

public struct TreemapItem: Identifiable {
    public let id: UUID
    public let node: ScanNode
    public let rect: CGRect
}

public struct TreemapLayout {
    public init() {}

    public func layout(nodes: [ScanNode], in rect: CGRect, metric: KeyPath<ScanMetrics, UInt64>) -> [TreemapItem] {
        let sorted = nodes.sorted { $0.metrics[keyPath: metric] > $1.metrics[keyPath: metric] }
        let total = sorted.reduce(UInt64(0)) { $0 &+ $1.metrics[keyPath: metric] }
        guard total > 0 else { return [] }
        let weights = sorted.map { CGFloat($0.metrics[keyPath: metric]) / CGFloat(total) }
        let rectangles = squarify(weights: weights, rect: rect)
        return zip(sorted, rectangles).map { TreemapItem(id: $0.0.id, node: $0.0, rect: $0.1) }
    }

    private func squarify(weights: [CGFloat], rect: CGRect) -> [CGRect] {
        var remaining = rect
        var rows: [CGRect] = []
        var row: [CGFloat] = []
        var rowWeight: CGFloat = 0
        var index = 0

        func worstAspect(_ row: [CGFloat], in rect: CGRect) -> CGFloat {
            guard let maxWeight = row.max(), let minWeight = row.min() else { return .infinity }
            let sum = row.reduce(0, +)
            let side = min(rect.width, rect.height)
            let squared = side * side
            return max((squared * maxWeight) / (sum * sum), (sum * sum) / (squared * minWeight))
        }

        func layoutRow(_ row: [CGFloat], in rect: CGRect) -> [CGRect] {
            let sum = row.reduce(0, +)
            var frames: [CGRect] = []
            if rect.width >= rect.height {
                let height = rect.height * sum
                var x = rect.minX
                for weight in row {
                    let width = rect.width * weight / sum
                    frames.append(CGRect(x: x, y: rect.minY, width: width, height: height))
                    x += width
                }
                remaining = CGRect(x: rect.minX, y: rect.minY + height, width: rect.width, height: rect.height - height)
            } else {
                let width = rect.width * sum
                var y = rect.minY
                for weight in row {
                    let height = rect.height * weight / sum
                    frames.append(CGRect(x: rect.minX, y: y, width: width, height: height))
                    y += height
                }
                remaining = CGRect(x: rect.minX + width, y: rect.minY, width: rect.width - width, height: rect.height)
            }
            return frames
        }

        while index < weights.count {
            let weight = weights[index]
            let newRow = row + [weight]
            if row.isEmpty || worstAspect(newRow, in: remaining) <= worstAspect(row, in: remaining) {
                row = newRow
                rowWeight += weight
                index += 1
            } else {
                rows.append(contentsOf: layoutRow(row, in: remaining))
                row.removeAll(keepingCapacity: true)
                rowWeight = 0
            }
        }

        if !row.isEmpty {
            rows.append(contentsOf: layoutRow(row, in: remaining))
        }

        return rows
    }
}
