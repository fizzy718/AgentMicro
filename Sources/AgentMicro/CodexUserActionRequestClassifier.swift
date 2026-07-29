import Foundation

enum CodexUserActionRequestClassifier {
    private static let sentenceSeparators: Set<Character> = [".", "!", "?", "。", "！", "？", ";", "\n"]

    private static let chineseRequestMarkers = [
        "请",
        "麻烦",
        "需要你",
        "需要您",
        "等你",
        "等待你",
        "等待您",
        "轮到你",
        "轮到您",
    ]

    private static let chineseActionMarkers = [
        "输入",
        "填写",
        "登录",
        "登陆",
        "确认",
        "批准",
        "授权",
        "验证",
        "完成",
        "点击",
        "选择",
        "操作",
        "接管",
        "提交",
    ]

    private static let englishRequestMarkers = [
        "please",
        "need you to",
        "waiting for you to",
        "wait for you to",
        "your action is required",
        "requires your action",
    ]

    private static let englishActionMarkers = [
        "enter",
        "fill",
        "log in",
        "login",
        "sign in",
        "confirm",
        "approve",
        "authorize",
        "verify",
        "complete",
        "click",
        "select",
        "take over",
        "submit",
    ]

    private static let negativeMarkers = [
        "不要",
        "不用",
        "无需",
        "不需要",
        "请勿",
        "do not",
        "don't",
        "no need to",
        "please avoid",
    ]

    static func requiresInput(_ text: String) -> Bool {
        self.sentences(in: text).contains { sentence in
            let value = sentence.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !value.isEmpty,
                  !self.negativeMarkers.contains(where: value.contains)
            else { return false }

            if self.isDirectQuestion(value) {
                return true
            }

            let chineseRequest = self.chineseRequestMarkers.contains(where: value.contains)
            let chineseAction = self.chineseActionMarkers.contains(where: value.contains)
            if chineseRequest, chineseAction {
                return true
            }

            let englishRequest = self.englishRequestMarkers.contains(where: value.contains)
            let englishAction = self.englishActionMarkers.contains(where: value.contains)
            return englishRequest && englishAction
        }
    }

    private static func isDirectQuestion(_ value: String) -> Bool {
        guard value.contains("?") || value.contains("？") else { return false }

        let chineseQuestionMarkers = [
            "你",
            "您",
            "吗",
            "能否",
            "可否",
            "要不要",
            "需不需要",
            "哪一个",
            "哪个",
            "哪种",
            "是否允许",
            "是否同意",
        ]
        if chineseQuestionMarkers.contains(where: value.contains) {
            return true
        }

        let englishQuestionMarkers = [
            "you",
            "your",
            "would you",
            "could you",
            "can you",
            "do you",
            "which option",
        ]
        return englishQuestionMarkers.contains(where: value.contains)
    }

    private static func sentences(in text: String) -> [String] {
        var result: [String] = []
        var sentence = ""
        for character in text {
            sentence.append(character)
            if self.sentenceSeparators.contains(character) {
                result.append(sentence)
                sentence.removeAll(keepingCapacity: true)
            }
        }
        if !sentence.isEmpty {
            result.append(sentence)
        }
        return result
    }
}
