import SwiftUI

@main
struct BenchmarkApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                RunBenchmarkView()
                    .tabItem {
                        Label("Manual", systemImage: "gauge.with.dots.needle.50percent")
                    }
                NightRunHarnessView()
                    .tabItem {
                        Label("Night Run", systemImage: "moon.stars")
                    }
            }
        }
    }
}
