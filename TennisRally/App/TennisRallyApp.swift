import SwiftUI

@main
struct TennisRallyApp: App {
    @StateObject private var store = AppSessionStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
