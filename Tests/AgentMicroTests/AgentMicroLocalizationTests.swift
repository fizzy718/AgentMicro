import Foundation
import Testing
@testable import AgentMicro

struct AgentMicroLocalizationTests {
    @Test
    func `English resources cover menu and settings copy`() {
        #expect(AgentMicroLocalization.text("menu.footer.refresh", localeIdentifier: "en") == "Refresh")
        #expect(
            AgentMicroLocalization.text("settings.taskDisplay", localeIdentifier: "en") ==
                "Task display")
        #expect(
            AgentMicroLocalization.text("guide.title", localeIdentifier: "en") ==
                "Usage Guide")
    }

    @Test
    func `Simplified Chinese resources cover menu and settings copy`() {
        #expect(AgentMicroLocalization.text("menu.footer.refresh", localeIdentifier: "zh-Hans") == "刷新")
        #expect(
            AgentMicroLocalization.text("settings.taskDisplay", localeIdentifier: "zh-Hans") ==
                "任务显示")
        #expect(
            AgentMicroLocalization.text("guide.title", localeIdentifier: "zh-Hans") ==
                "使用指南")
    }

    @Test
    func `Localized format strings preserve task counts`() {
        #expect(
            AgentMicroLocalization.text(
                "menu.headline.active",
                localeIdentifier: "zh-Hans",
                arguments: 3) ==
                "AgentMicro — 3 个运行中")
        #expect(
            AgentMicroLocalization.text(
                "status.tooltip.active",
                localeIdentifier: "en",
                arguments: 2,
                6) ==
                "AgentMicro — 2 active of 6 recent Codex tasks")
    }

    @Test
    func `all CodexBar interface languages have complete AgentMicro catalogs`() throws {
        #expect(AgentMicroAppLanguage.allCases.count == 24)
        #expect(AgentMicroLocalization.supportedLanguageIdentifiers.count == 23)
        let englishKeys = try Self.catalogKeys(localeIdentifier: "en")

        for localeIdentifier in AgentMicroLocalization.supportedLanguageIdentifiers {
            #expect(try Self.catalogKeys(localeIdentifier: localeIdentifier) == englishKeys)
            #expect(
                AgentMicroLocalization.text(
                    "menu.footer.refresh",
                    localeIdentifier: localeIdentifier) !=
                    "menu.footer.refresh")
            #expect(
                AgentMicroLocalization.text(
                    "status.tooltip.active",
                    localeIdentifier: localeIdentifier,
                    arguments: 1,
                    6) !=
                    "status.tooltip.active")
        }
    }

    @Test
    func `Arabic and Persian use right to left layout`() {
        #expect(AgentMicroLocalization.isRightToLeft(languageIdentifier: "ar"))
        #expect(AgentMicroLocalization.isRightToLeft(languageIdentifier: "fa-IR"))
        #expect(!AgentMicroLocalization.isRightToLeft(languageIdentifier: "en"))
    }

    @Test
    func `updater unavailable reason localizes when the interface language changes`() {
        #expect(
            AgentMicroUpdaterUnavailableReason.feed.localizedDescription(localeIdentifier: "en") ==
                "The update feed has not been configured yet.")
        #expect(
            AgentMicroUpdaterUnavailableReason.feed.localizedDescription(localeIdentifier: "zh-Hans") ==
                "尚未配置软件更新源。")
    }

    private static func catalogKeys(localeIdentifier: String) throws -> Set<String> {
        let resourceDirectory = try #require(
            AgentMicroLocalization.localizedResourceURL(for: localeIdentifier))
        let data = try Data(contentsOf: resourceDirectory.appendingPathComponent("Localizable.strings"))
        let catalog = try #require(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
        return Set(catalog.keys)
    }
}
