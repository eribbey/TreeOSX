import SwiftUI
import Core

struct BreadcrumbView: View {
    let root: ScanNode?
    let current: ScanNode?
    var onSelect: (ScanNode) -> Void

    var body: some View {
        HStack(spacing: 4) {
            if let root {
                Button(root.name) { onSelect(root) }
            } else {
                Text("No Scan")
            }
            if let current, let root, current.id != root.id {
                Text("/")
                Text(current.name)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
