import SwiftUI

@main
struct TennisRallyApp: App {
    @StateObject private var store = AppSessionStore()
    @StateObject private var settings = AppSettingsStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(settings)
                .preferredColorScheme(settings.theme.preferredColorScheme)
                .environment(\.locale, settings.language.locale)
        }
    }
}
