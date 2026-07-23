import SwiftUI

struct PowerRootView: View {
    @Bindable var model: PowerAppModel

    var body: some View {
        TabView(selection: $model.selectedTab) {
            NavigationStack {
                PowerTestView(model: model)
            }
            .tabItem {
                Label("Test", systemImage: "play.circle.fill")
            }
            .tag(PowerAppModel.SelectedTab.test)

            NavigationStack {
                PowerResultsView(model: model)
            }
            .tabItem {
                Label("Results", systemImage: "tray.full.fill")
            }
            .tag(PowerAppModel.SelectedTab.results)
        }
    }
}
