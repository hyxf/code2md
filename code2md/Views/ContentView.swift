import SwiftUI

struct ContentView: View {
    @Environment(MergeMasterEngine.self) private var engine

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 500)
        } detail: {
            DetailView()
        }
        .navigationTitle("")
    }
}
