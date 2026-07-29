import Foundation

enum AgentMicroLocalization {
    static let appLanguageDefaultsKey = "agentMicro.appLanguage"
    static let supportedLanguageIdentifiers = AgentMicroAppLanguage.allCases
        .filter { $0 != .system }
        .map(\.rawValue)

    static var isRightToLeft: Bool {
        self.isRightToLeft(languageIdentifier: self.effectiveLanguageIdentifier)
    }

    static func isRightToLeft(languageIdentifier: String) -> Bool {
        let language = languageIdentifier.lowercased()
        return language == "ar" || language.hasPrefix("ar-") ||
            language == "fa" || language.hasPrefix("fa-")
    }

    static func text(
        _ key: String,
        localeIdentifier: String? = nil,
        arguments: CVarArg...) -> String
    {
        let bundle = self.bundle(for: localeIdentifier ?? self.resolvedAppLanguage())
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        guard !arguments.isEmpty else { return format }
        let locale = (localeIdentifier ?? self.resolvedAppLanguage())
            .nonEmpty
            .map(Locale.init(identifier:)) ?? .current
        return String(format: format, locale: locale, arguments: arguments)
    }

    static var effectiveLanguageIdentifier: String {
        let selected = self.resolvedAppLanguage()
        guard selected.isEmpty else { return selected }
        return Bundle.preferredLocalizations(
            from: Bundle.module.localizations.filter { $0 != "Base" },
            forPreferences: Locale.preferredLanguages).first ?? "en"
    }

    static func localizedResourceURL(for localeIdentifier: String) -> URL? {
        for candidate in [localeIdentifier, localeIdentifier.lowercased()] {
            if let url = Bundle.module.url(forResource: candidate, withExtension: "lproj") {
                return url
            }
        }
        return nil
    }

    private static func resolvedAppLanguage() -> String {
        UserDefaults.standard.string(forKey: self.appLanguageDefaultsKey) ?? ""
    }

    private static func bundle(for localeIdentifier: String) -> Bundle {
        let resolvedIdentifier = if localeIdentifier.isEmpty {
            Bundle.preferredLocalizations(
                from: Bundle.module.localizations.filter { $0 != "Base" },
                forPreferences: Locale.preferredLanguages).first ?? "en"
        } else {
            localeIdentifier
        }
        if let url = self.localizedResourceURL(for: resolvedIdentifier),
           let localizedBundle = Bundle(url: url)
        {
            return localizedBundle
        }
        guard let englishPath = Bundle.module.path(forResource: "en", ofType: "lproj"),
              let englishBundle = Bundle(path: englishPath)
        else {
            return Bundle.module
        }
        return englishBundle
    }
}

extension String {
    fileprivate var nonEmpty: String? {
        self.isEmpty ? nil : self
    }
}
