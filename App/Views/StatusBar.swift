import SwiftUI
import Core

struct StatusBar: View {
    let progress: ScanProgress
    let status: String
    let errors: Int

    var body: some View {
        HStack {
            Text(status)
            Spacer()
            Text("Items: \(progress.scannedItems)")
            Text("Dirs: \(progress.scannedDirectories)")
            Text("Errors: \(errors)")
            Text("Elapsed: \(String(format: "%.1f", progress.elapsed))s")
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}
