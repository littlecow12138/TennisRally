import Foundation
import SwiftUI

enum ThemePreference: String, CaseIterable, Identifiable, Equatable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .light: return "settings.theme.light"
        case .dark: return "settings.theme.dark"
        case .system: return "settings.theme.system"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable, Equatable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    var displayNameKey: LocalizedStringKey {
        switch self {
        case .english: return "settings.language.english"
        case .simplifiedChinese: return "settings.language.zh_hans"
        }
    }
}

@MainActor
final class AppSettingsStore: ObservableObject {
    private enum Keys {
        static let theme = "settings.theme"
        static let language = "settings.language"
    }

    private let defaults: UserDefaults

    @Published var theme: ThemePreference {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }

    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Keys.theme),
           let stored = ThemePreference(rawValue: raw) {
            theme = stored
        } else {
            theme = .dark
        }
        if let raw = defaults.string(forKey: Keys.language),
           let stored = AppLanguage(rawValue: raw) {
            language = stored
        } else {
            language = .english
        }
    }
}
