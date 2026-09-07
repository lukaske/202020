import Foundation

/// All user-facing settings, backed by UserDefaults.
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "enabled"
        static let workInterval = "workIntervalSeconds"
        static let breakDuration = "breakDurationSeconds"
        static let dimOpacity = "dimOpacity"
        static let soundEnabled = "soundEnabled"
        static let soundVolume = "soundVolume"
        static let showCountdownInMenuBar = "showCountdownInMenuBar"
        static let idleReset = "idleResetSeconds"
    }

    private init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.workInterval: 20 * 60,
            Key.breakDuration: 20,
            Key.dimOpacity: 0.96,
            Key.soundEnabled: true,
            Key.soundVolume: 1.0,
            Key.showCountdownInMenuBar: false,
            // If there was no keyboard/mouse activity for this long, the eyes have
            // already had their rest: skip the break and restart the cycle.
            Key.idleReset: 120,
        ])
    }

    var enabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    /// Seconds of work between breaks.
    var workInterval: TimeInterval {
        get { defaults.double(forKey: Key.workInterval) }
        set { defaults.set(newValue, forKey: Key.workInterval) }
    }

    /// Seconds a break lasts.
    var breakDuration: TimeInterval {
        get { defaults.double(forKey: Key.breakDuration) }
        set { defaults.set(newValue, forKey: Key.breakDuration) }
    }

    /// 0...1 — how much of the screen the overlay hides.
    var dimOpacity: Double {
        get { min(1, max(0.3, defaults.double(forKey: Key.dimOpacity))) }
        set { defaults.set(newValue, forKey: Key.dimOpacity) }
    }

    var soundEnabled: Bool {
        get { defaults.bool(forKey: Key.soundEnabled) }
        set { defaults.set(newValue, forKey: Key.soundEnabled) }
    }

    /// 0...1 — the position of the volume slider, not an amplitude. Loudness is
    /// derived from it in `Chime`, because a linear amplitude slider spends most
    /// of its travel in the top of the range and feels wrong under the finger.
    var soundVolume: Double {
        get { min(1, max(0, defaults.double(forKey: Key.soundVolume))) }
        set { defaults.set(min(1, max(0, newValue)), forKey: Key.soundVolume) }
    }

    var showCountdownInMenuBar: Bool {
        get { defaults.bool(forKey: Key.showCountdownInMenuBar) }
        set { defaults.set(newValue, forKey: Key.showCountdownInMenuBar) }
    }

    var idleReset: TimeInterval {
        get { defaults.double(forKey: Key.idleReset) }
        set { defaults.set(newValue, forKey: Key.idleReset) }
    }
}
