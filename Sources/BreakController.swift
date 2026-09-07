import AppKit

/// Drives the 20-20-20 cycle: every 20 minutes of screen time, 20 seconds of
/// looking at something 20 feet away.
///
/// Power behaviour matters for something that runs all day on a laptop, so the
/// waiting phase costs essentially nothing: one timer scheduled directly on the
/// next break, with a large tolerance so macOS can coalesce it with other
/// wakeups. There is no per-second polling unless something is actually on
/// screen that needs to change — the open menu, or the optional menu-bar
/// countdown. When reminders are off, no timer exists at all.
final class BreakController {

    enum State {
        case off
        case waiting
        case onBreak
    }

    /// Fires whenever anything the menu displays has changed.
    var onChange: (() -> Void)?

    private(set) var state: State = .off
    private(set) var nextBreakDate = Date.distantFuture
    private(set) var breakEndDate = Date.distantFuture

    private let overlay = OverlayController()

    /// Fires the break itself (and, during a break, drives the countdown).
    private var breakTimer: Timer?
    /// Only alive while some visible text needs refreshing.
    private var displayTimer: Timer?
    private var displayInterval: TimeInterval = 0

    private var screenIsLocked = false

    /// Set by the menu so the "next break in ..." line ticks only while visible.
    var menuIsOpen = false {
        didSet { updateDisplayTimer() }
    }

    private var prefs: Preferences { .shared }

    init() {
        overlay.onSkip = { [weak self] in self?.skipBreak() }
        observeSystemEvents()
    }

    // MARK: - On/off

    var isEnabled: Bool {
        get { state != .off }
        set { newValue ? start() : stop() }
    }

    func start() {
        guard state == .off else { return }
        state = .waiting
        scheduleNextBreak()
        notifyChange()
    }

    func stop() {
        if state == .onBreak { overlay.hide() }
        state = .off
        nextBreakDate = .distantFuture
        breakEndDate = .distantFuture
        breakTimer?.invalidate()
        breakTimer = nil
        updateDisplayTimer()
        notifyChange()
    }

    /// Restart the countdown from a full work interval.
    func scheduleNextBreak() {
        guard state != .off else { return }
        state = .waiting
        nextBreakDate = Date().addingTimeInterval(prefs.workInterval)

        breakTimer?.invalidate()
        let timer = Timer(fire: nextBreakDate, interval: 0, repeats: false) { [weak self] _ in
            self?.breakTimerFired()
        }
        // A minute either way is irrelevant to eyes and lets the system batch
        // this wakeup with whatever else it was going to do.
        timer.tolerance = min(30, prefs.workInterval * 0.05)
        RunLoop.main.add(timer, forMode: .common)
        breakTimer = timer

        updateDisplayTimer()
        notifyChange()
    }

    // MARK: - Break lifecycle

    func startBreakNow() {
        guard state != .onBreak else { return }
        if state == .off { start() }
        beginBreak()
    }

    private func breakTimerFired() {
        guard state == .waiting else { return }

        if screenIsLocked {
            scheduleNextBreak()
            return
        }
        // Already staring out of the window / away from the desk: the eyes have
        // had their break, so just restart the cycle.
        if secondsSinceLastInput() >= prefs.idleReset {
            scheduleNextBreak()
            return
        }
        beginBreak()
    }

    private func beginBreak() {
        state = .onBreak
        breakEndDate = Date().addingTimeInterval(prefs.breakDuration)
        overlay.show(total: prefs.breakDuration)
        Chime.playLookAway()

        breakTimer?.invalidate()
        // 10 fps is plenty for a ring that sweeps 18 degrees a second, and it
        // only repaints a small view for the length of the break.
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.breakTick()
        }
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        breakTimer = timer

        updateDisplayTimer()
        notifyChange()
    }

    private func breakTick() {
        guard state == .onBreak else { return }
        let remaining = breakEndDate.timeIntervalSinceNow
        if remaining <= 0 {
            endBreak(completed: true)
        } else {
            overlay.update(remaining: remaining)
        }
    }

    private func endBreak(completed: Bool) {
        guard state == .onBreak else { return }
        overlay.hide()
        if completed { Chime.playLookBack() }
        breakEndDate = .distantFuture
        scheduleNextBreak()
        notifyChange()
    }

    /// Skipping is allowed, and that is all it is — the next break is scheduled
    /// exactly as if this one had been taken.
    func skipBreak() {
        endBreak(completed: false)
    }

    // MARK: - Display refresh

    /// A second timer, running only while something on screen is counting down.
    private func updateDisplayTimer() {
        let needed = state == .waiting && (menuIsOpen || prefs.showCountdownInMenuBar)
        guard needed else {
            displayTimer?.invalidate()
            displayTimer = nil
            displayInterval = 0
            return
        }

        // While the menu is open the line shows m:ss, so it needs a second-by-
        // second refresh. Otherwise the menu bar shows whole minutes and a
        // quarter-minute tick is more than enough.
        let interval: TimeInterval = menuIsOpen ? 1 : (timeUntilNextBreak > 90 ? 15 : 1)
        guard displayTimer == nil || displayInterval != interval else { return }

        displayTimer?.invalidate()
        displayInterval = interval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.notifyChange()
            self.updateDisplayTimer()
        }
        timer.tolerance = interval * 0.25
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    /// Call after a preference that affects refreshing has changed.
    func preferencesChanged() {
        updateDisplayTimer()
    }

    private func notifyChange() {
        onChange?()
    }

    // MARK: - Display text

    var timeUntilNextBreak: TimeInterval {
        max(0, nextBreakDate.timeIntervalSinceNow)
    }

    /// Compact text for the menu bar: whole minutes until the last one.
    var menuBarCountdownText: String? {
        guard state == .waiting, prefs.showCountdownInMenuBar else { return nil }
        let remaining = timeUntilNextBreak
        if remaining > 60 {
            return "\(Int((remaining / 60).rounded(.up)))m"
        }
        return "\(Int(remaining.rounded(.up)))s"
    }

    static func shortTime(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - System state

    private func secondsSinceLastInput() -> TimeInterval {
        let types: [CGEventType] = [.mouseMoved, .keyDown, .flagsChanged, .leftMouseDown,
                                    .rightMouseDown, .scrollWheel, .otherMouseDown]
        let idle = types.map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }
        return idle.min() ?? 0
    }

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification,
                     NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.handleReturnToScreen()
            }
        }
        for name in [NSWorkspace.willSleepNotification,
                     NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.handleLeaveScreen()
            }
        }

        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.screenIsLocked = true
            self?.handleLeaveScreen()
        }
        distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.screenIsLocked = false
            self?.handleReturnToScreen()
        }
    }

    /// Coming back to the machine: the eyes are rested, so start a fresh
    /// interval rather than firing a break that the sleep clock "owes".
    private func handleReturnToScreen() {
        guard state != .off else { return }
        if state == .onBreak {
            overlay.hide()
            breakEndDate = .distantFuture
        }
        scheduleNextBreak()
    }

    /// Leaving the machine (sleep, lock, fast user switch): no point showing an
    /// overlay to an empty chair, and no point ticking either.
    private func handleLeaveScreen() {
        guard state == .onBreak else { return }
        overlay.hide()
        breakEndDate = .distantFuture
        scheduleNextBreak()
    }
}
