//
//  CueScript.swift
//  Cueflow (随读)
//
//  Pure parser that turns a plain-text script into a structured `CueScript`
//  for the "随讲" (cue card) mode — while preserving EXACT backward behavior
//  for every script that does not opt into the structure markup.
//
//  Markup convention (see 产品开发文档-F5):
//    "## 标题 [m:ss]"  -> outline point (section). All heading levels are flat.
//                         Trailing "[m:ss]" is an optional time budget.
//    "> 弹药"          -> must-say material
//    ">? 弹药"         -> optional material
//    other non-empty   -> spoken line (read aloud in auto / voice modes)
//
//  BACKWARD-COMPAT RULE (critical): a script that contains NO "## " heading is
//  treated as fully unstructured — `hasStructure` is false, `spokenOnly` equals
//  the raw input untouched, and `sections` is empty. So existing prompter
//  behavior (auto-scroll / voice-follow) is byte-identical unless the user
//  explicitly adds outline headings. Stray ">" lines alone never trigger
//  structure parsing.
//
//  This file has ZERO dependencies on the app target so it can be unit-tested
//  with swiftc standalone (same approach as ScriptTokenizer / AlignmentEngine):
//    swiftc notchprompt/CueScript.swift Tools/cuetest/main.swift -o .build-dd/cuetest && .build-dd/cuetest
//

import Foundation

/// One reference item shown under an outline point while improvising.
struct CueMaterial: Equatable {
    var text: String
    var isOptional: Bool   // true = "可选" (shown dimmed); false = "必讲"
}

/// One outline point ("提纲卡"). `id` is stable per instance for SwiftUI but is
/// intentionally excluded from equality so parsing the same text twice compares
/// equal in tests.
struct CueSection: Identifiable {
    let id: UUID
    var title: String
    var timeBudgetSeconds: Int?
    var spoken: String
    var materials: [CueMaterial]

    init(id: UUID = UUID(),
         title: String,
         timeBudgetSeconds: Int? = nil,
         spoken: String = "",
         materials: [CueMaterial] = []) {
        self.id = id
        self.title = title
        self.timeBudgetSeconds = timeBudgetSeconds
        self.spoken = spoken
        self.materials = materials
    }
}

extension CueSection: Equatable {
    static func == (lhs: CueSection, rhs: CueSection) -> Bool {
        lhs.title == rhs.title
            && lhs.timeBudgetSeconds == rhs.timeBudgetSeconds
            && lhs.spoken == rhs.spoken
            && lhs.materials == rhs.materials
    }
}

/// Structured view of a script for the three prompter modes.
struct CueScript: Equatable {
    /// Outline points; empty when the script is unstructured.
    var sections: [CueSection]
    /// True only when the script contains at least one "## " heading.
    var hasStructure: Bool
    /// Text fed to auto-scroll / voice-follow. For unstructured scripts this is
    /// the raw input untouched; for structured scripts the headings & materials
    /// are removed so only the spoken lines are read aloud.
    var spokenOnly: String

    /// Whether the script is usable in 随讲 mode (has at least one real point).
    var canUseCueMode: Bool { hasStructure && !sections.isEmpty }

    /// Whether there is any spoken (read-aloud) text. A pure outline script —
    /// only headings + materials — has none, so auto/voice modes would be blank.
    var hasSpoken: Bool { !spokenOnly.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

enum CueParser {

    static func parse(_ raw: String) -> CueScript {
        let lines = raw.components(separatedBy: "\n")

        // BACKWARD-COMPAT: no heading -> fully unstructured, raw passes through.
        let hasHeading = lines.contains { parseHeading($0) != nil }
        guard hasHeading else {
            return CueScript(sections: [], hasStructure: false, spokenOnly: raw)
        }

        var sections: [CueSection] = []

        // Accumulators for the in-progress section. `titleOrNil == nil` means we
        // are still in the implicit intro region before the first heading.
        var titleOrNil: String? = nil
        var budget: Int? = nil
        var spokenLines: [String] = []
        var materials: [CueMaterial] = []

        func flush() {
            let title = titleOrNil ?? ""
            let spoken = joinSpoken(spokenLines)
            // Drop a section that carries no information at all.
            guard !title.isEmpty || !spoken.isEmpty || !materials.isEmpty else { return }
            sections.append(CueSection(title: title,
                                       timeBudgetSeconds: budget,
                                       spoken: spoken,
                                       materials: materials))
        }

        for line in lines {
            if let heading = parseHeading(line) {
                flush()
                titleOrNil = heading.title
                budget = heading.budget
                spokenLines = []
                materials = []
            } else if let material = parseMaterial(line) {
                materials.append(material)
            } else {
                spokenLines.append(line)
            }
        }
        flush()

        // spokenOnly: keep everything that is neither a heading nor a material.
        let spokenOnly = lines
            .filter { parseHeading($0) == nil && parseMaterial($0) == nil }
            .joined(separator: "\n")

        return CueScript(sections: sections, hasStructure: true, spokenOnly: spokenOnly)
    }

    // MARK: - Line classifiers

    /// Returns the parsed heading (title without markup, optional time budget) or
    /// nil if the line is not a "# "/"## "/... heading.
    static func parseHeading(_ line: String) -> (title: String, budget: Int?)? {
        var s = dropLeadingBlanks(Substring(line))
        guard s.first == "#" else { return nil }
        var hashes = 0
        while s.first == "#" { s = s.dropFirst(); hashes += 1 }
        // A markdown heading requires a space after the '#'s; this avoids
        // matching "#hashtag" style text.
        guard hashes >= 1, s.first == " " else { return nil }
        let rest = String(s).trimmingCharacters(in: .whitespaces)
        let (title, budget) = splitTimeBudget(rest)
        return (title, budget)
    }

    /// Returns a material for "> ..." / ">? ..." lines (only meaningful inside a
    /// structured doc; callers gate on `hasHeading`).
    static func parseMaterial(_ line: String) -> CueMaterial? {
        var s = dropLeadingBlanks(Substring(line))
        guard s.first == ">" else { return nil }
        s = s.dropFirst()
        var isOptional = false
        if s.first == "?" {
            isOptional = true
            s = s.dropFirst()
        }
        let text = String(s).trimmingCharacters(in: .whitespaces)
        return CueMaterial(text: text, isOptional: isOptional)
    }

    // MARK: - Helpers

    private static func dropLeadingBlanks(_ s: Substring) -> Substring {
        var t = s
        while let f = t.first, f == " " || f == "\t" { t = t.dropFirst() }
        return t
    }

    private static func joinSpoken(_ lines: [String]) -> String {
        lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extracts a trailing "[m:ss]" / "[mm:ss]" budget from a heading title.
    /// Returns the title with the budget stripped and the budget in seconds.
    private static func splitTimeBudget(_ title: String) -> (String, Int?) {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard t.hasSuffix("]"), let open = t.lastIndex(of: "[") else { return (t, nil) }
        let inside = t[t.index(after: open)..<t.index(before: t.endIndex)]
        let parts = inside.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let m = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let sec = Int(parts[1].trimmingCharacters(in: .whitespaces)),
              m >= 0, sec >= 0, sec < 60 else {
            return (t, nil)
        }
        let clean = String(t[t.startIndex..<open]).trimmingCharacters(in: .whitespaces)
        return (clean, m * 60 + sec)
    }
}
