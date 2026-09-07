import AppKit

/// The content of the overlay: a near-opaque sheet with the countdown.
///
/// Skipping is possible but never urged. The button is visible so you can find
/// it, and quiet so it doesn't invite you: no fill, no colour, and it takes a
/// deliberate press-and-hold rather than a click. Escape does the same thing.
///
/// The sheet is split into a static background plus three small subviews so a
/// ticking countdown never repaints a whole display. Only the countdown and the
/// skip button are ever marked dirty.
final class BreakView: NSView {

    /// Called when the user completes the skip gesture.
    var onSkip: (() -> Void)?

    private static let holdDuration: TimeInterval = 1.5

    let isPrimary: Bool
    private let total: TimeInterval
    private let opacity: Double

    private var countdown: CountdownView?
    private var skipButton: SkipButtonView?

    private var holdStart: Date?
    private var holdTimer: Timer?

    init(frame: NSRect, isPrimary: Bool, total: TimeInterval, opacity: Double) {
        self.isPrimary = isPrimary
        self.total = total
        self.opacity = opacity
        super.init(frame: frame)

        wantsLayer = true
        // The background never changes, so let AppKit cache it as a layer and
        // only recomposite the small subviews that actually animate.
        layerContentsRedrawPolicy = .onSetNeedsDisplay

        guard isPrimary else { return }

        let countdown = CountdownView(frame: .zero)
        countdown.total = total
        countdown.remaining = total
        addSubview(countdown)
        self.countdown = countdown

        let button = SkipButtonView(frame: .zero)
        button.onHoldBegin = { [weak self] in self?.beginHold() }
        button.onHoldEnd = { [weak self] in self?.cancelHold() }
        addSubview(button)
        self.skipButton = button

        layoutSubviewFrames()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutSubviewFrames()
    }

    private func layoutSubviewFrames() {
        countdown?.frame = NSRect(x: bounds.midX - 380, y: bounds.midY - 220, width: 760, height: 480)
        skipButton?.frame = NSRect(x: bounds.midX - SkipButtonView.size.width / 2,
                                   y: bounds.minY + 84,
                                   width: SkipButtonView.size.width,
                                   height: SkipButtonView.size.height)
    }

    func update(remaining: TimeInterval) {
        guard isPrimary else { return }
        countdown?.remaining = remaining
    }

    // MARK: - Drawing (static background only)

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.05, alpha: CGFloat(opacity)).setFill()
        dirtyRect.fill()

        // A barely-there glow so the sheet reads as a surface, not a dead pixel.
        guard let gradient = NSGradient(colors: [
            NSColor(calibratedWhite: 0.16, alpha: CGFloat(opacity * 0.55)),
            NSColor(calibratedWhite: 0.05, alpha: 0.0),
        ]) else { return }
        gradient.draw(in: NSRect(x: bounds.minX,
                                 y: bounds.midY - bounds.height * 0.6,
                                 width: bounds.width,
                                 height: bounds.height * 1.2),
                      relativeCenterPosition: .zero)

        if !isPrimary {
            TextDraw.draw("Look away",
                          font: .systemFont(ofSize: 34, weight: .light),
                          color: NSColor(calibratedWhite: 1, alpha: 0.5),
                          centeredAt: NSPoint(x: bounds.midX, y: bounds.midY))
        }
    }

    // MARK: - Skip gesture

    override func keyDown(with event: NSEvent) {
        // 53 is Escape. Everything else is swallowed so stray typing during a
        // break neither beeps nor reaches whatever is behind the overlay.
        guard event.keyCode == 53, !event.isARepeat else { return }
        beginHold()
    }

    override func keyUp(with event: NSEvent) {
        guard event.keyCode == 53 else { return }
        cancelHold()
    }

    override func resignFirstResponder() -> Bool {
        cancelHold()
        return true
    }

    private func beginHold() {
        guard holdTimer == nil else { return }
        holdStart = Date()
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self, let start = self.holdStart else { return }
            let progress = min(1, Date().timeIntervalSince(start) / Self.holdDuration)
            self.skipButton?.holdProgress = progress
            if progress >= 1 {
                self.cancelHold()
                self.onSkip?()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        holdStart = nil
        skipButton?.holdProgress = 0
    }

    func tearDown() {
        cancelHold()
    }
}

// MARK: - Countdown

/// The ring, the number and the instruction. Small enough that repainting it
/// ten times a second costs nothing.
private final class CountdownView: NSView {

    var total: TimeInterval = 20
    var remaining: TimeInterval = 20 {
        didSet {
            // Redraw only when the drawn result would actually differ.
            if abs(remaining - oldValue) > 0.04 { needsDisplay = true }
        }
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY - 10)

        drawRing(center: center, radius: 108)

        // The digits sit dead centre in the ring: centred on their cap height,
        // not on the line box, which would push them low by the descender.
        let seconds = max(0, Int(ceil(remaining)))
        TextDraw.draw("\(seconds)",
                      font: .monospacedDigitSystemFont(ofSize: 92, weight: .ultraLight),
                      color: NSColor(calibratedWhite: 1, alpha: 0.92),
                      centeredAt: center,
                      opticallyCentered: true)

        TextDraw.draw("Look away",
                      font: .systemFont(ofSize: 42, weight: .light),
                      color: NSColor(calibratedWhite: 1, alpha: 0.9),
                      centeredAt: NSPoint(x: center.x, y: center.y + 196),
                      opticallyCentered: true)

        TextDraw.draw("Rest your eyes on something about 20 feet away.",
                      font: .systemFont(ofSize: 17, weight: .regular),
                      color: NSColor(calibratedWhite: 1, alpha: 0.42),
                      centeredAt: NSPoint(x: center.x, y: center.y + 156),
                      opticallyCentered: true)
    }

    private func drawRing(center: NSPoint, radius: CGFloat) {
        let fraction = total > 0 ? max(0, min(1, remaining / total)) : 0

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = 2
        NSColor(calibratedWhite: 1, alpha: 0.10).setStroke()
        track.stroke()

        guard fraction > 0 else { return }
        let progress = NSBezierPath()
        progress.appendArc(withCenter: center,
                           radius: radius,
                           startAngle: 90,
                           endAngle: 90 - 360 * CGFloat(fraction),
                           clockwise: true)
        progress.lineWidth = 2
        progress.lineCapStyle = .round
        NSColor(calibratedWhite: 1, alpha: 0.55).setStroke()
        progress.stroke()
    }
}

// MARK: - Skip button

/// Visible, so it can be found. Quiet, so it isn't an invitation. It only fires
/// after being held down — a stray click does nothing.
private final class SkipButtonView: NSView {

    static let size = NSSize(width: 188, height: 42)

    var onHoldBegin: (() -> Void)?
    var onHoldEnd: (() -> Void)?

    var holdProgress: Double = 0 {
        didSet { if abs(holdProgress - oldValue) > 0.005 { needsDisplay = true } }
    }

    private var isHovered = false { didSet { needsDisplay = true } }
    private var isPressed = false { didSet { needsDisplay = true } }

    override var isOpaque: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways],
                                       owner: self,
                                       userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        onHoldBegin?()
    }

    override func mouseUp(with event: NSEvent) {
        isPressed = false
        onHoldEnd?()
    }

    override func draw(_ dirtyRect: NSRect) {
        let outline = bounds.insetBy(dx: 1, dy: 1)
        let radius = outline.height / 2
        let shape = NSBezierPath(roundedRect: outline, xRadius: radius, yRadius: radius)

        // The hold fills the pill from the left so the gesture explains itself.
        if holdProgress > 0 {
            NSGraphicsContext.saveGraphicsState()
            shape.addClip()
            NSColor(calibratedWhite: 1, alpha: 0.12).setFill()
            NSRect(x: outline.minX,
                   y: outline.minY,
                   width: outline.width * CGFloat(holdProgress),
                   height: outline.height).fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        let emphasis = max(isHovered ? 0.30 : 0.18, 0.18 + 0.30 * holdProgress)
        shape.lineWidth = 1
        NSColor(calibratedWhite: 1, alpha: CGFloat(emphasis)).setStroke()
        shape.stroke()

        let label = holdProgress > 0 ? "Keep holding" : "Hold to skip"
        let textAlpha = max(isHovered ? 0.55 : 0.38, 0.38 + 0.35 * holdProgress)
        TextDraw.draw(label,
                      font: .systemFont(ofSize: 13, weight: .regular),
                      color: NSColor(calibratedWhite: 1, alpha: CGFloat(textAlpha)),
                      centeredAt: NSPoint(x: bounds.midX, y: bounds.midY),
                      opticallyCentered: true)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

// MARK: - Text helper

private enum TextDraw {

    /// Draws one line centred on `point`.
    ///
    /// `opticallyCentered` centres the glyphs on their cap height instead of on
    /// the line box. A line box reserves room for descenders, so text with none
    /// — digits especially — sits visibly low when the box is what gets centred.
    static func draw(_ text: String,
                     font: NSFont,
                     color: NSColor,
                     centeredAt point: NSPoint,
                     opticallyCentered: Bool = false) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
            .kern: font.pointSize > 30 ? 0.5 : 1.4,
        ])

        let size = attributed.size()
        let originY: CGFloat
        if opticallyCentered {
            // Baseline lands at (top of box - ascender); put the midpoint
            // between baseline and cap height on the requested y.
            originY = point.y - size.height + font.ascender - font.capHeight / 2
        } else {
            originY = point.y - size.height / 2
        }

        attributed.draw(in: NSRect(x: point.x - size.width / 2,
                                   y: originY,
                                   width: size.width,
                                   height: size.height + 2))
    }
}
