//
//  RehearsalStats.swift
//  Cueflow (随读)
//
//  F6-D: Local-only rehearsal statistics. A finished prompting session is
//  recorded as a RehearsalSession; sessions persist as JSON in Application
//  Support. Nothing is ever uploaded. Independently authored; no third-party code.
//

import Foundation
import Combine

/// One finished prompting session.
struct RehearsalSession: Codable, Identifiable {
    var id: UUID = UUID()
    var scriptID: UUID?
    var scriptTitle: String
    var startedAt: Date
    var duration: TimeInterval      // seconds actually prompted
    var words: Int                  // reading units covered (CJK chars + latin words)
    var avgWordsPerMin: Double
    var completion: Double          // 0...1
    var reachedEnd: Bool
}

/// Persists the session list to Application Support as JSON.
@MainActor
final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    @Published private(set) var sessions: [RehearsalSession] = []

    private let maxSessions = 500
    private let fileURL: URL

    private init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true))
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("Cueflow", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("rehearsal_stats.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([RehearsalSession].self, from: data) {
            sessions = decoded
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func add(_ session: RehearsalSession) {
        sessions.insert(session, at: 0)
        if sessions.count > maxSessions { sessions.removeLast(sessions.count - maxSessions) }
        persist()
    }

    func clearAll() {
        sessions.removeAll()
        persist()
    }

    // MARK: Aggregates

    var latest: RehearsalSession? { sessions.first }
    var totalSessions: Int { sessions.count }
    var totalDuration: TimeInterval { sessions.reduce(0) { $0 + $1.duration } }
}

/// Watches the prompting session and records a RehearsalSession when it ends.
/// A "session" spans from the first time the timer runs (after a reset) until the
/// user resets, reaches the end, or quits the app.
@MainActor
final class StatsManager {
    static let shared = StatsManager()

    /// Posted (with the recorded session as object) right after a session is saved.
    static let didRecordSession = Notification.Name("CueflowDidRecordSession")

    private let model = PrompterModel.shared
    private var sessionActive = false
    private var startedAt: Date?
    private var scriptID: UUID?
    private var scriptTitle: String = ""
    private var snapshotWords: Int = 0

    private init() {}

    /// Called whenever the timer is actively counting. Snapshots session context
    /// on the first activity after a reset.
    func markActivity() {
        guard !sessionActive else { return }
        sessionActive = true
        startedAt = Date()
        scriptID = model.activeScriptID
        scriptTitle = currentScriptTitle()
        snapshotWords = model.scriptUnitCount
    }

    private func currentScriptTitle() -> String {
        if let id = model.activeScriptID,
           let t = ScriptLibrary.shared.title(for: id),
           !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return t
        }
        return L(.libUntitled)
    }

    /// Finalize and persist the current session if it is meaningful (>= 3s).
    func finalize(reachedEnd: Bool) {
        defer { sessionActive = false; startedAt = nil }
        guard sessionActive, model.statsEnabled else { return }
        let duration = TimeInterval(TimerEngine.shared.currentSeconds)
        guard duration >= 3 else { return }

        let estimated = model.estimatedReadDuration
        let completion: Double = reachedEnd
            ? 1.0
            : (estimated > 0 ? min(1.0, duration / estimated) : 0)
        let wordsRead = Int((Double(snapshotWords) * completion).rounded())
        let minutes = duration / 60.0
        let wpm = minutes > 0 ? Double(wordsRead) / minutes : 0

        let session = RehearsalSession(
            scriptID: scriptID,
            scriptTitle: scriptTitle.isEmpty ? L(.libUntitled) : scriptTitle,
            startedAt: startedAt ?? Date(),
            duration: duration,
            words: wordsRead,
            avgWordsPerMin: wpm,
            completion: completion,
            reachedEnd: reachedEnd
        )
        StatsStore.shared.add(session)
        NotificationCenter.default.post(name: Self.didRecordSession, object: session)
    }
}
