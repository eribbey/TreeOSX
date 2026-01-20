#if canImport(SwiftUI)
import SwiftUI

@main
struct SwiftTreeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
#else
@main
struct SwiftTreeApp {
    static func main() {
        print("SwiftTreeApp requires SwiftUI and is only supported on Apple platforms.")
    }
}
#endif
