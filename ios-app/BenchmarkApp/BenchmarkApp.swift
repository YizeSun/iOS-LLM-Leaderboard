import SwiftUI

@main
struct BenchmarkApp: App {
    @State private var settings = PowerAppSettings()

    var body: some Scene {
        WindowGroup {
            RunBenchmarkView(settings: settings)
        }
    }
}
