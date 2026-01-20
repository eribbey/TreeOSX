#if canImport(SwiftUI)
import SwiftUI

@main
struct DiskVizApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
#else
@main
struct DiskVizApp {
    static func main() {
        print("DiskVizApp requires SwiftUI and is only supported on Apple platforms.")
    }
}
#endif
