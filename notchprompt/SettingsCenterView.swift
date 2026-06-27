//
//  SettingsCenterView.swift
//  Cueflow (随读)
//
//  F6: Visualized settings center. Replaces the single long scroll (ContentView)
//  with a sidebar + grouped-card layout (NavigationSplitView). All controls bind
//  to the same PrompterModel / LocalizationManager state as before — pure UI
//  reorganization plus the new F6 sections (motion, timer, stats, live preview).
//
//  Note: independently authored. Inspired in spirit by other notch apps' settings
//  UX, but contains no third-party (GPL) code.
//

import SwiftUI
import AppKit
import CoreGraphics

// MARK: - Category model

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general, prompting, appearance, voice, privacy, shortcuts

    var id: String { rawValue }

    var titleKey: LK {
        switch self {
        case .general:   return .catGeneral
        case .prompting: return .catPrompting
        case .appearance: return .catAppearance
        case .voice:     return .catVoice
        case .privacy:   return .catPrivacy
        case .shortcuts: return .catShortcuts
        }
    }

    var symbol: String {
        switch self {
        case .general:   return "gearshape"
        case .prompting: return "text.alignleft"
        case .appearance: return "paintpalette"
        case .voice:     return "waveform"
        case .privacy:   return "lock.shield"
        case .shortcuts: return "command"
        }
    }
}

// MARK: - Root

struct SettingsCenterView: View {
    @ObservedObject private var lm = LocalizationManager.shared
    @State private var selection: SettingsCategory? = .general

    var body: some View {
        // Custom two-pane layout (sidebar + divider + detail) instead of
        // NavigationSplitView — the latter injects a sidebar-toggle button and a
        // titlebar separator line into a bare NSWindow, which showed as a stray
        // line that shifted on resize. A plain HStack has no such chrome.
        HStack(spacing: 0) {
            List(SettingsCategory.allCases, selection: $selection) { category in
                Label(lm.l(category.titleKey), systemImage: category.symbol)
                    .tag(category)
            }
            .listStyle(.sidebar)
            .frame(width: 188)

            Divider()

            ScrollView {
                detailContent
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection ?? .general {
        case .general:   GeneralSettingsView()
        case .prompting: PromptingSettingsView()
        case .appearance: AppearanceSettingsView()
        case .voice:     VoiceSettingsView()
        case .privacy:   PrivacySettingsView()
        case .shortcuts: ShortcutsSettingsView()
        }
    }
}

// MARK: - Shared building blocks

/// A titled grouped card used across all categories.
struct SCCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// A page header (large title + subtitle) shown at the top of each category.
struct SCHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.weight(.semibold))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }
}

private let scLabelWidth: CGFloat = 150
private let scValueWidth: CGFloat = 56

/// A labelled slider row with a trailing live value.
struct SCSliderRow<S: View>: View {
    let title: String
    let valueText: String
    @ViewBuilder var slider: S
    var body: some View {
        HStack {
            Text(title).frame(width: scLabelWidth, alignment: .leading)
            slider
            Text(valueText)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: scValueWidth, alignment: .trailing)
        }
    }
}

/// A labelled row hosting an arbitrary trailing control (picker, etc.).
struct SCRow<C: View>: View {
    let title: String
    @ViewBuilder var control: C
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).frame(width: scLabelWidth, alignment: .leading)
            control
            Spacer(minLength: 0)
        }
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @ObservedObject private var model = PrompterModel.shared
    @ObservedObject private var lm = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SCHeader(title: lm.l(.catGeneral), subtitle: lm.l(.setSubtitle))

            SCCard(title: lm.l(.secLanguage)) {
                SCRow(title: lm.l(.fieldLanguage)) {
                    Picker("", selection: $lm.language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
            }

            SCCard(title: lm.l(.secWindow)) {
                DisplayModeCards(selection: $model.displayMode)
                Toggle(lm.l(.toggleAdaptiveFont), isOn: $model.adaptiveFontSize)
            }

            SCCard(title: lm.l(.secDisplay)) {
                SCRow(title: lm.l(.fieldShowOverlayOn)) {
                    Picker("", selection: $model.selectedScreenID) {
                        Text(lm.l(.displayAutoBuiltin)).tag(CGDirectDisplayID(0))
                        ForEach(NSScreen.screens, id: \.self) { screen in
                            Text(screen.localizedName).tag(screenID(for: screen))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 280)
                }
            }
        }
    }

    private func screenID(for screen: NSScreen) -> CGDirectDisplayID {
        guard let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return 0 }
        return CGDirectDisplayID(n.uint32Value)
    }
}

// MARK: - Prompting

struct PromptingSettingsView: View {
    @ObservedObject private var model = PrompterModel.shared
    @ObservedObject private var lm = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SCHeader(title: lm.l(.catPrompting), subtitle: lm.l(.setSubtitle))

            SCCard(title: lm.l(.secPlayback)) {
                SCSliderRow(title: lm.l(.fieldSpeed), valueText: "\(Int(model.speedPointsPerSecond))") {
                    Slider(value: $model.speedPointsPerSecond, in: 10...300, step: 5)
                }
                Toggle(lm.l(.toggleSpacePause), isOn: $model.spacePauseEnabled)
                SCRow(title: lm.l(.fieldScrollMode)) {
                    Picker("", selection: Binding(get: { model.scrollMode }, set: { model.setScrollMode($0) })) {
                        Text(lm.l(.scrollModeInfinite)).tag(PrompterModel.ScrollMode.infinite)
                        Text(lm.l(.scrollModeStopAtEnd)).tag(PrompterModel.ScrollMode.stopAtEnd)
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(maxWidth: 240)
                }
                SCRow(title: lm.l(.fieldCountdown)) {
                    Picker("", selection: $model.countdownBehavior) {
                        ForEach(PrompterModel.CountdownBehavior.allCases, id: \.self) { b in
                            Text(countdownLabel(b)).tag(b)
                        }
                    }
                    .labelsHidden().pickerStyle(.menu).frame(maxWidth: 200)
                }
                SCSliderRow(title: lm.l(.fieldCountdownDuration), valueText: "\(model.countdownSeconds)s") {
                    Slider(value: Binding(get: { Double(model.countdownSeconds) },
                                          set: { model.countdownSeconds = Int($0.rounded()) }),
                           in: 0...10, step: 1)
                    .disabled(model.countdownBehavior == .never)
                }
            }

            TimerSettingsCard()

            SCCard(title: lm.l(.secCue)) {
                SCSliderRow(title: lm.l(.fieldCueNotchHeight), valueText: "\(Int(model.cueNotchHeight))") {
                    Slider(value: $model.cueNotchHeight, in: 180...600, step: 10)
                }
                Toggle(lm.l(.toggleCueTotalTimer), isOn: $model.showCueTotalTimer)
            }

            SCCard(title: lm.l(.secGesture)) {
                Toggle(lm.l(.toggleGestureControl), isOn: $model.gestureControlEnabled)
                Text(lm.l(.gestureHint)).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func countdownLabel(_ behavior: PrompterModel.CountdownBehavior) -> String {
        switch behavior {
        case .always: return lm.l(.countdownAlways)
        case .freshStartOnly: return lm.l(.countdownFreshStart)
        case .never: return lm.l(.countdownNever)
        }
    }
}

// MARK: - Appearance

struct AppearanceSettingsView: View {
    @ObservedObject private var model = PrompterModel.shared
    @ObservedObject private var lm = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SCHeader(title: lm.l(.catAppearance), subtitle: lm.l(.setSubtitle))

            SCCard(title: lm.l(.previewTitle)) {
                SettingsLivePreview()
            }

            SCCard(title: lm.l(.secAppearance)) {
                SCSliderRow(title: lm.l(.fieldFontSize), valueText: "\(Int(model.fontSize))") {
                    Slider(value: $model.fontSize, in: 12...40, step: 1)
                }
                SCSliderRow(title: lm.l(.fieldOverlayWidth), valueText: "\(Int(model.overlayWidth))") {
                    Slider(value: $model.overlayWidth, in: 400...1200, step: 10)
                }
                SCSliderRow(title: lm.l(.fieldOverlayHeight), valueText: "\(Int(model.overlayHeight))") {
                    Slider(value: $model.overlayHeight, in: 120...300, step: 2)
                }
            }

            SCCard(title: lm.l(.secMotion)) {
                SCRow(title: lm.l(.fieldMotionStyle)) {
                    Picker("", selection: $model.motionStyle) {
                        Text(lm.l(.motionStandard)).tag(PrompterModel.MotionStyle.standard)
                        Text(lm.l(.motionBrisk)).tag(PrompterModel.MotionStyle.brisk)
                        Text(lm.l(.motionMinimal)).tag(PrompterModel.MotionStyle.minimal)
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(maxWidth: 320)
                }
                Text(lm.l(.motionReduceHint)).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Voice

struct VoiceSettingsView: View {
    @ObservedObject private var model = PrompterModel.shared
    @ObservedObject private var lm = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SCHeader(title: lm.l(.catVoice), subtitle: lm.l(.setSubtitle))
            SCCard(title: lm.l(.secVoiceEngine)) {
                SCRow(title: lm.l(.fieldVoiceEngine)) {
                    Picker("", selection: $model.voiceEngine) {
                        Text(lm.l(.veAuto)).tag(PrompterModel.VoiceEngine.auto)
                        Text(lm.l(.veAppleZh)).tag(PrompterModel.VoiceEngine.appleZh)
                        Text(lm.l(.veAppleEn)).tag(PrompterModel.VoiceEngine.appleEn)
                        Text(lm.l(.veWhisperMixed)).tag(PrompterModel.VoiceEngine.whisperMixed)
                    }
                    .labelsHidden().pickerStyle(.menu).frame(maxWidth: 320)
                }
                SCSliderRow(title: lm.l(.fieldVoiceNotchHeight), valueText: "\(Int(model.voiceFollowNotchHeight))") {
                    Slider(value: $model.voiceFollowNotchHeight, in: 180...600, step: 10)
                }
            }
        }
    }
}

// MARK: - Privacy

struct PrivacySettingsView: View {
    @ObservedObject private var model = PrompterModel.shared
    @ObservedObject private var lm = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SCHeader(title: lm.l(.catPrivacy), subtitle: lm.l(.setSubtitle))
            SCCard(title: lm.l(.secPrivacy)) {
                Toggle(lm.l(.toggleShowOverlay), isOn: $model.isOverlayVisible)
                Toggle(lm.l(.toggleLimitCapture), isOn: $model.privacyModeEnabled)
                Text(lm.l(.privacyBestEffort)).font(.footnote).foregroundStyle(.secondary)
            }
            SCCard(title: lm.l(.statsTitle)) {
                Toggle(lm.l(.toggleStatsEnabled), isOn: $model.statsEnabled)
                Toggle(lm.l(.toggleShowSummary), isOn: $model.showSessionSummary)
                    .disabled(!model.statsEnabled)
            }
        }
    }
}

// MARK: - Shortcuts

struct ShortcutsSettingsView: View {
    @ObservedObject private var lm = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SCHeader(title: lm.l(.catShortcuts), subtitle: lm.l(.setSubtitle))
            SCCard(title: lm.l(.secShortcuts)) {
                row("⌥⌘P", lm.l(.scStartPause))
                row("⌥⌘R", lm.l(.scResetScroll))
                row("⌥⌘J", lm.l(.scJumpBack))
                row("⌥⌘H", lm.l(.scTogglePrivacy))
                row("⌥⌘O", lm.l(.scToggleOverlay))
                row("⌥⌘=", lm.l(.scIncreaseSpeed))
                row("⌥⌘-", lm.l(.scDecreaseSpeed))
                Divider()
                row("Space", lm.l(.scSpacePause))
                row("↑↓", lm.l(.scSpeedKeys))
                Divider()
                row("⌥⌘G", lm.l(.scEnterCue))
                row("⌥⌘.", lm.l(.scNextPoint))
                row("⌥⌘,", lm.l(.scPrevPoint))
                row("⌥⌘L", lm.l(.scOverview))
                row("1–9", lm.l(.scJumpPoint))
                row("←→ ⇞⇟", lm.l(.scCuePager))
                row("↑↓", lm.l(.scCueScroll))
                Divider()
                row("⌥⌘]", lm.l(.scNextScript))
                row("⌥⌘[", lm.l(.scPrevScript))
            }
        }
    }

    private func row(_ keys: String, _ action: String) -> some View {
        HStack(spacing: 12) {
            Text(keys)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            Text(action).font(.subheadline)
            Spacer(minLength: 0)
        }
    }
}
