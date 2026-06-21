//
//  ContentView.swift
//  Cueflow (随读)
//
//  Settings panel. Localized via LocalizationManager (runtime switchable).
//

import SwiftUI
import AppKit
import CoreGraphics

struct ContentView: View {
    @ObservedObject private var model = PrompterModel.shared
    @ObservedObject private var lm = LocalizationManager.shared

    private let rowLabelWidth: CGFloat = 164
    private let valueWidth: CGFloat = 56

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerSection
                languageSection
                windowSection
                voiceSection
                cueSection
                playbackSection
                appearanceSection
                displaySection
                privacySection
                shortcutsSection
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .modifier(ScrollBounceBehaviorModifier())
        .frame(minWidth: 620, minHeight: 460)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lm.l(.setTitle))
                .font(.title3.weight(.semibold))
            Text(lm.l(.setSubtitle))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }

    private var languageSection: some View {
        SettingsSection(title: lm.l(.secLanguage)) {
            HStack(alignment: .firstTextBaseline) {
                Text(lm.l(.fieldLanguage))
                    .frame(width: rowLabelWidth, alignment: .leading)
                Picker("", selection: $lm.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
    }

    private var windowSection: some View {
        SettingsSection(title: lm.l(.secWindow)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(lm.l(.fieldDisplayMode))
                        .frame(width: rowLabelWidth, alignment: .leading)
                    Picker("", selection: $model.displayMode) {
                        Text(lm.l(.displayModeNotch)).tag(PrompterModel.DisplayMode.notch)
                        Text(lm.l(.displayModeFloating)).tag(PrompterModel.DisplayMode.floating)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                Toggle(lm.l(.toggleAdaptiveFont), isOn: $model.adaptiveFontSize)
            }
        }
    }

    private var voiceSection: some View {
        SettingsSection(title: lm.l(.secVoiceEngine)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(lm.l(.fieldVoiceEngine))
                        .frame(width: rowLabelWidth, alignment: .leading)
                    Picker("", selection: $model.voiceEngine) {
                        Text(lm.l(.veAuto)).tag(PrompterModel.VoiceEngine.auto)
                        Text(lm.l(.veAppleZh)).tag(PrompterModel.VoiceEngine.appleZh)
                        Text(lm.l(.veAppleEn)).tag(PrompterModel.VoiceEngine.appleEn)
                        Text(lm.l(.veWhisperMixed)).tag(PrompterModel.VoiceEngine.whisperMixed)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    Spacer(minLength: 0)
                }

                sliderRow(
                    title: lm.l(.fieldVoiceNotchHeight),
                    valueText: "\(Int(model.voiceFollowNotchHeight))",
                    slider: Slider(value: $model.voiceFollowNotchHeight, in: 180...600, step: 10)
                )
            }
        }
    }

    private var cueSection: some View {
        SettingsSection(title: lm.l(.secCue)) {
            VStack(alignment: .leading, spacing: 12) {
                sliderRow(
                    title: lm.l(.fieldCueNotchHeight),
                    valueText: "\(Int(model.cueNotchHeight))",
                    slider: Slider(value: $model.cueNotchHeight, in: 180...600, step: 10)
                )
                Toggle(lm.l(.toggleCueTotalTimer), isOn: $model.showCueTotalTimer)
            }
        }
    }

    private var playbackSection: some View {
        SettingsSection(title: lm.l(.secPlayback)) {
            VStack(alignment: .leading, spacing: 12) {
                sliderRow(
                    title: lm.l(.fieldSpeed),
                    valueText: "\(Int(model.speedPointsPerSecond))",
                    slider: Slider(value: $model.speedPointsPerSecond, in: 10...300, step: 5)
                )

                Toggle(lm.l(.toggleSpacePause), isOn: $model.spacePauseEnabled)

                HStack(alignment: .firstTextBaseline) {
                    Text(lm.l(.fieldScrollMode))
                        .frame(width: rowLabelWidth, alignment: .leading)
                    Picker(
                        "",
                        selection: Binding(
                            get: { model.scrollMode },
                            set: { model.setScrollMode($0) }
                        )
                    ) {
                        Text(lm.l(.scrollModeInfinite)).tag(PrompterModel.ScrollMode.infinite)
                        Text(lm.l(.scrollModeStopAtEnd)).tag(PrompterModel.ScrollMode.stopAtEnd)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                HStack {
                    Text(lm.l(.fieldCountdown))
                        .frame(width: rowLabelWidth, alignment: .leading)
                    Picker("", selection: $model.countdownBehavior) {
                        ForEach(PrompterModel.CountdownBehavior.allCases, id: \.self) { behavior in
                            Text(countdownLabel(behavior)).tag(behavior)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    Spacer(minLength: 0)
                }

                sliderRow(
                    title: lm.l(.fieldCountdownDuration),
                    valueText: "\(model.countdownSeconds)s",
                    slider: Slider(
                        value: Binding(
                            get: { Double(model.countdownSeconds) },
                            set: { model.countdownSeconds = Int($0.rounded()) }
                        ),
                        in: 0...10,
                        step: 1
                    )
                    .disabled(model.countdownBehavior == .never)
                )
            }
        }
    }

    private var appearanceSection: some View {
        SettingsSection(title: lm.l(.secAppearance)) {
            VStack(alignment: .leading, spacing: 12) {
                sliderRow(
                    title: lm.l(.fieldFontSize),
                    valueText: "\(Int(model.fontSize))",
                    slider: Slider(value: $model.fontSize, in: 12...40, step: 1)
                )

                sliderRow(
                    title: lm.l(.fieldOverlayWidth),
                    valueText: "\(Int(model.overlayWidth))",
                    slider: Slider(value: $model.overlayWidth, in: 400...1200, step: 10)
                )

                sliderRow(
                    title: lm.l(.fieldOverlayHeight),
                    valueText: "\(Int(model.overlayHeight))",
                    slider: Slider(value: $model.overlayHeight, in: 120...300, step: 2)
                )
            }
        }
    }

    private var displaySection: some View {
        SettingsSection(title: lm.l(.secDisplay)) {
            HStack {
                Text(lm.l(.fieldShowOverlayOn))
                    .frame(width: rowLabelWidth, alignment: .leading)
                Picker("", selection: $model.selectedScreenID) {
                    Text(lm.l(.displayAutoBuiltin)).tag(CGDirectDisplayID(0))
                    ForEach(NSScreen.screens, id: \.self) { screen in
                        Text(screen.localizedName).tag(screenID(for: screen))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                Spacer(minLength: 0)
            }
        }
    }

    private var privacySection: some View {
        SettingsSection(title: lm.l(.secPrivacy)) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(lm.l(.toggleShowOverlay), isOn: $model.isOverlayVisible)
                Toggle(lm.l(.toggleLimitCapture), isOn: $model.privacyModeEnabled)
                Text(lm.l(.privacyBestEffort))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var shortcutsSection: some View {
        SettingsSection(title: lm.l(.secShortcuts)) {
            VStack(alignment: .leading, spacing: 6) {
                shortcutRow("⌥⌘P", lm.l(.scStartPause))
                shortcutRow("⌥⌘R", lm.l(.scResetScroll))
                shortcutRow("⌥⌘J", lm.l(.scJumpBack))
                shortcutRow("⌥⌘H", lm.l(.scTogglePrivacy))
                shortcutRow("⌥⌘O", lm.l(.scToggleOverlay))
                shortcutRow("⌥⌘=", lm.l(.scIncreaseSpeed))
                shortcutRow("⌥⌘-", lm.l(.scDecreaseSpeed))
                shortcutRow("Space", lm.l(.scSpacePause))
                shortcutRow("↑↓", lm.l(.scSpeedKeys))
                shortcutRow("⌥⌘G", lm.l(.scEnterCue))
                shortcutRow("⌥⌘.", lm.l(.scNextPoint))
                shortcutRow("⌥⌘,", lm.l(.scPrevPoint))
                shortcutRow("⌥⌘L", lm.l(.scOverview))
                shortcutRow("1–9", lm.l(.scJumpPoint))
                shortcutRow("←→ ⇞⇟", lm.l(.scCuePager))
                shortcutRow("↑↓", lm.l(.scCueScroll))
                shortcutRow("⌥⌘]", lm.l(.scNextScript))
                shortcutRow("⌥⌘[", lm.l(.scPrevScript))
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

    @ViewBuilder
    private func sliderRow<SliderView: View>(
        title: String,
        valueText: String,
        slider: SliderView
    ) -> some View {
        HStack {
            Text(title)
                .frame(width: rowLabelWidth, alignment: .leading)
            slider
            Text(valueText)
                .foregroundStyle(.secondary)
                .frame(width: valueWidth, alignment: .trailing)
        }
    }

    private func shortcutRow(_ keys: String, _ action: String) -> some View {
        HStack(spacing: 12) {
            Text(keys)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(action)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
    }

    private func screenID(for screen: NSScreen) -> CGDirectDisplayID {
        guard let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return 0
        }
        return CGDirectDisplayID(n.uint32Value)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        GroupBox(label: Text(title).font(.headline)) {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ScrollBounceBehaviorModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.scrollBounceBehavior(.basedOnSize)
        } else {
            content
        }
    }
}
