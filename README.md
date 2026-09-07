# 202020

A macOS menu bar app for the 20-20-20 rule: every **20 minutes**, look at something
**20 feet** away for **20 seconds**.

When a break starts the screen is covered and a soft chime plays. When the break is
over a second, brighter chime plays — so you never have to look at the screen to know
when it is safe to look back. That is the whole point: the sound is the signal, the
countdown is just there if you want it.

## Install

```sh
./build.sh --install
```

This compiles the app, drops it in `/Applications`, and launches it. Look for the eye
icon in the menu bar. To build without installing, run `./build.sh` — the bundle lands
in `build/202020.app`.

Requires macOS 13 or later and the Swift toolchain from the Xcode Command Line Tools
(`xcode-select --install`). No Xcode project, no dependencies.

## Using it

Everything lives in the menu bar icon:

- **Eye breaks** — the on/off switch. Off means no timers at all.
- **Take a break now** — start one immediately.
- **Mute sounds** — silences both chimes. The breaks still happen; muting is not the
  same as switching the app off.
- **Volume** — the slider under it. Let go of the knob and it plays the "look back"
  tone so you can hear what you picked. It greys out while muted. The slider position
  is squared to get the amplitude, so the travel matches what your ears expect rather
  than crowding every useful level into the last third.
- **Settings** — break interval (15–60 min), break length (20–60 s), how much of the
  screen the overlay covers, a menu-bar countdown, and **Start at login**.

### Skipping

The overlay has a **Hold to skip** button, and the `esc` key does the same thing.
Either way it takes a deliberate second-and-a-half hold — a stray click or keypress
does nothing. The button is plain grey with no fill, sitting well away from the
countdown: easy to find when you genuinely need it, easy to ignore when you don't.
Skipping does not earn you a longer stretch before the next break.

## It stays out of the way

- **Away from the keyboard** when a break comes due? The break is dropped and the cycle
  restarts — your eyes already got their rest, and you won't come back to an overlay.
- **Screen locked, display asleep, or the Mac was sleeping?** Same: no overlay, and the
  clock restarts from a full interval when you come back.
- **Multiple displays** are all covered, so you can't just look at the other monitor.

## Battery

This runs all day, so it is built not to cost anything while it waits:

- While counting down there is **one timer, scheduled directly on the next break** —
  not a per-second poll. It carries a 30-second tolerance so macOS can coalesce the
  wakeup with others instead of waking the CPU on its own.
- Per-second updates exist **only while the menu is open**. Closing the menu stops them.
- The optional menu-bar countdown ticks **once every 15 seconds** (whole minutes),
  switching to seconds only in the final minute.
- Turning the switch off invalidates every timer — the app is then genuinely inert.
- During a break the overlay repaints a **small centred view at 10 fps**, never the
  whole display; the dark background is drawn once and cached as a layer.

Measured idle draw is effectively zero CPU time between breaks.

## Layout

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
