//
//  ScriptTokenizer.swift
//  Cueflow (随读)
//
//  Pure-Foundation tokenizer used by voice-follow (F3). Splits a script into
//  normalized comparison tokens: CJK is split per character, Latin per word.
//  Each token keeps its character offsets in the source for later highlighting.
//  No app dependencies → unit-testable standalone.
//

import Foundation

struct ScriptToken: Equatable {
    /// Normalized form used for matching (lowercased, punctuation stripped,
    /// full-width folded to half-width).
    let text: String
    /// Character offsets into the source string (end exclusive).
    let start: Int
    let end: Int
}

enum ScriptTokenizer {
    /// Tokenize a script into normalized tokens with source offsets.
    static func tokenize(_ source: String) -> [ScriptToken] {
        var tokens: [ScriptToken] = []
        let chars = Array(source)
        var wordStart = -1
        var wordChars = ""

        func flushWord(end: Int) {
            guard wordStart >= 0, !wordChars.isEmpty else { wordStart = -1; wordChars = ""; return }
            let norm = normalize(wordChars)
            if !norm.isEmpty {
                tokens.append(ScriptToken(text: norm, start: wordStart, end: end))
            }
            wordStart = -1
            wordChars = ""
        }

        for i in 0..<chars.count {
            let c = chars[i]
            if isCJK(c) {
                flushWord(end: i)
                let norm = normalize(String(c))
                if !norm.isEmpty {
                    tokens.append(ScriptToken(text: norm, start: i, end: i + 1))
                }
            } else if c.isLetter || c.isNumber {
                if wordStart < 0 { wordStart = i }
                wordChars.append(c)
            } else {
                flushWord(end: i)
            }
        }
        flushWord(end: chars.count)
        return tokens
    }

    /// Convenience: just the normalized token strings (used for recognized text).
    static func tokens(_ source: String) -> [String] {
        tokenize(source).map(\.text).filter { !$0.isEmpty }
    }

    /// Normalize a fragment: NFKC fold (full→half width), lowercase, keep only
    /// alphanumerics and CJK scalars.
    static func normalize(_ s: String) -> String {
        let folded = s.precomposedStringWithCompatibilityMapping.lowercased()
        var out = String.UnicodeScalarView()
        for u in folded.unicodeScalars where CharacterSet.alphanumerics.contains(u) || isCJKScalar(u) {
            out.append(u)
        }
        return String(out)
    }

    // MARK: Classification

    static func isCJK(_ c: Character) -> Bool {
        c.unicodeScalars.contains(where: isCJKScalar)
    }

    static func isCJKScalar(_ u: Unicode.Scalar) -> Bool {
        switch u.value {
        case 0x4E00...0x9FFF,   // CJK Unified Ideographs
             0x3400...0x4DBF,   // Ext A
             0xF900...0xFAFF,   // Compatibility Ideographs
             0x3040...0x30FF,   // Hiragana + Katakana
             0xAC00...0xD7AF:   // Hangul syllables
            return true
        default:
            return false
        }
    }
}
