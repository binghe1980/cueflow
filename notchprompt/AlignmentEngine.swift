//
//  AlignmentEngine.swift
//  Cueflow (随读)
//
//  Pure-Foundation forced-alignment for voice-follow (F3). Maintains a cursor
//  into the script tokens and relocates it from a stream of recognized tokens
//  using a whole-script anchored, gap-tolerant backward match.
//
//  Matching is FUZZY/phonetic so common ASR errors still align:
//   • CJK characters are compared by toneless pinyin → homophone errors match
//     (the #1 Chinese ASR error, e.g. 云/运/晕 all "yun").
//   • Latin words are compared by small edit distance → near-misses match
//     (e.g. "claude" vs "cloud", "demo" vs "demos").
//  Whole-script search lets the cursor follow arbitrary jumps; proximity to the
//  current cursor only breaks ties. No app deps beyond ScriptTokenizer (CJK test).
//

import Foundation

struct AlignmentConfig {
    /// Number of most-recent recognized tokens to consider as the "needle".
    var lookback: Int = 12
    /// Skipped script tokens tolerated while scoring (omissions/misrecognitions).
    var maxGap: Int = 4
    /// Minimum aligned tokens required to (re)locate the cursor — guards noise.
    var minScore: Int = 3
}

final class AlignmentEngine {
    let script: [String]
    let config: AlignmentConfig
    private let scriptKeys: [String]            // phonetic/normalized match keys
    private(set) var cursor: Int = 0            // tokens read through (0...count)

    init(script: [String], config: AlignmentConfig = AlignmentConfig()) {
        self.script = script
        self.config = config
        self.scriptKeys = script.map(AlignmentEngine.phoneticKey)
    }

    func reset() { cursor = 0 }

    @discardableResult
    func consume(recognizedTail: [String]) -> Int {
        guard !scriptKeys.isEmpty, !recognizedTail.isEmpty else { return cursor }
        let needle = recognizedTail.suffix(config.lookback).map(AlignmentEngine.phoneticKey)
        guard let last = needle.last else { return cursor }

        var best: (anchor: Int, score: Int, distance: Int)?
        for anchor in 0..<scriptKeys.count where AlignmentEngine.keysSimilar(scriptKeys[anchor], last) {
            let score = backwardMatchScore(anchoredAt: anchor, needle: needle)
            guard score >= config.minScore else { continue }
            let distance = abs(anchor - cursor)
            if let b = best {
                let better = (score != b.score) ? (score > b.score) : (distance < b.distance)
                if better { best = (anchor, score, distance) }
            } else {
                best = (anchor, score, distance)
            }
        }

        if let b = best { cursor = b.anchor + 1 }
        return cursor
    }

    /// Count fuzzily-aligned tokens scanning backward from `anchor`, allowing a
    /// limited number of skipped script tokens.
    private func backwardMatchScore(anchoredAt anchor: Int, needle: [String]) -> Int {
        var ni = needle.count - 1
        var si = anchor
        var matches = 0
        var gaps = 0
        while ni >= 0 && si >= 0 {
            if AlignmentEngine.keysSimilar(needle[ni], scriptKeys[si]) {
                matches += 1
                ni -= 1
                si -= 1
            } else {
                gaps += 1
                if gaps > config.maxGap { break }
                si -= 1
            }
            if anchor - si > config.lookback + config.maxGap { break }
        }
        return matches
    }

    // MARK: - Fuzzy / phonetic matching

    /// A single CJK char → toneless pinyin (homophones share a key); otherwise the
    /// token unchanged (already normalized lowercase by ScriptTokenizer).
    static func phoneticKey(_ token: String) -> String {
        if token.count == 1,
           let scalar = token.unicodeScalars.first,
           ScriptTokenizer.isCJKScalar(scalar) {
            let m = NSMutableString(string: token)
            CFStringTransform(m, nil, kCFStringTransformMandarinLatin, false)
            CFStringTransform(m, nil, kCFStringTransformStripDiacritics, false)
            return (m as String).replacingOccurrences(of: " ", with: "").lowercased()
        }
        return token
    }

    /// Exact match, or — for word-like keys (≥4 chars) — a small edit distance.
    /// Short keys (incl. short pinyin) require exact match to avoid over-merging.
    static func keysSimilar(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let la = a.count, lb = b.count
        guard min(la, lb) >= 4 else { return false }
        let distance = levenshtein(Array(a), Array(b))
        return distance <= max(1, Int((Double(max(la, lb)) * 0.34).rounded()))
    }

    static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var cur = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                cur[j] = Swift.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }
}

extension AlignmentEngine {
    /// Simulate streaming recognition (revealing a growing tail) for tests/spike.
    static func simulate(script: [String], spoken: [String], config: AlignmentConfig = AlignmentConfig()) -> [Int] {
        let engine = AlignmentEngine(script: script, config: config)
        var revealed: [String] = []
        var trace: [Int] = []
        for tok in spoken {
            revealed.append(tok)
            trace.append(engine.consume(recognizedTail: revealed))
        }
        return trace
    }
}
