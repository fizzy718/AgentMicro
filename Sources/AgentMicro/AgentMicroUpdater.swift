import Foundation
import Security

#if canImport(Sparkle) && ENABLE_AGENTMICRO_SPARKLE
import Sparkle
#endif

@MainActor
protocol AgentMicroUpdaterProviding: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    var automaticallyDownloadsUpdates: Bool { get set }
    var isAvailable: Bool { get }
    var unavailableReason: AgentMicroUpdaterUnavailableReason? { get }
    func checkForUpdates(_ sender: Any?)
}

enum AgentMicroUpdaterUnavailableReason: Sendable {
    case build
    case feed
    case signature

    func localizedDescription(localeIdentifier: String? = nil) -> String {
        AgentMicroLocalization.text(self.localizationKey, localeIdentifier: localeIdentifier)
    }

    private var localizationKey: String {
        switch self {
        case .build:
            "updates.unavailable.build"
        case .feed:
            "updates.unavailable.feed"
        case .signature:
            "updates.unavailable.signature"
        }
    }
}

@MainActor
final class AgentMicroDisabledUpdaterController: AgentMicroUpdaterProviding {
    var automaticallyChecksForUpdates = false
    var automaticallyDownloadsUpdates = false
    let isAvailable = false
    let unavailableReason: AgentMicroUpdaterUnavailableReason?

    init(unavailableReason: AgentMicroUpdaterUnavailableReason?) {
        self.unavailableReason = unavailableReason
    }

    func checkForUpdates(_: Any?) {}
}

#if canImport(Sparkle) && ENABLE_AGENTMICRO_SPARKLE
@MainActor
final class AgentMicroSparkleUpdaterController: AgentMicroUpdaterProviding {
    private let controller: SPUStandardUpdaterController
    let isAvailable = true
    let unavailableReason: AgentMicroUpdaterUnavailableReason? = nil

    init(automaticallyChecksForUpdates: Bool) {
        self.controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil)
        self.controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        self.controller.updater.automaticallyDownloadsUpdates = automaticallyChecksForUpdates
        self.controller.startUpdater()
    }

    var automaticallyChecksForUpdates: Bool {
        get { self.controller.updater.automaticallyChecksForUpdates }
        set { self.controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { self.controller.updater.automaticallyDownloadsUpdates }
        set { self.controller.updater.automaticallyDownloadsUpdates = newValue }
    }

    func checkForUpdates(_ sender: Any?) {
        self.controller.checkForUpdates(sender)
    }
}
#endif

@MainActor
enum AgentMicroUpdaterFactory {
    static func make(automaticallyChecksForUpdates: Bool) -> AgentMicroUpdaterProviding {
        #if canImport(Sparkle) && ENABLE_AGENTMICRO_SPARKLE
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return AgentMicroDisabledUpdaterController(
                unavailableReason: .build)
        }
        guard Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") is String,
              Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") is String
        else {
            return AgentMicroDisabledUpdaterController(
                unavailableReason: .feed)
        }
        guard self.isDeveloperIDSigned(bundleURL: Bundle.main.bundleURL) else {
            return AgentMicroDisabledUpdaterController(
                unavailableReason: .signature)
        }
        return AgentMicroSparkleUpdaterController(
            automaticallyChecksForUpdates: automaticallyChecksForUpdates)
        #else
        return AgentMicroDisabledUpdaterController(
            unavailableReason: .build)
        #endif
    }

    private static func isDeveloperIDSigned(bundleURL: URL) -> Bool {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
              let staticCode
        else {
            return false
        }

        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information) == errSecSuccess,
            let information = information as? [String: Any],
            let certificates = information[kSecCodeInfoCertificates as String] as? [SecCertificate],
            let certificate = certificates.first,
            let summary = SecCertificateCopySubjectSummary(certificate) as String?
        else {
            return false
        }
        return summary.hasPrefix("Developer ID Application:")
    }
}
