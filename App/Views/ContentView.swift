import SwiftUI
import Core

struct ContentView: View {
    @StateObject private var viewModel = ScanViewModel()
    @State private var showOpenPanel = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                TreemapView(
                    nodes: viewModel.filteredChildren,
                    metric: viewModel.selectedMetric,
                    sizeBase: viewModel.sizeBase
                ) { node in
                    viewModel.zoom(to: node)
                }
                .frame(minWidth: 400)
                Divider()
                NodeTableView(
                    nodes: viewModel.filteredChildren,
                    metric: viewModel.selectedMetric,
                    sizeBase: viewModel.sizeBase,
                    parentMetrics: viewModel.currentNode?.metrics ?? .zero
                )
            }
            Divider()
            StatusBar(progress: viewModel.progress, status: viewModel.statusMessage, errors: viewModel.errors.count)
        }
        .frame(minWidth: 1100, minHeight: 700)
        .toolbar {
            ToolbarItemGroup {
                Button("Scan") { showOpenPanel = true }
                Button("Cancel") { viewModel.cancelScan() }
                    .disabled(!viewModel.isScanning)
                Button("Up") { viewModel.zoomOut() }
                    .disabled(viewModel.currentNode?.id == viewModel.rootNode?.id)
            }
        }
        .fileImporter(isPresented: $showOpenPanel, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.startScan(path: url.path)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                BreadcrumbView(root: viewModel.rootNode, current: viewModel.currentNode) { node in
                    viewModel.zoom(to: node)
                }
                Spacer()
                Picker("Metric", selection: $viewModel.selectedMetric) {
                    ForEach(SizeMetric.allCases) { metric in
                        Text(metric.rawValue.capitalized).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Base", selection: $viewModel.sizeBase) {
                    Text("Base-2").tag(SizeBase.base2)
                    Text("Base-10").tag(SizeBase.base10)
                }
                .pickerStyle(.segmented)
            }
            HStack {
                TextField("Search", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                Spacer()
            }
        }
        .padding()
    }
}
