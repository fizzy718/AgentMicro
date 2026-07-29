import Foundation

enum CodexToolActionFormatter {
    private static let secretPrefixes = [
        "sk-ant-",
        "sk-proj-",
        "sk-or-",
        "sk_live_",
        "sk_test_",
        "rk_live_",
        "rk_test_",
        "ghp_",
        "gho_",
        "ghs_",
        "ghr_",
        "ghu_",
        "github_pat_",
        "glpat-",
        "xoxb-",
        "xoxp-",
        "AKIA",
        "ASIA",
        "Bearer ",
    ]

    static func action(toolName: String, rawInput: Any?) -> String {
        let normalizedName = self.sanitize(toolName, maximumLength: 48)
        guard let argument = self.argument(toolName: toolName, rawInput: rawInput), !argument.isEmpty else {
            return normalizedName
        }
        return "\(normalizedName) · \(argument)"
    }

    static func targetHandle(rawInput: Any?) -> String? {
        guard let object = self.inputObject(rawInput) else { return nil }
        for key in ["session_id", "cell_id"] {
            if let value = self.scalarString(object[key]) {
                return value
            }
        }
        return nil
    }

    private static func argument(toolName: String, rawInput: Any?) -> String? {
        if toolName == "apply_patch", let value = rawInput as? String {
            return self.patchFilename(value)
        }
        guard let object = self.inputObject(rawInput) else { return nil }

        for key in ["file_path", "path"] {
            if let value = self.scalarString(object[key]) {
                return self.sanitize(URL(fileURLWithPath: value).lastPathComponent, maximumLength: 80)
            }
        }
        for key in ["cmd", "command", "query", "target", "session_id", "cell_id"] {
            if let value = self.scalarString(object[key]) {
                return self.sanitize(value, maximumLength: 80)
            }
        }
        return nil
    }

    private static func inputObject(_ rawInput: Any?) -> [String: Any]? {
        if let object = rawInput as? [String: Any] {
            return object
        }
        guard let value = rawInput as? String,
              let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object
    }

    private static func scalarString(_ rawValue: Any?) -> String? {
        if let value = rawValue as? String {
            return value
        }
        if let value = rawValue as? NSNumber {
            return value.stringValue
        }
        if let values = rawValue as? [String] {
            if values.count >= 3, values[0] == "bash", values[1] == "-lc" {
                return values[2]
            }
            return values.joined(separator: " ")
        }
        return nil
    }

    private static func patchFilename(_ value: String) -> String? {
        let prefixes = ["*** Add File: ", "*** Update File: ", "*** Delete File: "]
        for line in value.split(whereSeparator: \.isNewline) {
            for prefix in prefixes where line.hasPrefix(prefix) {
                let path = String(line.dropFirst(prefix.count))
                return self.sanitize(URL(fileURLWithPath: path).lastPathComponent, maximumLength: 80)
            }
        }
        return nil
    }

    private static func sanitize(_ value: String, maximumLength: Int) -> String {
        let safeCharacters = value.filter { character in
            !character.isNewline &&
                !character.isASCIIControl &&
                !character.isBidirectionalControl
        }
        var result = safeCharacters.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        for prefix in self.secretPrefixes {
            while let range = result.range(of: prefix) {
                let end = result[range.upperBound...].firstIndex(where: \.isWhitespace) ?? result.endIndex
                result.replaceSubrange(range.lowerBound..<end, with: "[REDACTED]")
            }
        }
        result = self.redactNamedSecrets(result)
        if result.count > maximumLength {
            result = String(result.prefix(maximumLength - 1)) + "…"
        }
        return result
    }

    private static func redactNamedSecrets(_ value: String) -> String {
        let pattern = #"(?i)\b(api[_-]?key|token|password|secret)=([^\s]+)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..., in: value)
        return expression.stringByReplacingMatches(
            in: value,
            range: range,
            withTemplate: "$1=[REDACTED]")
    }
}

extension Character {
    fileprivate var isASCIIControl: Bool {
        self.unicodeScalars.allSatisfy { $0.value < 0x20 || $0.value == 0x7F }
    }

    fileprivate var isBidirectionalControl: Bool {
        self.unicodeScalars.contains { scalar in
            (0x202A...0x202E).contains(scalar.value) ||
                (0x2066...0x2069).contains(scalar.value) ||
                scalar.value == 0x200E ||
                scalar.value == 0x200F
        }
    }
}
