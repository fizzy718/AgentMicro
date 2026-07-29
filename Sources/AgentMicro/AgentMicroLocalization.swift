import Foundation

enum AgentMicroLocalization {
    static let appLanguageDefaultsKey = "agentMicro.appLanguage"
    private static let resourceBundleName = "CodexBar_AgentMicro.bundle"
    private static let resourceBundle: Bundle = {
        var candidates: [URL] = [
            Bundle.main.bundleURL.appendingPathComponent(Self.resourceBundleName),
        ]
        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent(Self.resourceBundleName))
        }
        if var directory = Bundle.main.executableURL?.deletingLastPathComponent() {
            for _ in 0..<4 {
                candidates.append(directory.appendingPathComponent(Self.resourceBundleName))
                directory.deleteLastPathComponent()
            }
        }
        let workingDirectory = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true)
        for architecture in ["arm64-apple-macosx", "x86_64-apple-macosx"] {
            for configuration in ["debug", "release"] {
                candidates.append(
                    workingDirectory
                        .appendingPathComponent(".build")
                        .appendingPathComponent(architecture)
                        .appendingPathComponent(configuration)
                        .appendingPathComponent(Self.resourceBundleName))
            }
        }
        for candidate in candidates {
            if let bundle = Bundle(url: candidate) {
                return bundle
            }
        }
        return Bundle.main
    }()

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
            from: self.resourceBundle.localizations.filter { $0 != "Base" },
            forPreferences: Locale.preferredLanguages).first ?? "en"
    }

    static func localizedResourceURL(for localeIdentifier: String) -> URL? {
        for candidate in [localeIdentifier, localeIdentifier.lowercased()] {
            if let url = self.resourceBundle.url(forResource: candidate, withExtension: "lproj") {
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
                from: self.resourceBundle.localizations.filter { $0 != "Base" },
                forPreferences: Locale.preferredLanguages).first ?? "en"
        } else {
            localeIdentifier
        }
        if let url = self.localizedResourceURL(for: resolvedIdentifier),
           let localizedBundle = Bundle(url: url)
        {
            return localizedBundle
        }
        guard let englishPath = self.resourceBundle.path(forResource: "en", ofType: "lproj"),
              let englishBundle = Bundle(path: englishPath)
        else {
            return self.resourceBundle
        }
        return englishBundle
    }
}

extension String {
    fileprivate var nonEmpty: String? {
        self.isEmpty ? nil : self
    }
}
