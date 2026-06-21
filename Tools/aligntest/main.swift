//
//  main.swift — standalone verification for ScriptTokenizer + AlignmentEngine.
//  Run: swiftc notchprompt/ScriptTokenizer.swift notchprompt/AlignmentEngine.swift \
//             Tools/aligntest/main.swift -o .build-dd/aligntest && .build-dd/aligntest
//  Not part of the app target (lives outside the synchronized notchprompt/ group).
//

import Foundation

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    print((cond ? "✅ " : "❌ ") + msg)
    if !cond { failures += 1 }
}

// 1) Tokenizer: CJK per char, Latin per word, normalized, punctuation dropped.
let toks = ScriptTokenizer.tokens("Hello, 世界！ 2025  Cueflow")
check(toks == ["hello", "世", "界", "2025", "cueflow"], "tokenize mixed -> \(toks)")

// Full-width fold + lowercase
check(ScriptTokenizer.tokens("ＨＥＬＬＯ") == ["hello"], "full-width folds to half-width lowercase")

// 2) Script under test
let scriptText = "大家好 欢迎来到 Cueflow 这是 一个 提词器 测试 thank you very much"
let script = ScriptTokenizer.tokens(scriptText)
print("script (\(script.count)): \(script)")

// 3) Normal read: spoken == script -> cursor reaches the end.
let t1 = AlignmentEngine.simulate(script: script, spoken: script)
check(t1.last == script.count, "normal read reaches end: \(t1.last ?? -1)/\(script.count)")
check(zip(t1, t1.dropFirst()).allSatisfy { $0.1 >= $0.0 }, "normal read is monotonic non-decreasing")

// 4) Skip: omit "这是 一个" (4 CJK tokens) -> still reaches near the end.
let spokenSkip = ScriptTokenizer.tokens("大家好 欢迎来到 Cueflow 提词器 测试 thank you very much")
let t2 = AlignmentEngine.simulate(script: script, spoken: spokenSkip)
check((t2.last ?? 0) >= script.count - 1, "skip read reaches near end: \(t2.last ?? -1)")

// 5) Re-read: speaker repeats an earlier phrase -> cursor moves backward then recovers.
let spokenReread = ScriptTokenizer.tokens(
    "大家好 欢迎来到 Cueflow 这是 一个 欢迎来到 Cueflow 这是 一个 提词器 测试 thank you very much"
)
let engine = AlignmentEngine(script: script)
var revealed: [String] = []
var trace: [Int] = []
for tok in spokenReread { revealed.append(tok); trace.append(engine.consume(recognizedTail: revealed)) }
print("reread trace: \(trace)")
check(zip(trace, trace.dropFirst()).contains { $0.1 < $0.0 }, "re-read makes the cursor jump backward at some point")
check((trace.last ?? 0) >= script.count - 1, "after re-read, reaches near end: \(trace.last ?? -1)")

// 6) Fuzzy: homophone (云→运) + English near-miss (claude→cloud) still align.
let fuzzyScript = ScriptTokenizer.tokens("我们用 Claude 在云端跑")
let fuzzySpoken = ScriptTokenizer.tokens("我们用 cloud 在运端跑")  // claude→cloud, 云→运(同音)
let tf = AlignmentEngine.simulate(script: fuzzyScript, spoken: fuzzySpoken)
print("fuzzy script: \(fuzzyScript)  trace: \(tf)")
check((tf.last ?? 0) >= fuzzyScript.count - 1, "fuzzy(homophone+near word) reaches end: \(tf.last ?? -1)/\(fuzzyScript.count)")

print(failures == 0 ? "\nALL PASS ✅" : "\n\(failures) CHECK(S) FAILED ❌")
exit(failures == 0 ? 0 : 1)
