import Foundation

enum ComputerUseApprovalClassifier {
    static func target(namespace: String?, rawInput: Any?) -> String? {
        let namespace = namespace?.lowercased() ?? ""
        guard namespace.contains("node_repl") || namespace.contains("computer") else { return nil }

        let input = self.toolInputText(rawInput)
        guard input.localizedCaseInsensitiveContains("sky.") else { return nil }

        let pattern = #"app\s*:\s*["']([^"']+)["']"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: input,
                  range: NSRange(input.startIndex..., in: input)),
              let targetRange = Range(match.range(at: 1), in: input)
        else { return nil }
        return input[targetRange].lowercased()
    }

    private static func toolInputText(_ rawInput: Any?) -> String {
        guard let rawInput else { return "" }
        if let value = rawInput as? String {
            if let data = value.data(using: .utf8),
               let decoded = try? JSONSerialization.jsonObject(with: data)
            {
                return self.toolInputText(decoded)
            }
            return value
        }
        if let values = rawInput as? [Any] {
            return values.map(self.toolInputText).joined(separator: "\n")
        }
        if let values = rawInput as? [String: Any] {
            return values.values.map(self.toolInputText).joined(separator: "\n")
        }
        return String(describing: rawInput)
    }
}

enum CodexToolCallClassifier {
    static func isExecution(_ name: String) -> Bool {
        name == "exec" || name == "exec_command"
    }

    static func isPolling(_ name: String) -> Bool {
        name == "wait" || name == "write_stdin"
    }

    static func requiresInput(_ name: String) -> Bool {
        name.localizedCaseInsensitiveContains("request_user_input")
    }
}
