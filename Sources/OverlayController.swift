import AppKit

/// Puts a near-opaque sheet over every display for the duration of a break.
final class OverlayController {

    var onSkip: (() -> Void)?

    private var windows: [NSWindow] = []
    private var views: [BreakView] = []
    private var previousApp: NSRunningApplication?
    private(set) var isShowing = false

    func show(total: TimeInterval) {
        guard !isShowing else { return }
        isShowing = true

        // Remember who had focus so it can be handed back when the break ends.
        previousApp = NSWorkspace.shared.frontmostApplication

        for (index, screen) in NSScreen.screens.enumerated() {
            let isPrimary = (screen == NSScreen.main) || (NSScreen.main == nil && index == 0)
            let view = BreakView(frame: NSRect(origin: .zero, size: screen.frame.size),
                                 isPrimary: isPrimary,
                                 total: total,
                                 opacity: Preferences.shared.dimOpacity)
            view.onSkip = { [weak self] in self?.onSkip?() }

            let window = NSWindow(contentRect: screen.frame,
                                  styleMask: .borderless,
                                  backing: .buffered,
                                  defer: false)
            window.contentView = view
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.isMovable = false
            window.animationBehavior = .none
            // Above full-screen apps and the menu bar.
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            window.alphaValue = 0
            window.setFrame(screen.frame, display: false)
            window.orderFrontRegardless()

            windows.append(window)
            views.append(view)
        }

        NSApp.activate(ignoringOtherApps: true)
        if let index = views.firstIndex(where: { $0.isPrimary }) ?? views.indices.first {
            windows[index].makeKeyAndOrderFront(nil)
            windows[index].makeFirstResponder(views[index])
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.55
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for window in windows { window.animator().alphaValue = 1 }
        }
    }

    func update(remaining: TimeInterval) {
        // Only the primary view has anything that changes; the sheets on other
        // displays are painted once and left alone.
        for view in views { view.update(remaining: remaining) }
    }

    func hide() {
        guard isShowing else { return }
        isShowing = false

        let closing = windows
        windows = []
        for view in views { view.tearDown() }
        views = []

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for window in closing { window.animator().alphaValue = 0 }
        }, completionHandler: {
            for window in closing { window.orderOut(nil) }
        })

        // Hand focus back to whatever was in front before the break.
        let previous = previousApp
        previousApp = nil
        NSApp.hide(nil)
        if let previous, previous.bundleIdentifier != Bundle.main.bundleIdentifier {
            previous.activate(options: [])
        }
    }
}
