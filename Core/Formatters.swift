import Foundation

public enum SizeBase: String, CaseIterable {
    case base2
    case base10
}

public struct SizeFormatter {
    public init() {}

    public func string(from bytes: UInt64, base: SizeBase) -> String {
        let unit: Double = base == .base2 ? 1024.0 : 1000.0
        let units = base == .base2 ? ["B", "KiB", "MiB", "GiB", "TiB", "PiB"] : ["B", "KB", "MB", "GB", "TB", "PB"]
        var value = Double(bytes)
        var index = 0
        while value >= unit && index < units.count - 1 {
            value /= unit
            index += 1
        }
        if index == 0 {
            return "\(Int(value)) \(units[index])"
        }
        return String(format: "%.1f %@", value, units[index])
    }
}
