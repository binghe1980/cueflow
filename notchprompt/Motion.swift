//
//  Motion.swift
//  Cueflow (随读)
//
//  F6-E: Centralized animation definitions. All app animations reference these
//  so timing/curves stay consistent and a single "motion style" + the system
//  "Reduce Motion" setting can globally tune or disable them. Independently
//  authored; no third-party code.
//

import SwiftUI
import AppKit

enum Motion {
    /// Whether the system "Reduce Motion" accessibility setting is on.
    static var systemReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// The effective style after honouring system Reduce Motion (which always wins).
    static func effectiveStyle(_ style: PrompterModel.MotionStyle) -> PrompterModel.MotionStyle {
        systemReduceMotion ? .minimal : style
    }

    /// The base animation for a given style. `.minimal` returns nil (no animation).
    static func resolved(_ style: PrompterModel.MotionStyle) -> Animation? {
        switch effectiveStyle(style) {
        case .standard: return .spring(response: 0.38, dampingFraction: 0.82)
        case .brisk:    return .spring(response: 0.24, dampingFraction: 0.9)
        case .minimal:  return nil
        }
    }

    /// Convenience that reads the current model style on the main actor.
    @MainActor static var current: Animation? {
        resolved(PrompterModel.shared.motionStyle)
    }

    /// Expand/collapse animation (notch / panels).
    @MainActor static var expand: Animation? { current }

    /// Card / control selection feedback.
    static let cardSelect: Animation = .spring(response: 0.28, dampingFraction: 0.85)

    /// A transition for cards/HUDs floating in and out (scale + fade).
    @MainActor static var cardTransition: AnyTransition {
        if effectiveStyle(PrompterModel.shared.motionStyle) == .minimal {
            return .opacity
        }
        return .scale(scale: 0.94).combined(with: .opacity)
    }
}

/// Shared time formatting for timer / stats (mm:ss or h:mm:ss).
enum TimeFormat {
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    static func clock(_ interval: TimeInterval) -> String {
        clock(Int(interval.rounded()))
    }
}
