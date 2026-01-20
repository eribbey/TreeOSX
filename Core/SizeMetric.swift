import Foundation

public enum SizeMetric: String, CaseIterable, Identifiable, Codable {
    case logical
    case allocated

    public var id: String { rawValue }

    public var keyPath: KeyPath<ScanMetrics, UInt64> {
        switch self {
        case .logical: return \ScanMetrics.logicalBytes
        case .allocated: return \ScanMetrics.allocatedBytes
        }
    }
}
