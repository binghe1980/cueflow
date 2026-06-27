//
//  PrompterModel.swift
//  notchprompt
//
//  Created by Saif on 2026-02-08.
//

import Foundation
import Combine
import CoreGraphics

@MainActor
final class PrompterModel: ObservableObject {
    enum ScrollMode: String, CaseIterable {
        case infinite
        case stopAtEnd
    }
    
    enum CountdownBehavior: String, CaseIterable {
        case always
        case freshStartOnly
        case never
        
        var label: String {
            switch self {
            case .always:
                return "Always"
            case .freshStartOnly:
                return "Fresh start only"
            case .never:
                return "Never"
            }
        }
    }

    enum DisplayMode: String, CaseIterable {
        case notch
        case floating
    }

    enum VoiceEngine: String, CaseIterable {
        case auto          // 按稿件自动选（推荐）
        case appleZh       // 系统识别·中文
        case appleEn       // 系统识别·英文
        case whisperMixed  // 本地 WhisperKit·中英混读
    }

    /// F5: 朗读模式。`normal` 保留既有行为（自动播放 / 语音跟随，由各自既有状态驱动）；
    /// `cue` 为新增的「随讲」提纲卡模式。两者与窗口形态(notch/floating)正交。
    enum ReadingMode: String {
        case normal
        case cue
    }

    /// F6 动效风格。`standard` 为默认 spring；`brisk` 更短更轻；`minimal` 几乎无动画
    /// （无障碍/性能优先）。系统「减弱动态效果」开启时由 Motion 层强制降级为 minimal。
    enum MotionStyle: String, CaseIterable, Identifiable {
        case standard
        case brisk
        case minimal
        var id: String { rawValue }
    }

    /// F6 计时器形态。`off` 不显示；`countUp` 正计时（已用时）；`countDown` 倒计时到目标；
    /// `remaining` 按剩余字数 × 当前语速估算预计剩余（仅 stopAtEnd 滚动有意义）。
    enum TimerMode: String, CaseIterable, Identifiable {
        case off
        case countUp
        case countDown
        case remaining
        var id: String { rawValue }
    }

    static let shared = PrompterModel()

    @Published var script: String = """
Paste your script here.

Tip: Use the menu bar icon to start/pause or reset the scroll.
""" {
        didSet {
            guard oldValue != script else { return }
            cueScript = CueParser.parse(script)
        }
    }

    // F5 随讲：当前脚本解析出的结构（随 script 变化缓存）。对无结构脚本，
    // `spokenOnly == script`，自动/语音模式行为与重构前一致（向后兼容）。
    @Published private(set) var cueScript: CueScript = CueScript(sections: [], hasStructure: false, spokenOnly: "")
    // 当前朗读模式；默认 normal，仅用户显式按热键/菜单才进入 cue。
    @Published var readingMode: ReadingMode = .normal
    // 随讲当前所在大纲点（会话内，不持久化；切脚本不保留位置）。
    @Published var activeSectionIndex: Int = 0
    // 随讲总览（鸟瞰整份大纲）开关，⌥⌘L 切换；会话内，不持久化。
    @Published var cueShowingOverview: Bool = false
    // 当前点内"滚动到第几条弹药"——↑↓ 调整，用于点内弹药超出刘海高度时翻看。
    @Published var cueMaterialIndex: Int = 0
    // 随讲模式刘海高度（可在设置里调整，持久化）。
    @Published var cueNotchHeight: Double = 300
    // 是否在随讲刘海显示全场累计用时（默认关，避免干扰）。
    @Published var showCueTotalTimer: Bool = false
    // 计时锚点：进入当前大纲点的时刻 / 进入随讲的时刻（会话内，不持久化）。
    @Published var cueSectionStartedAt: Date?
    @Published var cueStartedAt: Date?

    // F5 脚本库：当前加载进提词器的库条目（刘海显示的就是它）。粘贴/清空时置 nil
    // 表示"未保存的临时内容"。菜单 ✓ 与循环切换都以它为准。
    @Published var activeScriptID: UUID?

    // 空格暂停/继续（自动滚动时）。会话从 start() 开始、到 reset/清空/切脚本/进随讲
    // 结束；空格热键仅在会话内、且本 App 不在前台编辑时启用（见 AppDelegate），
    // 以免抢占编辑器/设置里的空格输入。
    @Published var spacePauseEnabled: Bool = true
    @Published private(set) var scrollSessionActive: Bool = false
    // 切换脚本时让刘海短暂浮出脚本名（无弹窗，录屏友好）。token 变化即触发一次。
    @Published private(set) var scriptFlashToken: UUID = UUID()
    private(set) var scriptFlashTitle: String = ""

    @Published var isRunning: Bool = false
    @Published var manualScrollEnabled: Bool = false
    @Published var isOverlayVisible: Bool = true
    @Published var privacyModeEnabled: Bool = true
    @Published private(set) var hasStartedSession: Bool = false
    @Published private(set) var isCountingDown: Bool = false
    @Published var countdownSeconds: Int = 3
    @Published var countdownBehavior: CountdownBehavior = .freshStartOnly
    @Published private(set) var countdownRemaining: Int = 0
    @Published private(set) var didReachEndInStopMode: Bool = false

    // Visual / behavior tuning
    @Published var speedPointsPerSecond: Double = 80
    @Published var fontSize: Double = 20
    @Published var overlayWidth: Double = 600
    @Published var overlayHeight: Double = 150
    // Window form (F4): notch overlay vs. free-floating window. Mutually exclusive.
    @Published var displayMode: DisplayMode = .notch
    @Published var adaptiveFontSize: Bool = true
    @Published var floatingWidth: Double = 700
    @Published var floatingHeight: Double = 320
    // NaN means "not yet positioned" -> center on first show.
    @Published var floatingOriginX: Double = .nan
    @Published var floatingOriginY: Double = .nan
    // F3 voice-follow recognition engine.
    @Published var voiceEngine: VoiceEngine = .auto
    // Notch height while voice-following (user-adjustable for read-ahead room).
    @Published var voiceFollowNotchHeight: Double = 280
    // Deprecated user setting: keep as a fixed constant unless changed explicitly in code.
    @Published var backgroundOpacity: Double = 1.0
    @Published var scrollMode: ScrollMode = .infinite
    // F6 动效风格（持久化）。
    @Published var motionStyle: MotionStyle = .standard
    // F6 计时器形态与倒计时目标秒数（持久化）。
    @Published var timerMode: TimerMode = .off
    @Published var timerTargetSeconds: Int = 60
    // F6 排练统计开关；关闭后不记录会话（持久化，默认开）。
    @Published var statsEnabled: Bool = true
    // F6 每次提词结束弹出会话小结卡（持久化，默认开）。
    @Published var showSessionSummary: Bool = true
    // F7 触控板手势翻页总开关（持久化，默认开）。关闭后横向手势与随讲纵向翻弹药停用；
    // 普通模式的纵向手动滚动是既有基础交互，始终保留。
    @Published var gestureControlEnabled: Bool = true
    // F8 留海迷你提词（单行跑马灯当前句）。开启后普通模式留海缩成一行（持久化，默认关）。
    @Published var miniPrompterEnabled: Bool = false
    // 免提裸键总开关（持久化，默认关）。关闭时 App 绝不全局占用 空格/↑↓/1-9/←→ 等裸键，
    // 不影响在其它 App 打字；仅演示时按需开启，配合翻页笔/单手控制。⌥⌘ 组合键不受此影响。
    @Published var handsFreeKeysEnabled: Bool = false
    /// 0 means "auto" (prefer built-in display)
    @Published var selectedScreenID: CGDirectDisplayID = 0
    // Fraction of the viewport height to fade at top and bottom.
    let edgeFadeFraction: Double = 0.20

    // Used to signal an immediate reset to the scrolling view.
    @Published private(set) var resetToken: UUID = UUID()
    @Published private(set) var jumpBackToken: UUID = UUID()
    @Published private(set) var jumpBackDistancePoints: CGFloat = 0
    @Published private(set) var manualScrollToken: UUID = UUID()
    @Published private(set) var manualScrollDeltaPoints: CGFloat = 0
    private(set) var savedScrollPhaseForResume: CGFloat?

    private var countdownTask: Task<Void, Never>?
    private var shouldUseCountdownOnNextStart: Bool = true

    static let speedRange: ClosedRange<Double> = 10...300
    static let speedStep: Double = 5
    static let speedPresetSlow: Double = 55
    static let speedPresetNormal: Double = 85
    static let speedPresetFast: Double = 125

    private enum DefaultsKey {
        static let hasSavedSession = "hasSavedSession"
        static let script = "script"
        static let isRunning = "isRunning"
        static let isOverlayVisible = "isOverlayVisible"
        static let privacyModeEnabled = "privacyModeEnabled"
        static let speed = "speedPointsPerSecond"
        static let fontSize = "fontSize"
        static let overlayWidth = "overlayWidth"
        static let overlayHeight = "overlayHeight"
        static let countdownSeconds = "countdownSeconds"
        static let countdownBehavior = "countdownBehavior"
        static let scrollMode = "scrollMode"
        static let selectedScreenID = "selectedScreenID"
        static let displayMode = "displayMode"
        static let adaptiveFontSize = "adaptiveFontSize"
        static let floatingWidth = "floatingWidth"
        static let floatingHeight = "floatingHeight"
        static let floatingOriginX = "floatingOriginX"
        static let floatingOriginY = "floatingOriginY"
        static let voiceEngine = "voiceEngine"
        static let voiceFollowNotchHeight = "voiceFollowNotchHeight"
        static let activeScriptID = "activeScriptID"
        static let cueNotchHeight = "cueNotchHeight"
        static let showCueTotalTimer = "showCueTotalTimer"
        static let spacePauseEnabled = "spacePauseEnabled"
        static let motionStyle = "motionStyle"
        static let timerMode = "timerMode"
        static let timerTargetSeconds = "timerTargetSeconds"
        static let statsEnabled = "statsEnabled"
        static let showSessionSummary = "showSessionSummary"
        static let gestureControlEnabled = "gestureControlEnabled"
        static let miniPrompterEnabled = "miniPrompterEnabled"
        static let handsFreeKeysEnabled = "handsFreeKeysEnabled"
    }

    private init() {
        cueScript = CueParser.parse(script)
    }

    deinit {
        countdownTask?.cancel()
    }

    // MARK: - 随讲（cue card）模式

    func toggleCueMode() {
        if readingMode == .cue { exitCueMode() } else { enterCueMode() }
    }

    func enterCueMode() {
        guard readingMode != .cue else { return }
        // 进入随讲前停掉滚动/倒计时（语音跟随由调用方停，见 AppDelegate）。
        stop()
        manualScrollEnabled = false
        let count = cueScript.sections.count
        activeSectionIndex = count > 0 ? min(max(0, activeSectionIndex), count - 1) : 0
        let now = Date()
        cueStartedAt = now
        cueSectionStartedAt = now
        cueShowingOverview = false
        cueMaterialIndex = 0
        scrollSessionActive = false
        readingMode = .cue
    }

    func exitCueMode() {
        guard readingMode == .cue else { return }
        readingMode = .normal
        cueShowingOverview = false
        cueStartedAt = nil
        cueSectionStartedAt = nil
    }

    /// Toggle the bird's-eye overview of the whole outline (⌥⌘L).
    func toggleCueOverview() {
        guard readingMode == .cue else { return }
        cueShowingOverview.toggle()
    }

    /// Jump straight to a point by index (bare 1–9). Returns to the detail view.
    func cueJumpToSection(_ index: Int) {
        guard readingMode == .cue else { return }
        let count = cueScript.sections.count
        guard count > 0, index >= 0, index < count else { return }
        cueShowingOverview = false
        setCueSection(index)
    }

    func cueNextSection() {
        guard readingMode == .cue else { return }
        let count = cueScript.sections.count
        guard count > 0 else { return }
        setCueSection(min(activeSectionIndex + 1, count - 1))
    }

    func cuePrevSection() {
        guard readingMode == .cue, cueScript.sections.count > 0 else { return }
        setCueSection(max(activeSectionIndex - 1, 0))
    }

    /// Move to a section, restarting the per-point timer only on an actual change.
    private func setCueSection(_ index: Int) {
        guard index != activeSectionIndex else { return }
        activeSectionIndex = index
        cueSectionStartedAt = Date()
        cueMaterialIndex = 0   // new point starts at the top of its materials
    }

    /// ↑↓ in 随讲. In the overview it moves the highlight through the vertical
    /// list of points; in the detail view it scrolls the current point's
    /// materials (revealing ones that overflow the notch height, hands-free).
    func cueScrollMaterials(_ delta: Int) {
        guard readingMode == .cue else { return }
        let count = cueScript.sections.count
        guard count > 0 else { return }

        if cueShowingOverview {
            setCueSection(min(max(0, activeSectionIndex + delta), count - 1))
            return
        }

        let idx = min(max(0, activeSectionIndex), count - 1)
        let materialCount = cueScript.sections[idx].materials.count
        guard materialCount > 0 else { return }
        cueMaterialIndex = min(max(0, cueMaterialIndex + delta), materialCount - 1)
    }

    func pasteScript(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        script = text
        // Pasted text is unsaved scratch — it is no longer a loaded library item.
        activeScriptID = nil
        scrollSessionActive = false
        // Show pasted text immediately (static at the top); scrolling still
        // only begins on Start.
        hasStartedSession = true
        autoEnterCueIfPureOutline()
    }

    /// A pure-outline script (headings/materials only, no read-aloud lines) has
    /// nothing to auto-scroll, so open it straight in 随讲 instead of showing a
    /// blank/hint normal view. Mixed scripts (with spoken text) stay in normal.
    private func autoEnterCueIfPureOutline() {
        if readingMode != .cue, cueScript.hasStructure, !cueScript.hasSpoken {
            enterCueMode()
        }
    }

    /// Clear the live prompter text and detach from any loaded library item.
    func clearScript() {
        script = ""
        activeScriptID = nil
        scrollSessionActive = false
    }

    // MARK: - 脚本库加载 / 切换

    /// Load a saved library item into the prompter and mark it active.
    func loadLibraryScript(_ id: UUID) {
        guard let content = ScriptLibrary.shared.content(for: id) else { return }
        script = content
        activeScriptID = id
        // Switching scripts always starts a fresh cue run from the first point.
        activeSectionIndex = 0
        cueMaterialIndex = 0
        if readingMode == .cue { cueSectionStartedAt = Date() }
        scrollSessionActive = false
        hasStartedSession = true
        flashScriptTitle(ScriptLibrary.shared.title(for: id))
        autoEnterCueIfPureOutline()
    }

    /// Cycle to the next/previous library item (hands-free, ⌥⌘] / ⌥⌘[).
    func activateAdjacentScript(forward: Bool) {
        guard let id = ScriptLibrary.shared.cycledID(from: activeScriptID, forward: forward) else { return }
        loadLibraryScript(id)
    }

    private func flashScriptTitle(_ title: String?) {
        let trimmed = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        scriptFlashTitle = trimmed.isEmpty ? L(.libUntitled) : trimmed
        scriptFlashToken = UUID()
    }

    func resetScroll() {
        didReachEndInStopMode = false
        shouldUseCountdownOnNextStart = true
        savedScrollPhaseForResume = nil
        scrollSessionActive = false
        resetToken = UUID()
    }

    func saveScrollPhaseForResume(_ phase: CGFloat) {
        savedScrollPhaseForResume = phase
    }

    func jumpBack(seconds: Double = 5) {
        guard seconds > 0 else { return }
        didReachEndInStopMode = false
        jumpBackDistancePoints = CGFloat(speedPointsPerSecond * seconds)
        jumpBackToken = UUID()
    }

    func switchPlaybackModeFromOverlayControl() {
        // 在随讲模式下点播放，先回到普通模式再走自动/手动逻辑。
        if readingMode == .cue { readingMode = .normal }
        if isRunning || isCountingDown {
            stop()
            manualScrollEnabled = true
            didReachEndInStopMode = false
            hasStartedSession = true
            shouldUseCountdownOnNextStart = false
            return
        }

        manualScrollEnabled = false
        start()
    }

    func handleManualScroll(deltaPoints: CGFloat) {
        guard abs(deltaPoints) > 0.01 else { return }

        if !manualScrollEnabled {
            manualScrollEnabled = true
        }

        if isRunning || isCountingDown {
            stop()
        }

        didReachEndInStopMode = false
        hasStartedSession = true
        shouldUseCountdownOnNextStart = false
        manualScrollDeltaPoints = deltaPoints
        manualScrollToken = UUID()
    }

    // MARK: - F7 手势分派

    enum GestureDirection { case left, right }

    /// 横向双指滑（离散，一次一步）。普通模式=调速，随讲模式=跳段。
    /// 受 `gestureControlEnabled` 总开关控制。
    func handleHorizontalGesture(_ direction: GestureDirection) {
        guard gestureControlEnabled else { return }
        if readingMode == .cue {
            switch direction {
            case .right: cueNextSection()
            case .left:  cuePrevSection()
            }
        } else {
            switch direction {
            case .right: adjustSpeed(delta: Self.speedStep)
            case .left:  adjustSpeed(delta: -Self.speedStep)
            }
        }
    }

    /// 纵向离散一步。随讲模式=翻看本点弹药。普通模式的纵向走连续 `handleManualScroll`，
    /// 不经过这里。受 `gestureControlEnabled` 控制。
    func handleVerticalDiscrete(_ delta: Int) {
        guard gestureControlEnabled, readingMode == .cue else { return }
        cueScrollMaterials(delta)
    }

    func toggleRunning() {
        if isRunning || isCountingDown {
            stop()
        } else {
            start()
        }
    }

    func start() {
        if isRunning || isCountingDown {
            return
        }

        manualScrollEnabled = false

        if scrollMode == .stopAtEnd, didReachEndInStopMode {
            // Keyboard "start" from end should restart from the top without requiring manual reset.
            resetScroll()
        }

        // A play/pause session is now active (enables the Space key; released on
        // reset / clear / script switch / entering 随讲). Set after the possible
        // resetScroll() above so it isn't cleared.
        scrollSessionActive = true

        let delay = max(0, countdownSeconds)
        let shouldRunCountdown: Bool
        switch countdownBehavior {
        case .always:
            shouldRunCountdown = delay > 0
        case .freshStartOnly:
            shouldRunCountdown = delay > 0 && shouldUseCountdownOnNextStart
        case .never:
            shouldRunCountdown = false
        }
        
        guard shouldRunCountdown else {
            beginRunningNow()
            return
        }
        
        beginCountdown(seconds: delay)
    }

    func markReachedEndInStopMode() {
        guard scrollMode == .stopAtEnd else { return }
        didReachEndInStopMode = true
        stop()
    }

    func setScrollMode(_ newMode: ScrollMode) {
        // Entire transition is deferred to avoid publishing inside SwiftUI view updates.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let oldMode = self.scrollMode
            guard oldMode != newMode else { return }
            let wasTerminalStopState = (oldMode == .stopAtEnd && self.didReachEndInStopMode)

            self.scrollMode = newMode

            if newMode == .infinite {
                self.didReachEndInStopMode = false
                if wasTerminalStopState {
                    self.hasStartedSession = true
                    self.isCountingDown = false
                    self.countdownRemaining = 0
                    self.countdownTask?.cancel()
                    self.countdownTask = nil
                    self.shouldUseCountdownOnNextStart = false
                    self.isRunning = true
                }
            }
        }
    }

    func stop() {
        countdownTask?.cancel()
        countdownTask = nil
        isCountingDown = false
        countdownRemaining = 0
        isRunning = false
    }

    func setSpeed(_ value: Double) {
        speedPointsPerSecond = clampedSpeed(value)
    }

    func adjustSpeed(delta: Double) {
        let newValue = speedPointsPerSecond + delta
        setSpeed(newValue)
    }

    func applySpeedPreset(_ preset: Double) {
        setSpeed(preset)
    }

    /// F6 字数口径：中文/日文/韩文等表意字符按「字」计，连续的拉丁/数字串按「词」计。
    /// 适合中英混排的提词稿，用于统计与「预计剩余」估算。
    static func readingUnitCount(in text: String) -> Int {
        var count = 0
        var inLatinRun = false
        for scalar in text.unicodeScalars {
            let v = scalar.value
            // CJK 统一表意文字 + 扩展A + 假名 + 谚文等常见东亚区段，逐字计。
            let isCJK = (0x3040...0x30FF).contains(v)   // 日文假名
                || (0x3400...0x4DBF).contains(v)        // CJK 扩展A
                || (0x4E00...0x9FFF).contains(v)        // CJK 基本
                || (0xAC00...0xD7AF).contains(v)        // 谚文音节
                || (0xF900...0xFAFF).contains(v)        // CJK 兼容
            if isCJK {
                count += 1
                inLatinRun = false
            } else if CharacterSet.alphanumerics.contains(scalar) {
                if !inLatinRun { count += 1; inLatinRun = true }
            } else {
                inLatinRun = false
            }
        }
        return count
    }

    /// 当前提词稿的字数（按上面的中英口径）。
    var scriptUnitCount: Int { Self.readingUnitCount(in: script) }

    var estimatedReadDuration: TimeInterval {
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        let words = max(1, trimmed.split(whereSeparator: \.isWhitespace).count)
        // Approximation: 160 words/minute baseline adjusted by current speed.
        let baselineWPM = 160.0
        let speedFactor = speedPointsPerSecond / Self.speedPresetNormal
        let adjustedWPM = max(60, baselineWPM * speedFactor)
        let minutes = Double(words) / adjustedWPM
        return minutes * 60
    }

    func formattedEstimatedReadDuration() -> String {
        let duration = Int(round(estimatedReadDuration))
        guard duration > 0 else { return "~0s" }
        if duration < 60 {
            return "~\(duration)s"
        }
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "~%dm %02ds", minutes, seconds)
    }

    func loadFromDefaults() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: DefaultsKey.hasSavedSession) else {
            return
        }

        if let savedScript = defaults.string(forKey: DefaultsKey.script) {
            script = savedScript
        }

        privacyModeEnabled = defaults.object(forKey: DefaultsKey.privacyModeEnabled) as? Bool ?? privacyModeEnabled
        isOverlayVisible = defaults.object(forKey: DefaultsKey.isOverlayVisible) as? Bool ?? true
        // Never auto-start on launch; require explicit user start each session.
        isRunning = false
        isCountingDown = false
        countdownRemaining = 0
        hasStartedSession = false
        shouldUseCountdownOnNextStart = true
        speedPointsPerSecond = clampedSpeed(defaults.object(forKey: DefaultsKey.speed) as? Double ?? speedPointsPerSecond)
        fontSize = clamp(defaults.object(forKey: DefaultsKey.fontSize) as? Double ?? fontSize, lower: 12, upper: 40)
        overlayWidth = clamp(defaults.object(forKey: DefaultsKey.overlayWidth) as? Double ?? overlayWidth, lower: 400, upper: 1200)
        overlayHeight = clamp(defaults.object(forKey: DefaultsKey.overlayHeight) as? Double ?? overlayHeight, lower: 120, upper: 300)
        // Opacity UI has been removed; always render fully opaque by default.
        backgroundOpacity = 1.0
        defaults.removeObject(forKey: "backgroundOpacity")
        countdownSeconds = Int(clamp(Double(defaults.object(forKey: DefaultsKey.countdownSeconds) as? Int ?? countdownSeconds), lower: 0, upper: 10))
        if let rawValue = defaults.string(forKey: DefaultsKey.countdownBehavior),
           let savedBehavior = CountdownBehavior(rawValue: rawValue) {
            countdownBehavior = savedBehavior
        } else {
            countdownBehavior = .freshStartOnly
        }
        if let rawValue = defaults.string(forKey: DefaultsKey.scrollMode),
           let savedMode = ScrollMode(rawValue: rawValue) {
            scrollMode = savedMode
        } else {
            scrollMode = .infinite
        }
        selectedScreenID = CGDirectDisplayID(defaults.object(forKey: DefaultsKey.selectedScreenID) as? UInt32 ?? 0)

        if let rawValue = defaults.string(forKey: DefaultsKey.displayMode),
           let savedMode = DisplayMode(rawValue: rawValue) {
            displayMode = savedMode
        }
        adaptiveFontSize = defaults.object(forKey: DefaultsKey.adaptiveFontSize) as? Bool ?? true
        floatingWidth = clamp(defaults.object(forKey: DefaultsKey.floatingWidth) as? Double ?? floatingWidth, lower: 320, upper: 2200)
        floatingHeight = clamp(defaults.object(forKey: DefaultsKey.floatingHeight) as? Double ?? floatingHeight, lower: 160, upper: 1400)
        floatingOriginX = defaults.object(forKey: DefaultsKey.floatingOriginX) as? Double ?? .nan
        floatingOriginY = defaults.object(forKey: DefaultsKey.floatingOriginY) as? Double ?? .nan
        if let rawValue = defaults.string(forKey: DefaultsKey.voiceEngine),
           let v = VoiceEngine(rawValue: rawValue) {
            voiceEngine = v
        }
        voiceFollowNotchHeight = clamp(defaults.object(forKey: DefaultsKey.voiceFollowNotchHeight) as? Double ?? voiceFollowNotchHeight, lower: 180, upper: 600)
        if let raw = defaults.string(forKey: DefaultsKey.activeScriptID),
           let id = UUID(uuidString: raw),
           ScriptLibrary.shared.item(id) != nil {
            activeScriptID = id
        } else {
            activeScriptID = nil
        }
        cueNotchHeight = clamp(defaults.object(forKey: DefaultsKey.cueNotchHeight) as? Double ?? cueNotchHeight, lower: 180, upper: 600)
        showCueTotalTimer = defaults.object(forKey: DefaultsKey.showCueTotalTimer) as? Bool ?? showCueTotalTimer
        spacePauseEnabled = defaults.object(forKey: DefaultsKey.spacePauseEnabled) as? Bool ?? spacePauseEnabled
        if let raw = defaults.string(forKey: DefaultsKey.motionStyle), let v = MotionStyle(rawValue: raw) {
            motionStyle = v
        }
        if let raw = defaults.string(forKey: DefaultsKey.timerMode), let v = TimerMode(rawValue: raw) {
            timerMode = v
        }
        timerTargetSeconds = Int(clamp(Double(defaults.object(forKey: DefaultsKey.timerTargetSeconds) as? Int ?? timerTargetSeconds), lower: 5, upper: 3600))
        statsEnabled = defaults.object(forKey: DefaultsKey.statsEnabled) as? Bool ?? statsEnabled
        showSessionSummary = defaults.object(forKey: DefaultsKey.showSessionSummary) as? Bool ?? showSessionSummary
        gestureControlEnabled = defaults.object(forKey: DefaultsKey.gestureControlEnabled) as? Bool ?? gestureControlEnabled
        miniPrompterEnabled = defaults.object(forKey: DefaultsKey.miniPrompterEnabled) as? Bool ?? miniPrompterEnabled
        handsFreeKeysEnabled = defaults.object(forKey: DefaultsKey.handsFreeKeysEnabled) as? Bool ?? handsFreeKeysEnabled
    }

    func saveToDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: DefaultsKey.hasSavedSession)
        defaults.set(script, forKey: DefaultsKey.script)
        defaults.set(isRunning, forKey: DefaultsKey.isRunning)
        defaults.set(isOverlayVisible, forKey: DefaultsKey.isOverlayVisible)
        defaults.set(privacyModeEnabled, forKey: DefaultsKey.privacyModeEnabled)
        defaults.set(speedPointsPerSecond, forKey: DefaultsKey.speed)
        defaults.set(fontSize, forKey: DefaultsKey.fontSize)
        defaults.set(overlayWidth, forKey: DefaultsKey.overlayWidth)
        defaults.set(overlayHeight, forKey: DefaultsKey.overlayHeight)
        defaults.set(countdownSeconds, forKey: DefaultsKey.countdownSeconds)
        defaults.set(countdownBehavior.rawValue, forKey: DefaultsKey.countdownBehavior)
        defaults.set(scrollMode.rawValue, forKey: DefaultsKey.scrollMode)
        defaults.set(selectedScreenID, forKey: DefaultsKey.selectedScreenID)
        defaults.set(displayMode.rawValue, forKey: DefaultsKey.displayMode)
        defaults.set(adaptiveFontSize, forKey: DefaultsKey.adaptiveFontSize)
        defaults.set(floatingWidth, forKey: DefaultsKey.floatingWidth)
        defaults.set(floatingHeight, forKey: DefaultsKey.floatingHeight)
        if floatingOriginX.isFinite { defaults.set(floatingOriginX, forKey: DefaultsKey.floatingOriginX) }
        if floatingOriginY.isFinite { defaults.set(floatingOriginY, forKey: DefaultsKey.floatingOriginY) }
        defaults.set(voiceEngine.rawValue, forKey: DefaultsKey.voiceEngine)
        defaults.set(voiceFollowNotchHeight, forKey: DefaultsKey.voiceFollowNotchHeight)
        if let activeScriptID {
            defaults.set(activeScriptID.uuidString, forKey: DefaultsKey.activeScriptID)
        } else {
            defaults.removeObject(forKey: DefaultsKey.activeScriptID)
        }
        defaults.set(cueNotchHeight, forKey: DefaultsKey.cueNotchHeight)
        defaults.set(showCueTotalTimer, forKey: DefaultsKey.showCueTotalTimer)
        defaults.set(spacePauseEnabled, forKey: DefaultsKey.spacePauseEnabled)
        defaults.set(motionStyle.rawValue, forKey: DefaultsKey.motionStyle)
        defaults.set(timerMode.rawValue, forKey: DefaultsKey.timerMode)
        defaults.set(timerTargetSeconds, forKey: DefaultsKey.timerTargetSeconds)
        defaults.set(statsEnabled, forKey: DefaultsKey.statsEnabled)
        defaults.set(showSessionSummary, forKey: DefaultsKey.showSessionSummary)
        defaults.set(gestureControlEnabled, forKey: DefaultsKey.gestureControlEnabled)
        defaults.set(miniPrompterEnabled, forKey: DefaultsKey.miniPrompterEnabled)
        defaults.set(handsFreeKeysEnabled, forKey: DefaultsKey.handsFreeKeysEnabled)
    }

    private func beginCountdown(seconds: Int) {
        countdownTask?.cancel()
        isCountingDown = true
        countdownRemaining = seconds

        countdownTask = Task { @MainActor in
            var remaining = seconds
            while remaining > 0 {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    isCountingDown = false
                    countdownRemaining = 0
                    countdownTask = nil
                    return
                }
                remaining -= 1
                countdownRemaining = remaining
            }

            guard !Task.isCancelled else { return }
            beginRunningNow()
            countdownTask = nil
        }
    }
    
    private func beginRunningNow() {
        isCountingDown = false
        countdownRemaining = 0
        hasStartedSession = true
        shouldUseCountdownOnNextStart = false
        isRunning = true
    }

    private func clampedSpeed(_ value: Double) -> Double {
        let clamped = clamp(value, lower: Self.speedRange.lowerBound, upper: Self.speedRange.upperBound)
        let step = Self.speedStep
        return (clamped / step).rounded() * step
    }

    private func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
