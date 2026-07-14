import SwiftUI

@main
struct BenchmarkApp: App {
    @State private var settings = PowerAppSettings()

    var body: some Scene {
        WindowGroup {
            TabView {
                RunBenchmarkView(settings: settings)
                    .tabItem {
                        Label("Manual", systemImage: "gauge.with.dots.needle.50percent")
                    }
                NightRunHarnessView(settings: settings)
                    .tabItem {
                        Label("Guided", systemImage: "list.bullet.clipboard")
                    }
            }
        }
    }
}
