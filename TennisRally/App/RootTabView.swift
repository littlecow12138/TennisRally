import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: AppSessionStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            LibraryImportView()
                .tabItem {
                    Label(String(localized: "tab.library"), systemImage: "film.stack")
                }
                .tag(AppTab.library)

            OfflineProcessingView()
                .tabItem {
                    Label(String(localized: "tab.process"), systemImage: "arrow.down.left.and.arrow.up.right.circle")
                }
                .tag(AppTab.process)

            RallyTimelineView()
                .tabItem {
                    Label(String(localized: "tab.rallies"), systemImage: "sportscourt")
                }
                .tag(AppTab.rallies)
        }
        .tint(HardCourt.accent)
        .toolbarBackground(HardCourt.bg, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .fullScreenCover(isPresented: $store.showCorrection) {
            if let rally = store.editingRally {
                CorrectionEditorView(rally: rally)
            }
        }
        .fullScreenCover(isPresented: $store.showReview) {
            if let rally = store.reviewingRally {
                ReviewExportView(rally: rally)
            }
        }
    }
}
