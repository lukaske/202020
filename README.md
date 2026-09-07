<div align="center">

<img src="assets/logo.png" width="128" alt="202020">

# 202020

**Every 20 minutes, look at something 20 feet away for 20 seconds.**

A small macOS menu bar app that makes the 20-20-20 rule hard to ignore
and easy to live with.

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-1d1d1f)](https://www.apple.com/macos/)
[![Swift 5](https://img.shields.io/badge/Swift-5-f05138)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-4c8eda)](LICENSE)
[![No dependencies](https://img.shields.io/badge/dependencies-none-4c9a68)](#building)

</div>

---

## Why

Staring at a screen all day means your eyes hold one focal distance for hours.
The 20-20-20 rule is the standard advice for that: every 20 minutes, spend 20
seconds looking at something roughly 20 feet away.

The problem with reminders is that you dismiss them. So this one covers the
screen — there is nothing to read, nothing to do, and no reason not to look out
of the window.

**And you don't have to watch it.** A soft falling chime plays when the break
starts and a brighter rising one when it ends, so you can turn your head, rest
your eyes properly, and let the sound tell you when it's safe to look back.

<div align="center">
<img src="assets/break-screen.png" width="720" alt="The break overlay: a dark sheet with a countdown ring, the words Look away, and a Hold to skip button">
</div>

## Install

**Download** the latest `202020.app.zip` from
[Releases](../../releases/latest), unzip it, and drag it to `/Applications`.

The app is signed ad-hoc rather than with a paid Apple Developer certificate, so
the first launch needs one extra step: **right-click the app → Open**, then
confirm. macOS remembers the choice. (Or `xattr -d com.apple.quarantine
/Applications/202020.app` from a terminal.)

**Or build it yourself** — it takes a couple of seconds and skips the Gatekeeper
dance entirely:

```sh
git clone https://github.com/lukaske/202020.git
cd 202020
./build.sh --install
```

Then click the eye icon → **Settings → Start at login**. Enable it *after* the
app is in its final location: macOS records where the app was when you
registered it.

## Using it

Everything lives in the menu bar icon.

| | |
|---|---|
| **Eye breaks** | The on/off switch. Off means no timers at all. |
| **Take a break now** | Start one immediately. |
| **Mute sounds** | Silences both chimes. Breaks still happen — muting isn't switching it off. |
| **Volume** | Let go of the knob and it plays the "look back" tone, so you hear what you picked. |
| **Settings** | Interval (15–60 min), break length (20–60 s), how much of the screen is covered, a menu-bar countdown, and **Start at login**. |

### Skipping

The overlay has a **Hold to skip** button, and `esc` does the same thing. Either
way it takes a deliberate second-and-a-half hold — a stray click or keypress
does nothing.

It's drawn as a plain grey outline with no fill, parked well away from the
countdown. Easy to find when you genuinely need it, easy to ignore when you
don't. Skipping doesn't buy you a longer stretch before the next break, so
there's nothing to game.

### It stays out of the way

- **Away from your desk** when a break comes due? It's dropped, not queued. Your
  eyes already got their rest, and you won't come back to a screen full of
  overlay.
- **Screen locked, display asleep, or the Mac was sleeping?** Same — and the
  clock restarts from a full interval when you come back.
- **Multiple displays** are all covered, so you can't just look at the other
  monitor.

## Battery

This runs all day on a laptop, so the waiting phase is built to cost nothing:

- One timer, **scheduled directly on the next break** — not a per-second poll.
  It carries a 30-second tolerance so macOS coalesces the wakeup with others
  instead of waking the CPU on its own.
- Per-second updates exist **only while the menu is open**.
- The optional menu-bar countdown ticks **once every 15 seconds**, switching to
  seconds only in the final minute.
- Turning the switch off invalidates every timer. The app is then inert.
- During a break the overlay repaints a **small centred view at 10 fps**, never
  the whole display — the dark background is drawn once and cached as a layer.

Measured: **0.00 seconds of CPU over 120 seconds idle**, ~44 MB resident.

## Building

Needs macOS 13+ and the Swift toolchain from the Xcode Command Line Tools
(`xcode-select --install`). No Xcode project, no package manager, no
dependencies — `build.sh` compiles the sources, lays out the bundle, draws the
icon and ad-hoc signs it.

```sh
./build.sh            # build into ./build/202020.app
./build.sh --install  # build, replace /Applications copy, relaunch
```

```
Sources/
  main.swift               entry point
  AppDelegate.swift        status item + menu
  BreakController.swift    the cycle, timers, sleep/idle handling
  OverlayController.swift  the windows, one per display
  BreakView.swift          overlay drawing + the hold-to-skip gesture
  Chime.swift              the two signals, synthesised as WAV in memory
  Preferences.swift        UserDefaults
  SwitchMenuItemView.swift the on/off switch in the menu
  VolumeMenuItemView.swift the volume slider in the menu
  LaunchAtLogin.swift      SMAppService login item
Tools/MakeIcon.swift       draws the app icon at build time
build.sh                   compile, bundle, ad-hoc sign
```

A few decisions worth knowing if you're reading the source:

- **The chimes are synthesised**, not sampled — a couple of decaying sine
  partials written into a WAV in memory. Nothing to ship, and they sound the
  same on every machine regardless of which system sounds are installed.
- **The volume slider position is squared** to get an amplitude. A linear
  amplitude slider crowds every useful level into the last third of its travel.
- **Digits are centred on their cap height**, not their line box, which reserves
  descender space they don't use and would sit them visibly low in the ring.

## License

[MIT](LICENSE) © Luka Skeledzija
