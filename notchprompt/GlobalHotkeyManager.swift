import AppKit
import Carbon
import Foundation

enum ShortcutCommand: CaseIterable {
    case startPause
    case reset
    case jumpBack
    case togglePrivacy
    case toggleOverlay
    case speedUp
    case speedDown
    // F5 随讲（cue card）
    case cueToggle
    case cueNext
    case cuePrev
    case cueOverview
    // F5 脚本库：循环切换激活脚本
    case scriptNext
    case scriptPrev

    var keyEquivalent: String {
        switch self {
        case .startPause:
            return "p"
        case .reset:
            return "r"
        case .jumpBack:
            return "j"
        case .togglePrivacy:
            return "h"
        case .toggleOverlay:
            return "o"
        case .speedUp:
            return "="
        case .speedDown:
            return "-"
        case .cueToggle:
            return "g"
        case .cueNext:
            return "."
        case .cuePrev:
            return ","
        case .cueOverview:
            return "l"
        case .scriptNext:
            return "]"
        case .scriptPrev:
            return "["
        }
    }

    var displayShortcut: String {
        switch self {
        case .startPause:
            return "⌥⌘P"
        case .reset:
            return "⌥⌘R"
        case .jumpBack:
            return "⌥⌘J"
        case .togglePrivacy:
            return "⌥⌘H"
        case .toggleOverlay:
            return "⌥⌘O"
        case .speedUp:
            return "⌥⌘="
        case .speedDown:
            return "⌥⌘-"
        case .cueToggle:
            return "⌥⌘G"
        case .cueNext:
            return "⌥⌘."
        case .cuePrev:
            return "⌥⌘,"
        case .cueOverview:
            return "⌥⌘L"
        case .scriptNext:
            return "⌥⌘]"
        case .scriptPrev:
            return "⌥⌘["
        }
    }

    fileprivate var hotKeyID: UInt32 {
        switch self {
        case .startPause:
            return 1
        case .reset:
            return 2
        case .jumpBack:
            return 3
        case .togglePrivacy:
            return 4
        case .toggleOverlay:
            return 5
        case .speedUp:
            return 6
        case .speedDown:
            return 7
        case .cueToggle:
            return 8
        case .cueNext:
            return 9
        case .cuePrev:
            return 10
        case .scriptNext:
            return 11
        case .scriptPrev:
            return 12
        case .cueOverview:
            return 13
        }
    }

    fileprivate var keyCode: UInt32 {
        switch self {
        case .startPause:
            return UInt32(kVK_ANSI_P)
        case .reset:
            return UInt32(kVK_ANSI_R)
        case .jumpBack:
            return UInt32(kVK_ANSI_J)
        case .togglePrivacy:
            return UInt32(kVK_ANSI_H)
        case .toggleOverlay:
            return UInt32(kVK_ANSI_O)
        case .speedUp:
            return UInt32(kVK_ANSI_Equal)
        case .speedDown:
            return UInt32(kVK_ANSI_Minus)
        case .cueToggle:
            return UInt32(kVK_ANSI_G)
        case .cueNext:
            return UInt32(kVK_ANSI_Period)
        case .cuePrev:
            return UInt32(kVK_ANSI_Comma)
        case .scriptNext:
            return UInt32(kVK_ANSI_RightBracket)
        case .scriptPrev:
            return UInt32(kVK_ANSI_LeftBracket)
        case .cueOverview:
            return UInt32(kVK_ANSI_L)
        }
    }

    fileprivate var carbonModifiers: UInt32 {
        UInt32(optionKey | cmdKey)
    }
}

final class GlobalHotkeyManager {
    private static let signature: OSType = 0x4E_50_48_4B // "NPHK"

    private var hotKeyRefs: [ShortcutCommand: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private let onCommand: (ShortcutCommand) -> Void
    private let onJumpToIndex: (Int) -> Void
    private let onCueScroll: (Int) -> Void

    /// Last-seen time per held hotkey id, used to collapse OS key-repeat so one
    /// physical press fires exactly once (e.g. holding ⌥⌘] no longer skips two
    /// scripts). Cleared on key release; a stale entry self-heals after 1s in
    /// case a release event is ever missed.
    private var heldSince: [UInt32: CFAbsoluteTime] = [:]
    private static let repeatGuardWindow: CFAbsoluteTime = 1.0

    /// hotKeyID -> command, covering both the always-on chords and the cue-mode
    /// single keys, so the event handler can resolve either set.
    private var commandForHotKeyID: [UInt32: ShortcutCommand] = [:]

    // Single-key cue navigation, registered ONLY while 随讲 is active so it never
    // disrupts normal typing. No modifier => one thumb / a Bluetooth presentation
    // clicker (which sends Page Up/Down or ←→) can flip outline points. ↑↓ are
    // intentionally left out here — they belong to speed control (below).
    private var cueNavRefs: [EventHotKeyRef] = []
    private var cueNavActive = false
    private static let cueNavBindings: [(keyCode: Int, id: UInt32, command: ShortcutCommand)] = [
        (kVK_PageDown, 101, .cueNext),
        (kVK_RightArrow, 102, .cueNext),
        (kVK_PageUp, 104, .cuePrev),
        (kVK_LeftArrow, 105, .cuePrev),
    ]

    // Bare number keys 1–9 jump straight to an outline point. Registered together
    // with cue navigation (cue mode only), so they never disturb normal typing.
    private var cueJumpRefs: [EventHotKeyRef] = []
    private var jumpIndexForHotKeyID: [UInt32: Int] = [:]
    private static let cueJumpBindings: [(keyCode: Int, id: UInt32, index: Int)] = [
        (kVK_ANSI_1, 111, 0), (kVK_ANSI_2, 112, 1), (kVK_ANSI_3, 113, 2),
        (kVK_ANSI_4, 114, 3), (kVK_ANSI_5, 115, 4), (kVK_ANSI_6, 116, 5),
        (kVK_ANSI_7, 117, 6), (kVK_ANSI_8, 118, 7), (kVK_ANSI_9, 119, 8),
    ]

    // ↑↓ scroll the materials WITHIN the current point (cue mode only). These keys
    // are free here because the speed-control ↑↓ are only active while auto-scroll
    // is playing — the two states never overlap.
    private var cueScrollRefs: [EventHotKeyRef] = []
    private var scrollDeltaForHotKeyID: [UInt32: Int] = [:]
    private static let cueScrollBindings: [(keyCode: Int, id: UInt32, delta: Int)] = [
        (kVK_UpArrow, 121, -1),
        (kVK_DownArrow, 122, 1),
    ]

    // Single-key speed control, registered ONLY while auto-scroll is actively
    // playing (so ↑↓ stay free for the system the rest of the time). ↑ faster,
    // ↓ slower — the moment you need a quick tweak while reading.
    private var speedNavRefs: [EventHotKeyRef] = []
    private var speedNavActive = false
    private static let speedNavBindings: [(keyCode: Int, id: UInt32, command: ShortcutCommand)] = [
        (kVK_UpArrow, 201, .speedUp),
        (kVK_DownArrow, 202, .speedDown),
    ]

    // Single-key play/pause (Space), registered ONLY during an active scroll
    // session AND while this app isn't frontmost (so it never eats spaces typed
    // in the editor / settings). Reuses the .startPause command.
    private var playPauseNavRefs: [EventHotKeyRef] = []
    private var playPauseNavActive = false
    private static let playPauseNavBindings: [(keyCode: Int, id: UInt32, command: ShortcutCommand)] = [
        (kVK_Space, 301, .startPause),
    ]

    private(set) var failedRegistrations: [ShortcutCommand] = []

    init(onCommand: @escaping (ShortcutCommand) -> Void,
         onJumpToIndex: @escaping (Int) -> Void = { _ in },
         onCueScroll: @escaping (Int) -> Void = { _ in }) {
        self.onCommand = onCommand
        self.onJumpToIndex = onJumpToIndex
        self.onCueScroll = onCueScroll
    }

    deinit {
        unregisterAll()
    }

    func registerAll() {
        unregisterAll()
        installHandlerIfNeeded()

        var failed: [ShortcutCommand] = []
        for command in ShortcutCommand.allCases {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: command.hotKeyID)
            let status = RegisterEventHotKey(
                command.keyCode,
                command.carbonModifiers,
                hotKeyID,
                GetEventDispatcherTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr, let hotKeyRef {
                hotKeyRefs[command] = hotKeyRef
                commandForHotKeyID[command.hotKeyID] = command
            } else {
                failed.append(command)
            }
        }

        failedRegistrations = failed
    }

    func unregisterAll() {
        setCueNavigationActive(false)
        setSpeedNavigationActive(false)
        setPlayPauseKeyActive(false)

        for (_, hotKeyRef) in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()
        commandForHotKeyID.removeAll()
        jumpIndexForHotKeyID.removeAll()
        scrollDeltaForHotKeyID.removeAll()
        heldSince.removeAll()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }

        failedRegistrations = []
    }

    /// Enable/disable the single-key cue navigation. Called when entering/leaving
    /// 随讲 so the keys only ever capture input while the user is presenting.
    func setCueNavigationActive(_ active: Bool) {
        guard active != cueNavActive else { return }
        cueNavActive = active
        applyDynamicBindings(Self.cueNavBindings, refs: &cueNavRefs, active: active)
        applyJumpBindings(active: active)
        applyScrollBindings(active: active)
    }

    private func applyScrollBindings(active: Bool) {
        if active {
            installHandlerIfNeeded()
            for binding in Self.cueScrollBindings {
                var ref: EventHotKeyRef?
                let hotKeyID = EventHotKeyID(signature: Self.signature, id: binding.id)
                let status = RegisterEventHotKey(
                    UInt32(binding.keyCode), 0, hotKeyID,
                    GetEventDispatcherTarget(), 0, &ref
                )
                if status == noErr, let ref {
                    cueScrollRefs.append(ref)
                    scrollDeltaForHotKeyID[binding.id] = binding.delta
                }
            }
        } else {
            for ref in cueScrollRefs { UnregisterEventHotKey(ref) }
            cueScrollRefs.removeAll()
            for binding in Self.cueScrollBindings {
                scrollDeltaForHotKeyID[binding.id] = nil
                heldSince[binding.id] = nil
            }
        }
    }

    private func applyJumpBindings(active: Bool) {
        if active {
            installHandlerIfNeeded()
            for binding in Self.cueJumpBindings {
                var ref: EventHotKeyRef?
                let hotKeyID = EventHotKeyID(signature: Self.signature, id: binding.id)
                let status = RegisterEventHotKey(
                    UInt32(binding.keyCode), 0, hotKeyID,
                    GetEventDispatcherTarget(), 0, &ref
                )
                if status == noErr, let ref {
                    cueJumpRefs.append(ref)
                    jumpIndexForHotKeyID[binding.id] = binding.index
                }
            }
        } else {
            for ref in cueJumpRefs { UnregisterEventHotKey(ref) }
            cueJumpRefs.removeAll()
            for binding in Self.cueJumpBindings {
                jumpIndexForHotKeyID[binding.id] = nil
                heldSince[binding.id] = nil
            }
        }
    }

    /// Enable/disable single-key speed control (↑↓). Called when auto-scroll
    /// starts/stops so ↑↓ stay free for the system whenever it isn't playing.
    func setSpeedNavigationActive(_ active: Bool) {
        guard active != speedNavActive else { return }
        speedNavActive = active
        applyDynamicBindings(Self.speedNavBindings, refs: &speedNavRefs, active: active)
    }

    /// Enable/disable the single-key (Space) play/pause. Gated by the app so it
    /// only captures Space during a scroll session while not editing text.
    func setPlayPauseKeyActive(_ active: Bool) {
        guard active != playPauseNavActive else { return }
        playPauseNavActive = active
        applyDynamicBindings(Self.playPauseNavBindings, refs: &playPauseNavRefs, active: active)
    }

    private func applyDynamicBindings(_ bindings: [(keyCode: Int, id: UInt32, command: ShortcutCommand)],
                                      refs: inout [EventHotKeyRef],
                                      active: Bool) {
        if active {
            installHandlerIfNeeded()
            for binding in bindings {
                var ref: EventHotKeyRef?
                let hotKeyID = EventHotKeyID(signature: Self.signature, id: binding.id)
                let status = RegisterEventHotKey(
                    UInt32(binding.keyCode),
                    0, // no modifier
                    hotKeyID,
                    GetEventDispatcherTarget(),
                    0,
                    &ref
                )
                if status == noErr, let ref {
                    refs.append(ref)
                    commandForHotKeyID[binding.id] = binding.command
                }
            }
        } else {
            for ref in refs {
                UnregisterEventHotKey(ref)
            }
            refs.removeAll()
            for binding in bindings {
                commandForHotKeyID[binding.id] = nil
                heldSince[binding.id] = nil
            }
        }
    }

    #if DEBUG
    static func runSelfChecks() {
        let commands = ShortcutCommand.allCases
        assert(Set(commands.map(\.hotKeyID)).count == commands.count, "Shortcut hotkey IDs must be unique")
        assert(Set(commands.map(\.displayShortcut)).count == commands.count, "Display shortcuts must be unique")
        for command in commands {
            assert(!command.keyEquivalent.isEmpty, "Missing keyEquivalent for \(command)")
            assert(command.carbonModifiers == UInt32(optionKey | cmdKey), "Unexpected modifiers for \(command)")
        }
    }
    #endif

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, eventRef, userData in
                guard let userData, let eventRef else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotKeyEvent(eventRef)
            },
            eventTypes.count,
            &eventTypes,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        if status != noErr {
            eventHandlerRef = nil
        }
    }

    private func handleHotKeyEvent(_ eventRef: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else { return status }
        guard hotKeyID.signature == Self.signature else { return OSStatus(eventNotHandledErr) }

        let now = CFAbsoluteTimeGetCurrent()

        // Key released: clear the held marker so the next press fires again.
        if Int(GetEventKind(eventRef)) == kEventHotKeyReleased {
            heldSince[hotKeyID.id] = nil
            return noErr
        }

        // Key pressed. If we're already holding this key (and the marker is
        // fresh), this is an OS auto-repeat — refresh the timestamp and ignore.
        if let since = heldSince[hotKeyID.id], (now - since) < Self.repeatGuardWindow {
            heldSince[hotKeyID.id] = now
            return noErr
        }

        heldSince[hotKeyID.id] = now

        if let command = commandForHotKeyID[hotKeyID.id] {
            DispatchQueue.main.async { [onCommand] in onCommand(command) }
            return noErr
        }
        if let index = jumpIndexForHotKeyID[hotKeyID.id] {
            DispatchQueue.main.async { [onJumpToIndex] in onJumpToIndex(index) }
            return noErr
        }
        if let delta = scrollDeltaForHotKeyID[hotKeyID.id] {
            DispatchQueue.main.async { [onCueScroll] in onCueScroll(delta) }
            return noErr
        }
        return OSStatus(eventNotHandledErr)
    }
}
