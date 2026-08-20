import Foundation

enum AppLocalization {
    static func text(_ key: String, locale: Locale) -> String {
        NSLocalizedString(key, tableName: nil, bundle: bundle(for: locale), value: key, comment: "")
    }

    static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        let template = text(key, locale: locale)
        return String(format: template, locale: locale, arguments: arguments)
    }

    static func bundle(for locale: Locale) -> Bundle {
        let name = localizationFolderName(for: locale)
        if let path = Bundle.main.path(forResource: name, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }

    static func localizationFolderName(for locale: Locale) -> String {
        if let language = locale.language.languageCode?.identifier {
            if language == "zh" {
                if locale.language.script?.identifier == "Hant" {
                    return "zh-Hant"
                }
                return "zh-Hans"
            }
            return language
        }

        let identifier = locale.identifier
        if identifier.hasPrefix("zh") {
            return identifier.contains("Hant") ? "zh-Hant" : "zh-Hans"
        }
        if identifier.hasPrefix("en") {
            return "en"
        }
        return identifier
    }
}
