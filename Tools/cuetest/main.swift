//
//  main.swift  (Tools/cuetest)
//  Standalone self-test for CueParser. Not part of the app target.
//
//  Run:
//    swiftc notchprompt/CueScript.swift Tools/cuetest/main.swift -o .build-dd/cuetest && .build-dd/cuetest
//

import Foundation

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    if cond {
        print("  ok  - \(msg)")
    } else {
        failures += 1
        print("  FAIL- \(msg)")
    }
}

// MARK: - 1. Backward compatibility: plain prose is untouched.
do {
    let raw = "第一句话。\n\n第二句话，没有任何结构标记。\n第三行。"
    let s = CueParser.parse(raw)
    check(s.hasStructure == false, "plain prose -> hasStructure == false")
    check(s.spokenOnly == raw, "plain prose -> spokenOnly is byte-identical to raw")
    check(s.sections.isEmpty, "plain prose -> no sections")
    check(s.canUseCueMode == false, "plain prose -> cannot use cue mode")
}

// MARK: - 2. A stray '>' line WITHOUT any heading stays unstructured (safety).
do {
    let raw = "他说：\n> 这是一句引用，不该被当作弹药\n继续讲。"
    let s = CueParser.parse(raw)
    check(s.hasStructure == false, "'>' without heading -> still unstructured")
    check(s.spokenOnly == raw, "'>' without heading -> spokenOnly == raw (no filtering)")
}

// MARK: - 3. Structured script: heading + spoken + must/optional materials.
do {
    let raw = """
    ## 开场：为什么"慢就是快" [2:00]
    品牌做久了，大家都在抢快。
    > 数据：复购率 +30%
    >? 备用：可以提一句蔚来换电

    ## 三个误区 [3:30]
    > 案例：星巴克第三空间
    """
    let s = CueParser.parse(raw)
    check(s.hasStructure, "structured -> hasStructure == true")
    check(s.canUseCueMode, "structured -> canUseCueMode == true")
    check(s.sections.count == 2, "structured -> 2 sections (got \(s.sections.count))")

    let s0 = s.sections[0]
    check(s0.title == "开场：为什么\"慢就是快\"", "section0 title stripped of '##' and budget")
    check(s0.timeBudgetSeconds == 120, "section0 budget == 120s")
    check(s0.spoken == "品牌做久了，大家都在抢快。", "section0 spoken excludes materials")
    check(s0.materials.count == 2, "section0 has 2 materials")
    check(s0.materials[0] == CueMaterial(text: "数据：复购率 +30%", isOptional: false), "material0 is must-say")
    check(s0.materials[1] == CueMaterial(text: "备用：可以提一句蔚来换电", isOptional: true), "material1 is optional")

    let s1 = s.sections[1]
    check(s1.title == "三个误区", "section1 title")
    check(s1.timeBudgetSeconds == 210, "section1 budget == 210s")
    check(s1.materials.count == 1 && !s1.materials[0].isOptional, "section1 has 1 must-say material")

    // spokenOnly drops every heading and material line.
    check(!s.spokenOnly.contains("数据"), "spokenOnly drops materials")
    check(!s.spokenOnly.contains("##"), "spokenOnly drops headings")
    check(s.spokenOnly.contains("品牌做久了"), "spokenOnly keeps spoken text")
}

// MARK: - 4. Intro content before the first heading becomes a no-title section.
do {
    let raw = """
    这段在第一个标题之前。
    ## 正文
    > 弹药一
    """
    let s = CueParser.parse(raw)
    check(s.sections.count == 2, "intro -> 2 sections incl. implicit intro (got \(s.sections.count))")
    check(s.sections[0].title.isEmpty, "intro section has empty title")
    check(s.sections[0].spoken == "这段在第一个标题之前。", "intro spoken captured")
    check(s.sections[1].title == "正文", "second section is the real heading")
}

// MARK: - 5. Time-budget edge cases.
do {
    check(CueParser.parseHeading("## A [0:45]")?.budget == 45, "[0:45] -> 45s")
    check(CueParser.parseHeading("## B [10:05]")?.budget == 605, "[10:05] -> 605s")
    check(CueParser.parseHeading("## C")?.budget == nil, "no budget -> nil")
    check(CueParser.parseHeading("## D [99]")?.budget == nil, "malformed [99] -> nil, title kept")
    check(CueParser.parseHeading("## D [99]")?.title == "D [99]", "malformed budget stays in title")
    check(CueParser.parseHeading("text") == nil, "non-heading -> nil")
    check(CueParser.parseHeading("#tag") == nil, "'#tag' (no space) -> not a heading")
    check(CueParser.parseHeading("# Title")?.title == "Title", "single '#' is also a heading (flat)")
}

// MARK: - 6. Material marker variants.
do {
    check(CueParser.parseMaterial("> x") == CueMaterial(text: "x", isOptional: false), "'> x' must")
    check(CueParser.parseMaterial(">? x") == CueMaterial(text: "x", isOptional: true), "'>? x' optional")
    check(CueParser.parseMaterial(">x") == CueMaterial(text: "x", isOptional: false), "'>x' (no space) must")
    check(CueParser.parseMaterial("  > x") == CueMaterial(text: "x", isOptional: false), "leading spaces ok")
    check(CueParser.parseMaterial("plain") == nil, "plain line -> not material")
}

print("")
if failures == 0 {
    print("ALL CUEPARSER TESTS PASSED ✅")
    exit(0)
} else {
    print("\(failures) FAILURE(S) ❌")
    exit(1)
}
