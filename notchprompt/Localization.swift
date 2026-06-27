//
//  Localization.swift
//  Cueflow (随读)
//
//  Lightweight in-code localization with runtime language switching.
//  Default language is Simplified Chinese. SwiftUI views observe
//  `LocalizationManager.shared`; AppKit surfaces rebuild on the
//  `.appLanguageDidChange` notification.
//

import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case zhHans = "zh-Hans"
    case en = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }
}

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("CueflowAppLanguageDidChange")
}

/// Localization keys. Raw values double as the en fallback is NOT used;
/// English text lives in the table below for clarity.
enum LK: String {
    // Status-bar menu
    case menuStart, menuPause, menuResetScroll, menuJumpBack
    case menuPrivacyMode, menuShowOverlay, menuIncreaseSpeed, menuDecreaseSpeed
    case menuToggleWindowMode, menuScriptEditor, menuSettings, menuCheckUpdates, menuQuit
    case menuShortcutUnavailableOne, menuShortcutsUnavailableN, menuInUseByOther

    // Edit menu
    case editMenu, editUndo, editRedo, editCut, editCopy, editPaste, editSelectAll

    // Overlay right-click + buttons
    case ctxPaste, ctxClear
    case ovStartAutoScroll, ovPauseSwitchManual, ovJumpBack5
    case ovPasteScript, ovClearScript, ovDecreaseSpeed, ovIncreaseSpeed, ovQuit
    case ovVoiceStart, ovVoiceStop, ovEditScript
    case ovCueStart, ovCueStop

    // Scrolling empty/ready states + default script
    case scrollEmpty, scrollReady, defaultScript

    // Settings — sections & fields
    case setTitle, setSubtitle
    case secLanguage, fieldLanguage
    case secPlayback, fieldSpeed, fieldScrollMode, scrollModeInfinite, scrollModeStopAtEnd
    case fieldCountdown, countdownAlways, countdownFreshStart, countdownNever, fieldCountdownDuration
    case secAppearance, fieldFontSize, fieldOverlayWidth, fieldOverlayHeight
    case secWindow, fieldDisplayMode, displayModeNotch, displayModeFloating, toggleAdaptiveFont
    case secDisplay, fieldShowOverlayOn, displayAutoBuiltin
    case secPrivacy, toggleShowOverlay, toggleLimitCapture, privacyBestEffort
    case secShortcuts
    case scStartPause, scResetScroll, scJumpBack, scTogglePrivacy, scToggleOverlay, scIncreaseSpeed, scDecreaseSpeed

    // Window titles
    case winSettingsTitle, winScriptEditorTitle

    // Script editor
    case edImport, edExport, edEstimatedReadTime, edFileOpFailed, edOK, edFileOpFailedMsg

    // File panels
    case panelImport, panelImportMsg, panelExport, panelExportMsg

    // Script library
    case libScripts, libNewScript, libDelete, libUseInPrompter, libTitle, libUntitled, libEmpty, libSearch
    case libCurrent, libSaveToLibrary, libSavedRecords

    // Voice follow (F3 beta)
    case menuVoiceFollowTest, vfWindowTitle, vfStart, vfStop, vfLanguage, vfHeard, vfHint
    case vfNoScript, vfPermissionDenied, vfUnavailable, vfListening, vfReady, vfOnDevice, vfReloadScript
    case vfLangZh, vfLangEn, vfEnableDictationHint, vfLangMixed

    // Voice engine setting
    case secVoiceEngine, fieldVoiceEngine, veAuto, veAppleZh, veAppleEn, veWhisperMixed
    case fieldVoiceNotchHeight

    // F5 随讲（cue card）
    case menuCueMode, scEnterCue, scNextPoint, scPrevPoint
    case cueNoOutlineHint, cueEnterHint, cueSectionNoMaterial, cueNextPoint, cueLastPoint
    case scOverview, scJumpPoint, cueOverviewTitle, cueOverviewHint, scCueScroll

    // F5 脚本库切换
    case menuScriptsEmpty, scNextScript, scPrevScript

    // F5 随讲设置
    case secCue, fieldCueNotchHeight, toggleCueTotalTimer
    case scCuePager, scSpeedKeys

    // F5 随讲录入（模板 / 语法提示 / 列表徽章）
    case libNewBlank, libNewCue, libCueTemplateTitle, libCueTemplateBody
    case cueSyntaxHint, badgeCue, badgeRead

    // F5 空格暂停
    case toggleSpacePause, scSpacePause

    // F6 设置中心 — 分类导航
    case catGeneral, catPrompting, catAppearance, catVoice, catPrivacy, catShortcuts

    // F6 动效
    case secMotion, fieldMotionStyle, motionStandard, motionBrisk, motionMinimal, motionReduceHint

    // F6 实时预览 / 显示模式可视卡
    case previewTitle, previewSample, displayNotchDesc, displayFloatingDesc

    // F6 计时器
    case secTimer, fieldTimerMode, timerOff, timerCountUp, timerCountDown, timerRemaining
    case fieldTimerTarget, timerReachedTarget, timerRemainNeedStopMode

    // F6 排练统计
    case menuStats, winStatsTitle, statsTitle, statsSubtitle
    case statsThisSession, statsDuration, statsWords, statsAvgSpeed, statsCompletion, statsWordsPerMin
    case statsTotals, statsTotalSessions, statsTotalTime, statsRecent, statsScript
    case statsEmpty, statsClear, statsClearConfirmTitle, statsClearConfirmMsg, statsCancel
    case toggleStatsEnabled, toggleShowSummary, summaryTitle, summaryDismiss
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    private static let defaultsKey = "appLanguage"

    @Published var language: AppLanguage {
        didSet {
            guard oldValue != language else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey)
            NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
            objectWillChange.send()
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let lang = AppLanguage(rawValue: raw) {
            language = lang
        } else {
            language = .zhHans // 默认简体中文
        }
    }

    func l(_ key: LK) -> String {
        let entry = Self.table[key]
        return entry?[language] ?? entry?[.en] ?? key.rawValue
    }

    /// Convenience for `String(format:)` localized strings.
    func l(_ key: LK, _ args: CVarArg...) -> String {
        String(format: l(key), arguments: args)
    }
}

/// Global convenience for non-view contexts (controllers, AppDelegate).
@MainActor
func L(_ key: LK) -> String { LocalizationManager.shared.l(key) }

@MainActor
func L(_ key: LK, _ args: CVarArg...) -> String {
    String(format: LocalizationManager.shared.l(key), arguments: args)
}

extension LocalizationManager {
    static let table: [LK: [AppLanguage: String]] = [
        // MARK: Menu
        .menuStart: [.zhHans: "开始", .en: "Start"],
        .menuPause: [.zhHans: "暂停", .en: "Pause"],
        .menuResetScroll: [.zhHans: "重置滚动", .en: "Reset Scroll"],
        .menuJumpBack: [.zhHans: "回退 5 秒", .en: "Jump Back 5s"],
        .menuPrivacyMode: [.zhHans: "隐私模式", .en: "Privacy Mode"],
        .menuShowOverlay: [.zhHans: "显示提词窗口", .en: "Show Overlay"],
        .menuIncreaseSpeed: [.zhHans: "加速", .en: "Increase Speed"],
        .menuDecreaseSpeed: [.zhHans: "减速", .en: "Decrease Speed"],
        .menuToggleWindowMode: [.zhHans: "切换窗口形态（刘海/独立）", .en: "Toggle Window Mode"],
        .menuScriptEditor: [.zhHans: "脚本编辑器…", .en: "Script Editor…"],
        .menuSettings: [.zhHans: "设置…", .en: "Settings…"],
        .menuCheckUpdates: [.zhHans: "检查更新…", .en: "Check for Updates…"],
        .menuQuit: [.zhHans: "退出 随读", .en: "Quit Cueflow"],
        .menuShortcutUnavailableOne: [.zhHans: "快捷键不可用：%@（被其他应用占用）", .en: "Shortcut unavailable: %@ (in use by another app)"],
        .menuShortcutsUnavailableN: [.zhHans: "有快捷键不可用（%d 个）", .en: "Shortcuts unavailable (%d)"],
        .menuInUseByOther: [.zhHans: "被其他应用占用：%@", .en: "In use by another app: %@"],

        // MARK: Edit menu
        .editMenu: [.zhHans: "编辑", .en: "Edit"],
        .editUndo: [.zhHans: "撤销", .en: "Undo"],
        .editRedo: [.zhHans: "重做", .en: "Redo"],
        .editCut: [.zhHans: "剪切", .en: "Cut"],
        .editCopy: [.zhHans: "复制", .en: "Copy"],
        .editPaste: [.zhHans: "粘贴", .en: "Paste"],
        .editSelectAll: [.zhHans: "全选", .en: "Select All"],

        // MARK: Overlay
        .ctxPaste: [.zhHans: "粘贴", .en: "Paste"],
        .ctxClear: [.zhHans: "清空", .en: "Clear"],
        .ovStartAutoScroll: [.zhHans: "开始自动滚动", .en: "Start auto scroll"],
        .ovPauseSwitchManual: [.zhHans: "暂停并切换为触控板手动滚动", .en: "Pause and switch to manual trackpad scroll"],
        .ovJumpBack5: [.zhHans: "回退 5 秒", .en: "Jump back 5 seconds"],
        .ovPasteScript: [.zhHans: "从剪贴板粘贴脚本", .en: "Paste script from clipboard"],
        .ovClearScript: [.zhHans: "清空脚本", .en: "Clear script"],
        .ovDecreaseSpeed: [.zhHans: "减速", .en: "Decrease speed"],
        .ovIncreaseSpeed: [.zhHans: "加速", .en: "Increase speed"],
        .ovQuit: [.zhHans: "退出 随读", .en: "Quit Cueflow"],
        .ovVoiceStart: [.zhHans: "语音跟随（中文）", .en: "Voice follow (Chinese)"],
        .ovVoiceStop: [.zhHans: "停止语音跟随", .en: "Stop voice follow"],
        .ovCueStart: [.zhHans: "进入随讲（提纲卡）", .en: "Enter cue mode (outline cards)"],
        .ovCueStop: [.zhHans: "退出随讲", .en: "Exit cue mode"],
        .ovEditScript: [.zhHans: "编辑稿件", .en: "Edit script"],

        // MARK: Scrolling states
        .scrollEmpty: [.zhHans: "还没有脚本。\n打开设置粘贴你的脚本即可开始。", .en: "No script yet.\nOpen Settings and paste your script to begin."],
        .scrollReady: [.zhHans: "准备就绪。\n按“开始”进入倒计时。", .en: "Ready to prompt.\nPress Start to begin countdown."],
        .defaultScript: [
            .zhHans: "在这里粘贴你的稿件。\n\n提示：用菜单栏图标或快捷键开始/暂停、重置滚动。",
            .en: "Paste your script here.\n\nTip: Use the menu bar icon to start/pause or reset the scroll."
        ],

        // MARK: Settings
        .setTitle: [.zhHans: "设置", .en: "Settings"],
        .setSubtitle: [.zhHans: "配置提词窗口的播放、外观与显示行为。", .en: "Configure playback, appearance, and display behavior for the overlay."],
        .secLanguage: [.zhHans: "语言", .en: "Language"],
        .fieldLanguage: [.zhHans: "界面语言", .en: "Interface language"],
        .secPlayback: [.zhHans: "播放", .en: "Playback"],
        .fieldSpeed: [.zhHans: "速度", .en: "Speed"],
        .fieldScrollMode: [.zhHans: "滚动模式", .en: "Scroll mode"],
        .scrollModeInfinite: [.zhHans: "循环", .en: "Infinite"],
        .scrollModeStopAtEnd: [.zhHans: "到底停止", .en: "Stop at end"],
        .fieldCountdown: [.zhHans: "倒计时", .en: "Countdown"],
        .countdownAlways: [.zhHans: "总是", .en: "Always"],
        .countdownFreshStart: [.zhHans: "仅从头开始时", .en: "Fresh start only"],
        .countdownNever: [.zhHans: "从不", .en: "Never"],
        .fieldCountdownDuration: [.zhHans: "倒计时时长", .en: "Countdown duration"],
        .secAppearance: [.zhHans: "外观", .en: "Appearance"],
        .fieldFontSize: [.zhHans: "字号", .en: "Font size"],
        .fieldOverlayWidth: [.zhHans: "窗口宽度", .en: "Overlay width"],
        .fieldOverlayHeight: [.zhHans: "窗口高度", .en: "Overlay height"],
        .secWindow: [.zhHans: "窗口形态", .en: "Window"],
        .fieldDisplayMode: [.zhHans: "显示形态", .en: "Display mode"],
        .displayModeNotch: [.zhHans: "刘海", .en: "Notch"],
        .displayModeFloating: [.zhHans: "独立窗口", .en: "Floating window"],
        .toggleAdaptiveFont: [.zhHans: "字号随窗口自适应", .en: "Auto-fit font to window size"],
        .secDisplay: [.zhHans: "显示", .en: "Display"],
        .fieldShowOverlayOn: [.zhHans: "在此屏幕显示", .en: "Show overlay on"],
        .displayAutoBuiltin: [.zhHans: "自动（内置屏）", .en: "Auto (Built-in)"],
        .secPrivacy: [.zhHans: "隐私", .en: "Privacy"],
        .toggleShowOverlay: [.zhHans: "显示提词窗口", .en: "Show overlay"],
        .toggleLimitCapture: [.zhHans: "屏幕共享时隐藏窗口", .en: "Limit screen sharing capture"],
        .privacyBestEffort: [.zhHans: "尽力而为，不同录屏/会议软件表现可能不同。", .en: "Best effort only. Capture behavior can vary by app."],
        .secShortcuts: [.zhHans: "键盘快捷键", .en: "Keyboard Shortcuts"],
        .scStartPause: [.zhHans: "开始 / 暂停", .en: "Start / Pause"],
        .scResetScroll: [.zhHans: "重置滚动", .en: "Reset scroll"],
        .scJumpBack: [.zhHans: "回退 5 秒", .en: "Jump back 5 seconds"],
        .scTogglePrivacy: [.zhHans: "切换隐私模式", .en: "Toggle privacy mode"],
        .scToggleOverlay: [.zhHans: "显示 / 隐藏提词窗口", .en: "Toggle overlay visibility"],
        .scIncreaseSpeed: [.zhHans: "加速", .en: "Increase speed"],
        .scDecreaseSpeed: [.zhHans: "减速", .en: "Decrease speed"],

        // MARK: Window titles
        .winSettingsTitle: [.zhHans: "随读 · 设置", .en: "Cueflow Settings"],
        .winScriptEditorTitle: [.zhHans: "随读 · 脚本编辑器", .en: "Cueflow Script Editor"],

        // MARK: Script editor
        .edImport: [.zhHans: "导入…", .en: "Import..."],
        .edExport: [.zhHans: "导出…", .en: "Export..."],
        .edEstimatedReadTime: [.zhHans: "预计朗读时长：%@", .en: "Estimated read time: %@"],
        .edFileOpFailed: [.zhHans: "文件操作失败", .en: "File Operation Failed"],
        .edOK: [.zhHans: "好", .en: "OK"],
        .edFileOpFailedMsg: [.zhHans: "无法完成此文件操作。", .en: "This file operation could not be completed."],

        // MARK: File panels
        .panelImport: [.zhHans: "导入", .en: "Import"],
        .panelImportMsg: [.zhHans: "选择一个脚本文件，随读会尝试从常见文档格式中提取文本。", .en: "Choose a script file. Cueflow will try to extract text from common document formats."],
        .panelExport: [.zhHans: "导出", .en: "Export"],
        .panelExportMsg: [.zhHans: "导出为 TXT、MD、RTF、DOCX 或 ODT。", .en: "Export as TXT, MD, RTF, DOCX, or ODT."],

        // MARK: Script library
        .libScripts: [.zhHans: "脚本库", .en: "Scripts"],
        .libNewScript: [.zhHans: "新建脚本", .en: "New script"],
        .libDelete: [.zhHans: "删除", .en: "Delete"],
        .libUseInPrompter: [.zhHans: "用于提词", .en: "Use in prompter"],
        .libTitle: [.zhHans: "标题", .en: "Title"],
        .libUntitled: [.zhHans: "未命名脚本", .en: "Untitled script"],
        .libEmpty: [.zhHans: "还没有保存的脚本。编辑左侧“当前提词内容”后点“保存到脚本库”，或点“导入”。", .en: "No saved scripts yet. Edit “Current” then “Save to library”, or Import."],
        .libSearch: [.zhHans: "搜索脚本", .en: "Search scripts"],
        .libCurrent: [.zhHans: "当前提词内容", .en: "Current prompter text"],
        .libSaveToLibrary: [.zhHans: "保存到脚本库", .en: "Save to library"],
        .libSavedRecords: [.zhHans: "已保存的脚本", .en: "Saved scripts"],

        // MARK: Voice follow (F3 beta)
        .menuVoiceFollowTest: [.zhHans: "语音跟随（测试）…", .en: "Voice Follow (Beta)…"],
        .vfWindowTitle: [.zhHans: "随读 · 语音跟随（测试）", .en: "Cueflow · Voice Follow (Beta)"],
        .vfStart: [.zhHans: "开始聆听", .en: "Start listening"],
        .vfStop: [.zhHans: "停止", .en: "Stop"],
        .vfLanguage: [.zhHans: "识别语言", .en: "Language"],
        .vfHeard: [.zhHans: "识别到", .en: "Heard"],
        .vfHint: [.zhHans: "选好识别语言，点“开始聆听”，对着麦克风朗读上方稿件——高亮会跟着你走、自动滚动。这是用于验证跟随效果的测试版。", .en: "Pick a language, click Start, and read the script above aloud — the highlight follows you and auto-scrolls. This is a beta to validate tracking."],
        .vfNoScript: [.zhHans: "还没有稿件。请先在提词器粘贴/导入，或在脚本编辑器编辑。", .en: "No script yet. Paste/import in the prompter, or edit in the Script editor."],
        .vfPermissionDenied: [.zhHans: "麦克风或语音识别权限被拒绝。请在“系统设置 → 隐私与安全性”里开启后重试。", .en: "Microphone or Speech Recognition permission was denied. Enable it in System Settings → Privacy & Security, then retry."],
        .vfUnavailable: [.zhHans: "该语言的语音识别暂不可用。", .en: "Speech recognition is unavailable for this language."],
        .vfListening: [.zhHans: "聆听中…", .en: "Listening…"],
        .vfReady: [.zhHans: "就绪", .en: "Ready"],
        .vfOnDevice: [.zhHans: "本机识别（离线）", .en: "On-device (offline)"],
        .vfReloadScript: [.zhHans: "载入当前提词稿", .en: "Load current script"],
        .vfLangZh: [.zhHans: "中文", .en: "Chinese"],
        .vfLangEn: [.zhHans: "英文", .en: "English"],
        .vfLangMixed: [.zhHans: "中英混读(本地)", .en: "Mixed zh+en (local)"],

        // MARK: Voice engine setting
        .secVoiceEngine: [.zhHans: "语音跟随", .en: "Voice follow"],
        .fieldVoiceEngine: [.zhHans: "识别引擎", .en: "Recognition engine"],
        .veAuto: [.zhHans: "自动（推荐）", .en: "Auto (recommended)"],
        .veAppleZh: [.zhHans: "系统识别·中文", .en: "System·Chinese"],
        .veAppleEn: [.zhHans: "系统识别·英文", .en: "System·English"],
        .veWhisperMixed: [.zhHans: "本地·中英混读(WhisperKit·实验)", .en: "Local·Mixed zh+en (WhisperKit, beta)"],
        .fieldVoiceNotchHeight: [.zhHans: "语音跟随刘海高度", .en: "Notch height (voice follow)"],
        .vfEnableDictationHint: [
            .zhHans: "提示：当前用云端识别，延迟较高。到「系统设置 → 键盘 → 听写」开启对应语言的听写并等其下载完成，即可用本机离线识别、延迟大幅降低。",
            .en: "Tip: using server recognition (higher latency). Enable Dictation for this language in System Settings → Keyboard → Dictation and let it download to get fast on-device recognition."
        ],

        // MARK: F5 随讲（cue card）
        .menuCueMode: [.zhHans: "随讲模式（提纲卡）", .en: "Cue Mode (Outline Cards)"],
        .scEnterCue: [.zhHans: "进入 / 退出随讲", .en: "Enter / exit cue mode"],
        .scNextPoint: [.zhHans: "下一个大纲点", .en: "Next outline point"],
        .scPrevPoint: [.zhHans: "上一个大纲点", .en: "Previous outline point"],
        .scOverview: [.zhHans: "总览（鸟瞰大纲）", .en: "Overview (outline map)"],
        .scJumpPoint: [.zhHans: "跳到第 N 点（随讲时按 1–9）", .en: "Jump to point N (press 1–9 in cue mode)"],
        .scCueScroll: [.zhHans: "点内翻看弹药（随讲时 ↑↓）", .en: "Scroll materials in a point (↑↓ in cue mode)"],
        .cueNoOutlineHint: [
            .zhHans: "这份脚本还没有大纲点。\n用 ## 加一个标题即可使用随讲。",
            .en: "This script has no outline points.\nAdd a heading with ## to use cue mode."
        ],
        .cueEnterHint: [
            .zhHans: "这是随讲脚本（没有逐字台词）。\n按 ⌥⌘G 进入随讲模式查看大纲与素材。",
            .en: "This is a cue script (no read-aloud lines).\nPress ⌥⌘G to enter cue mode."
        ],
        .cueSectionNoMaterial: [.zhHans: "（本点无素材）", .en: "(no materials)"],
        .cueNextPoint: [.zhHans: "下一点 ▸ %@", .en: "Next ▸ %@"],
        .cueLastPoint: [.zhHans: "最后一点 · 准备收尾", .en: "Last point · wrap up"],
        .cueOverviewTitle: [.zhHans: "总览 · 共 %d 点", .en: "Overview · %d points"],
        .cueOverviewHint: [.zhHans: "按 1–9 跳到对应点 · ⌥⌘L 返回", .en: "Press 1–9 to jump · ⌥⌘L to return"],

        // MARK: F5 脚本库切换
        .menuScriptsEmpty: [.zhHans: "（脚本库为空）", .en: "(library is empty)"],
        .scNextScript: [.zhHans: "下一条脚本", .en: "Next script"],
        .scPrevScript: [.zhHans: "上一条脚本", .en: "Previous script"],

        // MARK: F5 随讲设置
        .secCue: [.zhHans: "随讲", .en: "Cue mode"],
        .fieldCueNotchHeight: [.zhHans: "随讲刘海高度", .en: "Notch height (cue mode)"],
        .toggleCueTotalTimer: [.zhHans: "显示全场累计用时", .en: "Show total elapsed time"],
        .scCuePager: [.zhHans: "随讲翻点（单手 / 翻页笔，仅随讲时）", .en: "Cue paging (one hand / clicker, cue mode only)"],
        .scSpeedKeys: [.zhHans: "加速 / 减速（自动滚动播放时）", .en: "Speed up / down (while auto-scroll plays)"],

        // MARK: F5 随讲录入
        .libNewBlank: [.zhHans: "空白脚本", .en: "Blank script"],
        .libNewCue: [.zhHans: "随讲模板（提纲卡）", .en: "Cue template (outline)"],
        .libCueTemplateTitle: [.zhHans: "随讲示例", .en: "Cue example"],
        .libCueTemplateBody: [
            .zhHans: """
## 开场：一句话主题 [2:00]
> 必讲：最关键的数据 / 案例 / 金句
>? 可选：有时间再展开的内容

## 第二部分：标题 [3:00]
> 必讲：要点一
> 必讲：要点二
>? 可选：备用素材

## 收尾：行动号召 [1:00]
> 必讲：让观众记住的一句话
""",
            .en: """
## Opening: one-line theme [2:00]
> Must-say: key data / case / quote
>? Optional: expand if there's time

## Part two: title [3:00]
> Must-say: point one
> Must-say: point two
>? Optional: backup material

## Closing: call to action [1:00]
> Must-say: the one line they should remember
"""
        ],
        .cueSyntaxHint: [
            .zhHans: "随讲语法：  ## 标题   ·   > 必讲   ·   >? 可选   ·   [2:00] 时长   （写了 ## 才能进随讲）",
            .en: "Cue syntax:  ## title  ·  > must-say  ·  >? optional  ·  [2:00] budget  (needs ## to use cue mode)"
        ],
        .badgeCue: [.zhHans: "随讲", .en: "Cue"],
        .badgeRead: [.zhHans: "随读", .en: "Read"],

        // MARK: F5 空格暂停
        .toggleSpacePause: [.zhHans: "用空格暂停 / 继续（播放自动滚动时）", .en: "Space to pause / resume (while auto-scroll plays)"],
        .scSpacePause: [.zhHans: "暂停 / 继续（自动滚动会话中）", .en: "Pause / resume (during a scroll session)"],

        // MARK: F6 设置中心分类
        .catGeneral: [.zhHans: "通用", .en: "General"],
        .catPrompting: [.zhHans: "提词", .en: "Prompting"],
        .catAppearance: [.zhHans: "外观", .en: "Appearance"],
        .catVoice: [.zhHans: "语音", .en: "Voice"],
        .catPrivacy: [.zhHans: "隐私", .en: "Privacy"],
        .catShortcuts: [.zhHans: "快捷键", .en: "Shortcuts"],

        // MARK: F6 动效
        .secMotion: [.zhHans: "动效", .en: "Motion"],
        .fieldMotionStyle: [.zhHans: "动画风格", .en: "Animation style"],
        .motionStandard: [.zhHans: "标准", .en: "Standard"],
        .motionBrisk: [.zhHans: "轻快", .en: "Brisk"],
        .motionMinimal: [.zhHans: "极简（几乎无动画）", .en: "Minimal (almost none)"],
        .motionReduceHint: [
            .zhHans: "系统开启「减弱动态效果」时将自动使用极简动画。",
            .en: "Minimal animations are used automatically when system Reduce Motion is on."
        ],

        // MARK: F6 预览 / 显示模式卡
        .previewTitle: [.zhHans: "实时预览", .en: "Live preview"],
        .previewSample: [
            .zhHans: "这是一段示例提词文本，用来预览字号与窗口比例。",
            .en: "Sample prompter text to preview font size and window proportions."
        ],
        .displayNotchDesc: [.zhHans: "贴合刘海，录屏友好", .en: "Hugs the notch, capture-friendly"],
        .displayFloatingDesc: [.zhHans: "可自由拖动的独立窗口", .en: "Free-floating, draggable window"],

        // MARK: F6 计时器
        .secTimer: [.zhHans: "计时器", .en: "Timer"],
        .fieldTimerMode: [.zhHans: "计时方式", .en: "Timer mode"],
        .timerOff: [.zhHans: "关闭", .en: "Off"],
        .timerCountUp: [.zhHans: "正计时（已用时）", .en: "Count up (elapsed)"],
        .timerCountDown: [.zhHans: "倒计时（到目标）", .en: "Count down (to target)"],
        .timerRemaining: [.zhHans: "预计剩余", .en: "Estimated remaining"],
        .fieldTimerTarget: [.zhHans: "倒计时目标", .en: "Countdown target"],
        .timerReachedTarget: [.zhHans: "时间到", .en: "Time's up"],
        .timerRemainNeedStopMode: [
            .zhHans: "「预计剩余」需配合「到底停止」滚动模式。",
            .en: "“Estimated remaining” works with the “Stop at end” scroll mode."
        ],

        // MARK: F6 排练统计
        .menuStats: [.zhHans: "排练统计…", .en: "Rehearsal Stats…"],
        .winStatsTitle: [.zhHans: "随读 · 排练统计", .en: "Cueflow · Rehearsal Stats"],
        .statsTitle: [.zhHans: "排练统计", .en: "Rehearsal Stats"],
        .statsSubtitle: [.zhHans: "你的练习记录都保存在本机，不会上传。", .en: "Your practice records stay on this Mac and are never uploaded."],
        .statsThisSession: [.zhHans: "最近一次", .en: "Latest session"],
        .statsDuration: [.zhHans: "时长", .en: "Duration"],
        .statsWords: [.zhHans: "字数", .en: "Words"],
        .statsAvgSpeed: [.zhHans: "平均语速", .en: "Avg. pace"],
        .statsCompletion: [.zhHans: "完成度", .en: "Completion"],
        .statsWordsPerMin: [.zhHans: "字/分", .en: "wpm"],
        .statsTotals: [.zhHans: "累计", .en: "Totals"],
        .statsTotalSessions: [.zhHans: "练习次数", .en: "Sessions"],
        .statsTotalTime: [.zhHans: "累计时长", .en: "Total time"],
        .statsRecent: [.zhHans: "最近记录", .en: "Recent sessions"],
        .statsScript: [.zhHans: "脚本", .en: "Script"],
        .statsEmpty: [.zhHans: "还没有练习记录。开始一次提词，结束后就会出现在这里。", .en: "No records yet. Start prompting; sessions appear here when you finish."],
        .statsClear: [.zhHans: "清空统计", .en: "Clear stats"],
        .statsClearConfirmTitle: [.zhHans: "清空全部统计记录？", .en: "Clear all stats?"],
        .statsClearConfirmMsg: [.zhHans: "此操作不可撤销。", .en: "This cannot be undone."],
        .statsCancel: [.zhHans: "取消", .en: "Cancel"],
        .toggleStatsEnabled: [.zhHans: "记录排练统计", .en: "Record rehearsal stats"],
        .toggleShowSummary: [.zhHans: "结束后显示本次小结", .en: "Show session summary when finished"],
        .summaryTitle: [.zhHans: "本次小结", .en: "Session summary"],
        .summaryDismiss: [.zhHans: "好", .en: "OK"],
    ]
}
