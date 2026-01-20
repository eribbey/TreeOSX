import Foundation
import Core

struct CLI {
    static func run() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.first == "scan" else {
            print("Usage: swifttree scan <path> [--json output.json] [--metric logical|allocated]")
            return
        }
        guard arguments.count >= 2 else {
            print("Missing path")
            return
        }
        let path = arguments[1]
        var jsonPath: String?
        var metric: SizeMetric = .allocated

        var index = 2
        while index < arguments.count {
            let arg = arguments[index]
            if arg == "--json", index + 1 < arguments.count {
                jsonPath = arguments[index + 1]
                index += 2
            } else if arg == "--metric", index + 1 < arguments.count {
                let value = arguments[index + 1]
                metric = value == "logical" ? .logical : .allocated
                index += 2
            } else {
                index += 1
            }
        }

        let scanner = Scanner()
        let start = Date()
        do {
            let result = try await scanner.scan(rootPath: path, options: ScanOptions()) { event in
                if case .progress(let progress) = event {
                    let rate = Double(progress.scannedItems) / max(progress.elapsed, 0.001)
                    fputs("\rItems: \(progress.scannedItems) Dirs: \(progress.scannedDirectories) Errors: \(progress.errors) Rate: \(String(format: "%.0f", rate))/s", stdout)
                    fflush(stdout)
                }
            }
            let elapsed = Date().timeIntervalSince(start)
            fputs("\nCompleted in \(String(format: "%.2f", elapsed))s\n", stdout)

            if let jsonPath {
                let snapshot = ScanSnapshot(root: result.root, createdAt: Date(), path: path)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(snapshot)
                try data.write(to: URL(fileURLWithPath: jsonPath))
                print("Wrote \(jsonPath)")
            } else {
                let formatter = SizeFormatter()
                let bytes = metric == .logical ? result.root.metrics.logicalBytes : result.root.metrics.allocatedBytes
                print("Total: \(formatter.string(from: bytes, base: .base2))")
            }
        } catch {
            print("Scan failed: \(error)")
        }
    }
}

@main
enum SwiftTreeCLI {
    static func main() async {
        await CLI.run()
    }
}
