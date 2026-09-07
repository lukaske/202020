import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let controller = BreakController()
    private let menu = NSMenu()

    private lazy var activeIcon: NSImage? = templateIcon("eye")
    private lazy var pausedIcon: NSImage? = templateIcon("eye.slash")
    private var lastIconWasActive: Bool?
    private var lastButtonTitle = ""

    private var switchView: SwitchMenuItemView!
    private var statusLineItem: NSMenuItem!
    private var breakNowItem: NSMenuItem!
    private var muteItem: NSMenuItem!
    private var volumeView: VolumeMenuItemView!
    private var countdownItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var intervalItems: [NSMenuItem] = []
    private var durationItems: [NSMenuItem] = []
    private var dimmingItems: [NSMenuItem] = []

    private let intervalChoices: [(String, TimeInterval)] = [
        ("15 minutes", 15 * 60), ("20 minutes", 20 * 60), ("30 minutes", 30 * 60),
        ("45 minutes", 45 * 60), ("60 minutes", 60 * 60),
    ]
    private let durationChoices: [(String, TimeInterval)] = [
        ("20 seconds", 20), ("30 seconds", 30), ("45 seconds", 45), ("60 seconds", 60),
    ]
    private let dimmingChoices: [(String, Double)] = [
        ("Light", 0.70), ("Medium", 0.85), ("Heavy", 0.96), ("Full", 1.0),
    ]

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.toolTip = "20-20-20 eye breaks"

        buildMenu()
        statusItem.menu = menu

        controller.onChange = { [weak self] in self?.refresh() }
        if Preferences.shared.enabled { controller.start() }
        refresh()

        showFirstRunNoticeIfNeeded()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: - Menu construction

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        let switchItem = NSMenuItem()
        switchView = SwitchMenuItemView(title: "Eye breaks", isOn: Preferences.shared.enabled) { [weak self] isOn in
            self?.setEnabled(isOn)
        }
        switchItem.view = switchView
        menu.addItem(switchItem)

        menu.addItem(.separator())

        statusLineItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusLineItem.isEnabled = false
        menu.addItem(statusLineItem)

        breakNowItem = NSMenuItem(title: "Take a break now", action: #selector(takeBreakNow), keyEquivalent: "")
        breakNowItem.target = self
        menu.addItem(breakNowItem)

        menu.addItem(.separator())

        muteItem = NSMenuItem(title: "Mute sounds", action: #selector(toggleMute), keyEquivalent: "")
        muteItem.target = self
        menu.addItem(muteItem)

        let volumeItem = NSMenuItem()
        volumeView = VolumeMenuItemView(volume: Preferences.shared.soundVolume,
                                        enabled: Preferences.shared.soundEnabled) { [weak self] volume, preview in
            self?.setVolume(volume, preview: preview)
        }
        volumeItem.view = volumeView
        menu.addItem(volumeItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        let settings = NSMenu()
        settings.autoenablesItems = false

        settings.addItem(sectionHeader("Break every"))
        for (title, value) in intervalChoices {
            let item = NSMenuItem(title: title, action: #selector(selectInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.indentationLevel = 1
            settings.addItem(item)
            intervalItems.append(item)
        }

        settings.addItem(.separator())
        settings.addItem(sectionHeader("Break lasts"))
        for (title, value) in durationChoices {
            let item = NSMenuItem(title: title, action: #selector(selectDuration(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.indentationLevel = 1
            settings.addItem(item)
            durationItems.append(item)
        }

        settings.addItem(.separator())
        settings.addItem(sectionHeader("Screen cover"))
        for (title, value) in dimmingChoices {
            let item = NSMenuItem(title: title, action: #selector(selectDimming(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.indentationLevel = 1
            settings.addItem(item)
            dimmingItems.append(item)
        }

        settings.addItem(.separator())

        countdownItem = NSMenuItem(title: "Show countdown in menu bar", action: #selector(toggleMenuBarCountdown), keyEquivalent: "")
        countdownItem.target = self
        settings.addItem(countdownItem)

        loginItem = NSMenuItem(title: "Start at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        settings.addItem(loginItem)

        settingsItem.submenu = settings
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "About 202020", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit 202020", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func templateIcon(_ symbol: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "20-20-20 eye breaks")
        image?.isTemplate = true
        return image
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: - Refresh

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        // The "next break in m:ss" line only ticks while it can be seen.
        controller.menuIsOpen = true
        refresh()
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        controller.menuIsOpen = false
    }

    private func refresh() {
        let prefs = Preferences.shared

        let active = controller.isEnabled
        if lastIconWasActive != active {
            lastIconWasActive = active
            statusItem.button?.image = active ? activeIcon : pausedIcon
        }

        let title = controller.menuBarCountdownText.map { " \($0)" } ?? ""
        if title != lastButtonTitle {
            lastButtonTitle = title
            statusItem.button?.title = title
        }

        // Everything below is only visible with the menu open.
        guard controller.menuIsOpen || menu.highlightedItem != nil else { return }

        switch controller.state {
        case .off:
            statusLineItem.title = "Reminders are off"
        case .waiting:
            statusLineItem.title = "Next break in \(BreakController.shortTime(controller.timeUntilNextBreak))"
        case .onBreak:
            statusLineItem.title = "Break in progress"
        }

        switchView.isOn = controller.isEnabled
        breakNowItem.isEnabled = controller.state != .onBreak

        for item in intervalItems {
            item.state = (item.representedObject as? TimeInterval) == prefs.workInterval ? .on : .off
        }
        for item in durationItems {
            item.state = (item.representedObject as? TimeInterval) == prefs.breakDuration ? .on : .off
        }
        for item in dimmingItems {
            let value = item.representedObject as? Double ?? 0
            item.state = abs(value - prefs.dimOpacity) < 0.001 ? .on : .off
        }
        muteItem.state = prefs.soundEnabled ? .off : .on
        volumeView.volume = prefs.soundVolume
        volumeView.isEnabled = prefs.soundEnabled
        countdownItem.state = prefs.showCountdownInMenuBar ? .on : .off
        loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    // MARK: - Actions

    private func setEnabled(_ enabled: Bool) {
        Preferences.shared.enabled = enabled
        controller.isEnabled = enabled
        refresh()
    }

    @objc private func takeBreakNow() {
        controller.startBreakNow()
    }

    @objc private func selectInterval(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? TimeInterval else { return }
        Preferences.shared.workInterval = value
        if controller.state == .waiting { controller.scheduleNextBreak() }
        refresh()
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? TimeInterval else { return }
        Preferences.shared.breakDuration = value
        refresh()
    }

    @objc private func selectDimming(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        Preferences.shared.dimOpacity = value
        refresh()
    }

    private func setVolume(_ volume: Double, preview: Bool) {
        Preferences.shared.soundVolume = volume
        // Let go of the knob and you hear what you just chose.
        if preview { Chime.playLookBack() }
    }

    /// Silences both signals. The break itself still happens — muting the app
    /// is not the same as turning it off, which is what the switch is for.
    @objc private func toggleMute() {
        Preferences.shared.soundEnabled.toggle()
        // Play the "look back" tone when unmuting, so you hear what you get.
        if Preferences.shared.soundEnabled { Chime.playLookBack() }
        refresh()
    }

    @objc private func toggleMenuBarCountdown() {
        Preferences.shared.showCountdownInMenuBar.toggle()
        controller.preferencesChanged()
        if !Preferences.shared.showCountdownInMenuBar {
            lastButtonTitle = ""
            statusItem.button?.title = ""
        }
        refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        let wanted = !LaunchAtLogin.isEnabled
        if let error = LaunchAtLogin.set(wanted) {
            let alert = NSAlert()
            alert.messageText = "Couldn't change the login item"
            alert.informativeText = "\(error)\n\nYou can add 202020 manually under Login Items in System Settings."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                LaunchAtLogin.openLoginItemsSettings()
            }
        }
        refresh()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "202020"
        alert.informativeText = """
            Every 20 minutes, look at something about 20 feet away for 20 seconds.

            One sound tells you to look away, another tells you it's safe to look \
            back — you never have to watch the screen to know when the break is over.

            A break can be skipped by holding the button on the overlay, or by \
            holding the esc key. Skipping doesn't buy you a longer stretch \
            before the next one.
            """
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - First run

    private func showFirstRunNoticeIfNeeded() {
        let key = "hasShownFirstRunNotice"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let alert = NSAlert()
        alert.messageText = "202020 is running in the menu bar"
        alert.informativeText = """
            Look for the eye icon at the top of the screen. Every 20 minutes the \
            screen will be covered for 20 seconds so you can rest your eyes on \
            something far away — a sound will tell you when to look back.
            """
        alert.addButton(withTitle: "Start at login")
        alert.addButton(withTitle: "Not now")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            toggleLaunchAtLoginIfOff()
        }
    }

    private func toggleLaunchAtLoginIfOff() {
        guard !LaunchAtLogin.isEnabled else { return }
        toggleLaunchAtLogin()
    }
}
