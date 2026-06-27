//
//  SettingsExtras.swift
//  Cueflow (随读)
//
//  F6-B/C: Visual settings components used by SettingsCenterView —
//  display-mode picker cards, a live overlay preview, and the timer settings card.
//

import SwiftUI

// MARK: - Display mode visual cards (F6-B)

struct DisplayModeCards: View {
    @Binding var selection: PrompterModel.DisplayMode
    @ObservedObject private var lm = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 12) {
            card(.notch, symbol: "macbook", title: lm.l(.displayModeNotch), desc: lm.l(.displayNotchDesc))
            card(.floating, symbol: "macwindow", title: lm.l(.displayModeFloating), desc: lm.l(.displayFloatingDesc))
        }
    }

    private func card(_ mode: PrompterModel.DisplayMode, symbol: String, title: String, desc: String) -> some View {
        let selected = (selection == mode)
        return Button {
            withAnimation(Motion.cardSelect) { selection = mode }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: symbol).font(.title2)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.5))
                }
                Text(title).font(.subheadline.weight(.semibold))
                Text(desc).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.25),
                            lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Live overlay preview (F6-B)

struct SettingsLivePreview: View {
    @ObservedObject private var model = PrompterModel.shared
    @ObservedObject private var lm = LocalizationManager.shared

    var body: some View {
        let aspect = max(0.2, model.overlayHeight / max(1, model.overlayWidth))
        let previewWidth: CGFloat = 360
        let previewHeight = max(70, min(220, previewWidth * aspect))
        // Scale the real font size down into the preview box proportionally.
        let scale = previewWidth / max(1, model.overlayWidth)
        let previewFont = max(9, model.fontSize * scale * 1.6)

        return VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.black)
                Text(lm.l(.previewSample))
                    .font(.system(size: previewFont, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: previewWidth, height: previewHeight)
            .animation(Motion.resolved(model.motionStyle), value: model.fontSize)
            .animation(Motion.resolved(model.motionStyle), value: model.overlayWidth)
            .animation(Motion.resolved(model.motionStyle), value: model.overlayHeight)

            Text("\(Int(model.overlayWidth)) × \(Int(model.overlayHeight))  ·  \(Int(model.fontSize))pt")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Timer settings card (F6-C)

struct TimerSettingsCard: View {
    @ObservedObject private var model = PrompterModel.shared
    @ObservedObject private var lm = LocalizationManager.shared

    var body: some View {
        SCCard(title: lm.l(.secTimer)) {
            SCRow(title: lm.l(.fieldTimerMode)) {
                Picker("", selection: $model.timerMode) {
                    Text(lm.l(.timerOff)).tag(PrompterModel.TimerMode.off)
                    Text(lm.l(.timerCountUp)).tag(PrompterModel.TimerMode.countUp)
                    Text(lm.l(.timerCountDown)).tag(PrompterModel.TimerMode.countDown)
                    Text(lm.l(.timerRemaining)).tag(PrompterModel.TimerMode.remaining)
                }
                .labelsHidden().pickerStyle(.menu).frame(maxWidth: 220)
            }

            if model.timerMode == .countDown {
                SCSliderRow(title: lm.l(.fieldTimerTarget),
                            valueText: TimeFormat.clock(model.timerTargetSeconds)) {
                    Slider(value: Binding(get: { Double(model.timerTargetSeconds) },
                                          set: { model.timerTargetSeconds = Int($0.rounded()) }),
                           in: 5...1800, step: 5)
                }
            }

            if model.timerMode == .remaining && model.scrollMode != .stopAtEnd {
                Text(lm.l(.timerRemainNeedStopMode))
                    .font(.footnote).foregroundStyle(.orange)
            }
        }
    }
}
