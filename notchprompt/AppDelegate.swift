//
//  AppDelegate.swift
//  Cueflow (随读)
//
//  Created by Saif on 2026-02-08. Rebranded & extended for Cueflow.
//

import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    static let cueflowOpenScriptEditor = Notification.Name("CueflowOpenScriptEditor")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, NSMenuDelegate {
    private let shortcutModifiers: NSEvent.ModifierFlags = [.command, .option]

    private let model = PrompterModel.shared

    private var statusItem: NSStatusItem?
    private var overlayController: OverlayWindowController?
    private var floatingController: FloatingWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var scriptEditorWindowController: ScriptEditorWindowController?
    private var voiceFollowWindowController: VoiceFollowWindowController?
    private var cancellables: Set<AnyCancellable> = []
    private var languageObserver: NSObjectProtocol?
    private var editorObserver: NSObjectProtocol?

    private var startPauseItem: NSMenuItem?
    private var showOverlayItem: NSMenuItem?
    private var privacyModeItem: NSMenuItem?
    private var windowModeItem: NSMenuItem?
    private var cueModeItem: NSMenuItem?
    private weak var scriptsSubmenu: NSMenu?
    private var speedUpItem: NSMenuItem?
    private var speedDownItem: NSMenuItem?
    private var shortcutWarningItem: NSMenuItem?
    private var shortcutWarningDetailItem: NSMenuItem?
    private var shortcutWarningSeparator: NSMenuItem?

    private lazy var hotkeyManager = GlobalHotkeyManager(
        onCommand: { [weak self] command in self?.performShortcut(command) },
        onJumpToIndex: { [weak self] index in self?.model.cueJumpToSection(index) },
        onCueScroll: { [weak self] delta in self?.model.cueScrollMaterials(delta) }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isFirstRun = !UserDefaults.standard.bool(forKey: "hasSavedSession")
        model.loadFromDefaults()
        if isFirstRun {
            model.script = L(.defaultScript)
        }

        overlayController = OverlayWindowController(model: model)
        floatingController = FloatingWindowController(model: model)
        applyWindowConfiguration()

#if DEBUG
        ScreenSelectionSelfTests.run()
        runShortcutSelfChecks()
#endif

        setupEditMenu()
        wireModel()
        hotkeyManager.registerAll()
        setupStatusBar()
        installEditKeyHandler()

        languageObserver = NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildStatusMenu() }
        }

        editorObserver = NotificationCenter.default.addObserver(
            forName: .cueflowOpenScriptEditor, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.openScriptEditorWindow() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.saveToDefaults()
        hotkeyManager.unregisterAll()
        cancellables.removeAll()
        if let languageObserver { NotificationCenter.default.removeObserver(languageObserver) }
        if let editorObserver { NotificationCenter.default.removeObserver(editorObserver) }
    }

    // MARK: - Window configuration (notch vs floating, mutually exclusive)

    private func applyWindowConfiguration() {
        let wantFloating = (model.displayMode == .floating)
        let visible = model.isOverlayVisible
        overlayController?.setVisible(visible && !wantFloating)
        floatingController?.setVisible(visible && wantFloating)
        overlayController?.setPrivacyMode(model.privacyModeEnabled)
        floatingController?.setPrivacyMode(model.privacyModeEnabled)
    }

    private func wireModel() {
        model.$privacyModeEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.overlayController?.setPrivacyMode(enabled)
                self?.floatingController?.setPrivacyMode(enabled)
            }
            .store(in: &cancellables)

        model.$isOverlayVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyWindowConfiguration()
            }
            .store(in: &cancellables)

        model.$displayMode
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyWindowConfiguration()
            }
            .store(in: &cancellables)

        // Resize the notch panel when voice-follow toggles (grows for read-ahead room).
        VoiceFollowController.shared.$isListening
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.overlayController?.reposition()
                self?.updateSpacePauseKey()
            }
            .store(in: &cancellables)

        // Live-resize the notch as the voice-follow height setting is dragged.
        model.$voiceFollowNotchHeight
            .removeDuplicates()
            .throttle(for: .milliseconds(16), scheduler: RunLoop.main, latest: true)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.overlayController?.reposition()
            }
            .store(in: &cancellables)

        // Grow/shrink the notch and toggle single-key cue navigation when
        // entering/leaving 随讲 (cue) mode.
        model.$readingMode
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in
                // Entering 随讲 (by hotkey, button, or auto on a pure-outline
                // script) stops voice-follow so the mic doesn't keep running.
                if mode == .cue { VoiceFollowController.shared.stop() }
                self?.overlayController?.reposition()
                self?.hotkeyManager.setCueNavigationActive(mode == .cue)
                self?.updateSpacePauseKey()
            }
            .store(in: &cancellables)

        // Enable ↑↓ speed control only while auto-scroll is actively playing.
        model.$isRunning
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] running in
                self?.hotkeyManager.setSpeedNavigationActive(running)
            }
            .store(in: &cancellables)

        // Enable the Space play/pause key only during a scroll session (and only
        // while not editing — see updateSpacePauseKey()).
        model.$scrollSessionActive
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateSpacePauseKey() }
            .store(in: &cancellables)

        model.$spacePauseEnabled
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateSpacePauseKey() }
            .store(in: &cancellables)

        // Release the Space key whenever this app comes to the front (so spaces
        // typed in the editor / settings are never swallowed), re-arm when it
        // resigns (presenting in another app).
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .merge(with: NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateSpacePauseKey() }
            .store(in: &cancellables)

        // Live-resize the notch as the 随讲 height setting is dragged.
        model.$cueNotchHeight
            .removeDuplicates()
            .throttle(for: .milliseconds(16), scheduler: RunLoop.main, latest: true)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.overlayController?.reposition()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(model.$overlayWidth, model.$overlayHeight)
            .removeDuplicates { lhs, rhs in
                Int(lhs.0) == Int(rhs.0) && Int(lhs.1) == Int(rhs.1)
            }
            .throttle(for: .milliseconds(16), scheduler: RunLoop.main, latest: true)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.overlayController?.reposition()
            }
            .store(in: &cancellables)

        model.$selectedScreenID
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.overlayController?.reposition()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.overlayController?.reposition()
            }
            .store(in: &cancellables)

        // Persist on any settings change (array form keeps the type-checker fast).
        let saveTriggers: [AnyPublisher<Void, Never>] = [
            model.$script.map { _ in () }.eraseToAnyPublisher(),
            model.$isRunning.map { _ in () }.eraseToAnyPublisher(),
            model.$privacyModeEnabled.map { _ in () }.eraseToAnyPublisher(),
            model.$speedPointsPerSecond.map { _ in () }.eraseToAnyPublisher(),
            model.$fontSize.map { _ in () }.eraseToAnyPublisher(),
            model.$overlayWidth.map { _ in () }.eraseToAnyPublisher(),
            model.$overlayHeight.map { _ in () }.eraseToAnyPublisher(),
            model.$countdownSeconds.map { _ in () }.eraseToAnyPublisher(),
            model.$countdownBehavior.map { _ in () }.eraseToAnyPublisher(),
            model.$scrollMode.map { _ in () }.eraseToAnyPublisher(),
            model.$selectedScreenID.map { _ in () }.eraseToAnyPublisher(),
            model.$displayMode.map { _ in () }.eraseToAnyPublisher(),
            model.$adaptiveFontSize.map { _ in () }.eraseToAnyPublisher(),
            model.$floatingWidth.map { _ in () }.eraseToAnyPublisher(),
            model.$floatingHeight.map { _ in () }.eraseToAnyPublisher(),
            model.$floatingOriginX.map { _ in () }.eraseToAnyPublisher(),
            model.$floatingOriginY.map { _ in () }.eraseToAnyPublisher(),
            model.$voiceEngine.map { _ in () }.eraseToAnyPublisher(),
            model.$voiceFollowNotchHeight.map { _ in () }.eraseToAnyPublisher(),
            model.$activeScriptID.map { _ in () }.eraseToAnyPublisher(),
            model.$cueNotchHeight.map { _ in () }.eraseToAnyPublisher(),
            model.$showCueTotalTimer.map { _ in () }.eraseToAnyPublisher(),
            model.$spacePauseEnabled.map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(saveTriggers)
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.model.saveToDefaults()
            }
            .store(in: &cancellables)
    }

    private func setupEditMenu() {
        let editMenu = NSMenu(title: L(.editMenu))
        editMenu.addItem(withTitle: L(.editUndo), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L(.editRedo), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L(.editCut), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L(.editCopy), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L(.editPaste), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L(.editSelectAll), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editMenuItem = NSMenuItem(title: L(.editMenu), action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu

        if let mainMenu = NSApp.mainMenu {
            mainMenu.addItem(editMenuItem)
        } else {
            let mainMenu = NSMenu()
            mainMenu.addItem(editMenuItem)
            NSApp.mainMenu = mainMenu
        }
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()

        let startPause = NSMenuItem(title: L(.menuStart), action: #selector(toggleRunning), keyEquivalent: ShortcutCommand.startPause.keyEquivalent)
        startPause.target = self
        startPause.keyEquivalentModifierMask = shortcutModifiers
        menu.addItem(startPause)
        startPauseItem = startPause

        let reset = NSMenuItem(title: L(.menuResetScroll), action: #selector(resetScroll), keyEquivalent: ShortcutCommand.reset.keyEquivalent)
        reset.target = self
        reset.keyEquivalentModifierMask = shortcutModifiers
        menu.addItem(reset)

        let jumpBack = NSMenuItem(title: L(.menuJumpBack), action: #selector(jumpBack), keyEquivalent: ShortcutCommand.jumpBack.keyEquivalent)
        jumpBack.target = self
        jumpBack.keyEquivalentModifierMask = shortcutModifiers
        menu.addItem(jumpBack)

        let privacyMode = NSMenuItem(title: L(.menuPrivacyMode), action: #selector(togglePrivacyMode), keyEquivalent: ShortcutCommand.togglePrivacy.keyEquivalent)
        privacyMode.target = self
        privacyMode.keyEquivalentModifierMask = shortcutModifiers
        menu.addItem(privacyMode)
        privacyModeItem = privacyMode

        let showOverlay = NSMenuItem(title: L(.menuShowOverlay), action: #selector(toggleOverlayVisibility), keyEquivalent: ShortcutCommand.toggleOverlay.keyEquivalent)
        showOverlay.target = self
        showOverlay.keyEquivalentModifierMask = shortcutModifiers
        menu.addItem(showOverlay)
        showOverlayItem = showOverlay

        let windowMode = NSMenuItem(title: L(.menuToggleWindowMode), action: #selector(toggleWindowMode), keyEquivalent: "")
        windowMode.target = self
        menu.addItem(windowMode)
        windowModeItem = windowMode

        let cueMode = NSMenuItem(title: L(.menuCueMode), action: #selector(toggleCueMode), keyEquivalent: ShortcutCommand.cueToggle.keyEquivalent)
        cueMode.target = self
        cueMode.keyEquivalentModifierMask = shortcutModifiers
        menu.addItem(cueMode)
        cueModeItem = cueMode

        let speedUp = NSMenuItem(title: L(.menuIncreaseSpeed), action: #selector(increaseSpeed), keyEquivalent: ShortcutCommand.speedUp.keyEquivalent)
        speedUp.target = self
        speedUp.keyEquivalentModifierMask = shortcutModifiers
        menu.addItem(speedUp)
        speedUpItem = speedUp

        let speedDown = NSMenuItem(title: L(.menuDecreaseSpeed), action: #selector(decreaseSpeed), keyEquivalent: ShortcutCommand.speedDown.keyEquivalent)
        speedDown.target = self
        speedDown.keyEquivalentModifierMask = shortcutModifiers
        menu.addItem(speedDown)
        speedDownItem = speedDown

        refreshShortcutWarningItems(in: menu)

        menu.addItem(.separator())

        let scripts = NSMenuItem(title: L(.libScripts), action: nil, keyEquivalent: "")
        let scriptsMenu = NSMenu()
        scriptsMenu.delegate = self
        scripts.submenu = scriptsMenu
        menu.addItem(scripts)
        scriptsSubmenu = scriptsMenu

        let openScriptEditor = NSMenuItem(title: L(.menuScriptEditor), action: #selector(openScriptEditorWindow), keyEquivalent: "")
        openScriptEditor.target = self
        menu.addItem(openScriptEditor)

        let voiceFollow = NSMenuItem(title: L(.menuVoiceFollowTest), action: #selector(openVoiceFollowTest), keyEquivalent: "")
        voiceFollow.target = self
        menu.addItem(voiceFollow)

        menu.addItem(.separator())

        let open = NSMenuItem(title: L(.menuSettings), action: #selector(openMainWindow), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: L(.menuQuit), action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        quit.keyEquivalentModifierMask = [.command]
        menu.addItem(quit)

        return menu
    }

    private func setupStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "Cueflow") {
            item.button?.image = image
        } else {
            item.button?.title = "随读"
        }
        item.button?.toolTip = "随读 Cueflow"
        item.menu = buildStatusMenu()
        statusItem = item
    }

    private func rebuildStatusMenu() {
        // Warning items live inside the menu we're about to replace; drop refs.
        shortcutWarningItem = nil
        shortcutWarningDetailItem = nil
        shortcutWarningSeparator = nil
        statusItem?.menu = buildStatusMenu()
    }

    // MARK: - Edit key handler (Cmd+C/V/X/A/Z bypass for menu-bar apps)

    private func installEditKeyHandler() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command ||
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .shift] else {
                return event
            }
            let key = event.charactersIgnoringModifiers ?? ""
            let action: Selector? = switch key {
            case "x": #selector(NSText.cut(_:))
            case "c": #selector(NSText.copy(_:))
            case "v": #selector(NSText.paste(_:))
            case "a": #selector(NSText.selectAll(_:))
            case "z" where event.modifierFlags.contains(.shift): NSSelectorFromString("redo:")
            case "z": NSSelectorFromString("undo:")
            default: nil
            }
            if let action, NSApp.sendAction(action, to: nil, from: nil) {
                return nil
            }
            return event
        }
    }

    // MARK: - Actions

    @objc private func toggleRunning() { model.toggleRunning() }
    @objc private func resetScroll() { model.resetScroll() }
    @objc private func jumpBack() { model.jumpBack(seconds: 5) }
    @objc private func togglePrivacyMode() { model.privacyModeEnabled.toggle() }
    @objc private func toggleOverlayVisibility() { model.isOverlayVisible.toggle() }
    @objc private func increaseSpeed() { model.adjustSpeed(delta: PrompterModel.speedStep) }
    @objc private func decreaseSpeed() { model.adjustSpeed(delta: -PrompterModel.speedStep) }

    @objc private func toggleWindowMode() {
        model.displayMode = (model.displayMode == .notch) ? .floating : .notch
    }

    @objc private func toggleCueMode() {
        // Entering 随讲 stops voice-follow so the mic doesn't keep running.
        if model.readingMode != .cue { VoiceFollowController.shared.stop() }
        model.toggleCueMode()
    }

    @objc private func selectScript(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let id = UUID(uuidString: raw) else { return }
        model.loadLibraryScript(id)
    }

    // MARK: - NSMenuDelegate (scripts submenu, populated lazily on open)

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === scriptsSubmenu else { return }
        menu.removeAllItems()

        let items = ScriptLibrary.shared.items
        if items.isEmpty {
            let empty = NSMenuItem(title: L(.menuScriptsEmpty), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for item in items {
                let title = item.title.isEmpty ? L(.libUntitled) : item.title
                let mi = NSMenuItem(title: title, action: #selector(selectScript(_:)), keyEquivalent: "")
                mi.target = self
                mi.representedObject = item.id.uuidString
                mi.state = (model.activeScriptID == item.id) ? .on : .off
                menu.addItem(mi)
            }
        }

        menu.addItem(.separator())
        let openEditor = NSMenuItem(title: L(.menuScriptEditor), action: #selector(openScriptEditorWindow), keyEquivalent: "")
        openEditor.target = self
        menu.addItem(openEditor)
    }

    @objc private func openMainWindow() {
        Task { @MainActor in
            if settingsWindowController == nil {
                settingsWindowController = SettingsWindowController()
            }
            settingsWindowController?.show()
        }
    }

    @objc private func openScriptEditorWindow() {
        Task { @MainActor in
            if scriptEditorWindowController == nil {
                scriptEditorWindowController = ScriptEditorWindowController()
            }
            scriptEditorWindowController?.show()
        }
    }

    @objc private func openVoiceFollowTest() {
        Task { @MainActor in
            if voiceFollowWindowController == nil {
                voiceFollowWindowController = VoiceFollowWindowController()
            }
            voiceFollowWindowController?.show()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    /// Space toggles play/pause, but only when it's both useful and safe:
    /// during an active scroll session, in normal (non-cue) mode, not while
    /// voice-following, the feature is on, and this app isn't frontmost (so it
    /// never intercepts spaces typed in the editor / settings windows).
    private func updateSpacePauseKey() {
        let active = model.spacePauseEnabled
            && model.scrollSessionActive
            && model.readingMode == .normal
            && !VoiceFollowController.shared.isListening
            && !NSApp.isActive
        hotkeyManager.setPlayPauseKeyActive(active)
    }

    private func performShortcut(_ command: ShortcutCommand) {
        switch command {
        case .startPause:
            model.toggleRunning()
        case .reset:
            model.resetScroll()
        case .jumpBack:
            model.jumpBack(seconds: 5)
        case .togglePrivacy:
            model.privacyModeEnabled.toggle()
        case .toggleOverlay:
            model.isOverlayVisible.toggle()
        case .speedUp:
            model.adjustSpeed(delta: PrompterModel.speedStep)
        case .speedDown:
            model.adjustSpeed(delta: -PrompterModel.speedStep)
        case .cueToggle:
            if model.readingMode != .cue { VoiceFollowController.shared.stop() }
            model.toggleCueMode()
        case .cueNext:
            model.cueNextSection()
        case .cuePrev:
            model.cuePrevSection()
        case .cueOverview:
            model.toggleCueOverview()
        case .scriptNext:
            model.activateAdjacentScript(forward: true)
        case .scriptPrev:
            model.activateAdjacentScript(forward: false)
        }
    }

    private func refreshShortcutWarningItems(in menu: NSMenu) {
        if let shortcutWarningItem {
            menu.removeItem(shortcutWarningItem)
            self.shortcutWarningItem = nil
        }
        if let shortcutWarningDetailItem {
            menu.removeItem(shortcutWarningDetailItem)
            self.shortcutWarningDetailItem = nil
        }
        if let shortcutWarningSeparator {
            menu.removeItem(shortcutWarningSeparator)
            self.shortcutWarningSeparator = nil
        }

        let unavailable = hotkeyManager.failedRegistrations
        guard !unavailable.isEmpty else { return }

        if unavailable.count == 1, let first = unavailable.first {
            let warning = NSMenuItem(title: L(.menuShortcutUnavailableOne, first.displayShortcut), action: nil, keyEquivalent: "")
            warning.isEnabled = false
            menu.insertItem(warning, at: 0)
            shortcutWarningItem = warning
        } else {
            let warning = NSMenuItem(title: L(.menuShortcutsUnavailableN, unavailable.count), action: nil, keyEquivalent: "")
            warning.isEnabled = false
            menu.insertItem(warning, at: 0)
            shortcutWarningItem = warning

            let detail = unavailable.map(\.displayShortcut).joined(separator: ", ")
            let detailItem = NSMenuItem(title: L(.menuInUseByOther, detail), action: nil, keyEquivalent: "")
            detailItem.isEnabled = false
            menu.insertItem(detailItem, at: 1)
            shortcutWarningDetailItem = detailItem
        }

        let separator = NSMenuItem.separator()
        menu.insertItem(separator, at: unavailable.count == 1 ? 1 : 2)
        shortcutWarningSeparator = separator
    }

#if DEBUG
    private func runShortcutSelfChecks() {
        GlobalHotkeyManager.runSelfChecks()
    }
#endif

    // MARK: - Menu Validation

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem === startPauseItem {
            menuItem.title = model.isRunning ? L(.menuPause) : L(.menuStart)
            return true
        }
        if menuItem === privacyModeItem {
            menuItem.state = model.privacyModeEnabled ? .on : .off
            return true
        }
        if menuItem === showOverlayItem {
            menuItem.state = model.isOverlayVisible ? .on : .off
            return true
        }
        if menuItem === windowModeItem {
            menuItem.state = (model.displayMode == .floating) ? .on : .off
            return true
        }
        if menuItem === cueModeItem {
            menuItem.state = (model.readingMode == .cue) ? .on : .off
            return true
        }
        if menuItem === speedUpItem || menuItem === speedDownItem {
            return true
        }
        return true
    }
}
