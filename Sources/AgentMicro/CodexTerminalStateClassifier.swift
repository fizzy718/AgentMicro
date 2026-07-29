import Foundation

enum CodexTerminalFailureClassifier {
    private static let recoveryMarkers = [
        "已修复",
        "已经修复",
        "已解决",
        "成功完成",
        "全部通过",
        "测试通过",
        "fixed",
        "resolved",
        "completed successfully",
        "successfully completed",
        "all tests pass",
        "all tests passed",
    ]

    private static let failureMarkers = [
        "无法完成",
        "未能完成",
        "任务失败",
        "执行失败",
        "无法继续",
        "不能继续",
        "could not complete",
        "couldn't complete",
        "unable to complete",
        "failed to complete",
        "task failed",
        "cannot continue",
        "can't continue",
        "blocked from completing",
    ]

    static func isBlockingFailure(_ text: String) -> Bool {
        let value = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !value.isEmpty,
              !self.recoveryMarkers.contains(where: value.contains)
        else { return false }
        return self.failureMarkers.contains(where: value.contains)
    }

    static func isFailureAbortReason(_ reason: String?) -> Bool {
        guard let value = reason?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !value.isEmpty
        else { return false }
        if ["interrupted", "cancelled", "canceled", "user_cancelled", "replaced"].contains(value) {
            return false
        }
        return value.contains("error") ||
            value.contains("fail") ||
            value.contains("crash") ||
            value.contains("fatal")
    }
}

enum CodexToolOutputFailureClassifier {
    static func isTerminalFailure(_ text: String) -> Bool {
        let value = text.lowercased()
        if let exitCode = self.exitCode(in: value) {
            return exitCode != 0
        }
        return value.contains("script failed") ||
            value.contains("tool call failed") ||
            value.contains("process terminated by signal") ||
            value.contains("\"status\":\"failed\"") ||
            value.contains("\"status\": \"failed\"")
    }

    static func isTerminalSuccess(_ text: String) -> Bool {
        let value = text.lowercased()
        if let exitCode = self.exitCode(in: value) {
            return exitCode == 0
        }
        return value.contains("script completed") ||
            value.contains("\"status\":\"completed\"") ||
            value.contains("\"status\": \"completed\"")
    }

    private static func exitCode(in value: String) -> Int? {
        let markers = [
            "process exited with code ",
            "process exited with status ",
            "exit code: ",
        ]
        for marker in markers {
            guard let range = value.range(of: marker) else { continue }
            let suffix = value[range.upperBound...]
            let digits = suffix.prefix { $0 == "-" || $0.isNumber }
            if let code = Int(digits) {
                return code
            }
        }
        return nil
    }
}
