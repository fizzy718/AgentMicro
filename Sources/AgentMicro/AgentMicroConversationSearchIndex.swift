import CodexBarCore
import Foundation

actor AgentMicroConversationSearchIndex {
    private struct CacheEntry {
        let fileSize: UInt64
        let modificationDate: Date?
        let conversationText: String
    }

    private static let maximumIndexedBytesPerTranscript = 8 * 1024 * 1024
    private var cache: [String: CacheEntry] = [:]

    func matchingSessionKeys(
        in tasks: [CodexTaskObservation],
        query: String) -> Set<String>
    {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.shouldSearchConversation(query) else { return [] }

        var matches: Set<String> = []
        for task in tasks {
            guard !Task.isCancelled,
                  let path = task.session.transcriptPath,
                  let conversationText = self.conversationText(at: path)
            else { continue }
            if conversationText.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive]) != nil
            {
                matches.insert(task.sessionKey)
            }
        }
        return matches
    }

    private func conversationText(at path: String) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = (attributes[.size] as? NSNumber)?.uint64Value
        else { return nil }
        let modificationDate = attributes[.modificationDate] as? Date
        if let cached = self.cache[path],
           cached.fileSize == fileSize,
           cached.modificationDate == modificationDate
        {
            return cached.conversationText
        }

        guard let data = Self.readTranscriptSuffix(at: path, fileSize: fileSize) else { return nil }
        let text = Self.extractConversationText(from: data)
        self.cache[path] = CacheEntry(
            fileSize: fileSize,
            modificationDate: modificationDate,
            conversationText: text)
        return text
    }

    private static func readTranscriptSuffix(at path: String, fileSize: UInt64) -> Data? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let bytesToRead = min(fileSize, UInt64(Self.maximumIndexedBytesPerTranscript))
        do {
            try handle.seek(toOffset: fileSize - bytesToRead)
            return try handle.read(upToCount: Int(bytesToRead))
        } catch {
            return nil
        }
    }

    private static func extractConversationText(from data: Data) -> String {
        guard let source = String(data: data, encoding: .utf8) else { return "" }
        var messages: [String] = []
        source.enumerateLines { line, _ in
            guard let lineData = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let outerType = object["type"] as? String,
                  let payload = object["payload"] as? [String: Any],
                  let payloadType = payload["type"] as? String
            else { return }

            if outerType == "event_msg",
               ["user_message", "agent_message"].contains(payloadType)
            {
                self.appendStrings(in: payload["message"], to: &messages)
                self.appendStrings(in: payload["text"], to: &messages)
            } else if outerType == "response_item",
                      payloadType == "message",
                      let role = payload["role"] as? String,
                      ["user", "assistant"].contains(role)
            {
                self.appendStrings(in: payload["content"], to: &messages)
            }
        }
        return messages.joined(separator: "\n")
    }

    private static func shouldSearchConversation(_ query: String) -> Bool {
        let characters = query.filter { !$0.isWhitespace }
        let containsCJK = characters.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                true
            default:
                false
            }
        }
        return characters.count >= (containsCJK ? 2 : 3)
    }

    private static func appendStrings(in value: Any?, to strings: inout [String]) {
        switch value {
        case let string as String:
            strings.append(string)
        case let values as [Any]:
            for value in values {
                self.appendStrings(in: value, to: &strings)
            }
        case let object as [String: Any]:
            for key in ["text", "message", "content"] {
                self.appendStrings(in: object[key], to: &strings)
            }
        default:
            break
        }
    }
}
