import SwiftUI

@main
struct TennisRallyApp: App {
    @StateObject private var store = AppSessionStore()
    @StateObject private var settings = AppSettingsStore()
    @StateObject private var visionModel: VisionModelStore
    @StateObject private var assistSession: AIAssistSession

    init() {
        let vision = VisionModelStore()
        _visionModel = StateObject(wrappedValue: vision)
        _assistSession = StateObject(wrappedValue: AIAssistSession(modelStore: vision))
    }

    init() {
        BackgroundSplitSupport.register()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(visionModel)
                .environmentObject(assistSession)
                .preferredColorScheme(settings.theme.preferredColorScheme)
                .environment(\.locale, settings.language.locale)
        }
    }
}
