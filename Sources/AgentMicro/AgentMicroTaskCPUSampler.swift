import CodexBarCore
import Foundation

struct AgentMicroProcessCPURecord: Equatable, Sendable {
    let pid: Int32
    let parentPID: Int32
    let cpuPercent: Double
}

enum AgentMicroProcessCPUParser {
    static func parse(_ output: String) -> [AgentMicroProcessCPURecord] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count == 3,
                  let pid = Int32(fields[0]),
                  let parentPID = Int32(fields[1]),
                  let cpuPercent = Double(fields[2])
            else { return nil }
            return AgentMicroProcessCPURecord(
                pid: pid,
                parentPID: parentPID,
                cpuPercent: max(0, cpuPercent))
        }
    }

    static func totals(
        records: [AgentMicroProcessCPURecord],
        rootPIDs: Set<Int32>) -> [Int32: Double]
    {
        let children = Dictionary(grouping: records, by: \.parentPID)
        let cpuByPID = Dictionary(uniqueKeysWithValues: records.map { ($0.pid, $0.cpuPercent) })
        return Dictionary(uniqueKeysWithValues: rootPIDs.map { rootPID in
            var pending = [rootPID]
            var visited: Set<Int32> = []
            var total = 0.0
            while let pid = pending.popLast(), visited.insert(pid).inserted {
                total += cpuByPID[pid] ?? 0
                pending.append(contentsOf: children[pid, default: []].map(\.pid))
            }
            return (rootPID, total)
        })
    }
}

actor AgentMicroTaskCPUSampler {
    static let refreshInterval: Duration = .seconds(2)
    private static let smoothingWeight: Double = 0.35
    private var smoothedBySessionKey: [String: Double] = [:]

    func sample(tasks: [CodexTaskObservation]) async -> [String: Double] {
        var rootsBySessionKey: [String: Int32] = [:]
        for task in tasks where task.session.source == .cli {
            if let pid = task.session.pid {
                rootsBySessionKey[task.sessionKey] = pid
            }
        }
        guard !rootsBySessionKey.isEmpty,
              let result = try? await SubprocessRunner.run(
                  binary: "/bin/ps",
                  arguments: ["-axo", "pid=,ppid=,%cpu="],
                  environment: ["LC_ALL": "C"],
                  timeout: 2,
                  acceptsNonZeroExit: false,
                  label: "AgentMicro task CPU sample")
        else {
            self.smoothedBySessionKey = [:]
            return [:]
        }
        let totals = AgentMicroProcessCPUParser.totals(
            records: AgentMicroProcessCPUParser.parse(result.stdout),
            rootPIDs: Set(rootsBySessionKey.values))
        var smoothed: [String: Double] = [:]
        for (sessionKey, pid) in rootsBySessionKey {
            guard let current = totals[pid] else { continue }
            let previous = self.smoothedBySessionKey[sessionKey] ?? current
            smoothed[sessionKey] = previous + (current - previous) * Self.smoothingWeight
        }
        self.smoothedBySessionKey = smoothed
        return smoothed
    }

    func reset() {
        self.smoothedBySessionKey = [:]
    }
}
