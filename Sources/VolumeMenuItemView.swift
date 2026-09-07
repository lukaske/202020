import AppKit

/// A volume slider that lives in the menu, next to the mute toggle.
final class VolumeMenuItemView: NSView {

    /// `preview` is true on mouse-up, when playing a sample is welcome rather
    /// than deafening — dragging fires this continuously.
    private let onChange: (Double, Bool) -> Void

    private let icon = NSImageView()
    private let slider = NSSlider()

    /// While the knob is under the finger, external updates are ignored so a
    /// periodic refresh can't yank it out from under the drag.
    private var isDragging = false

    init(volume: Double, enabled: Bool, onChange: @escaping (Double, Bool) -> Void) {
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 230, height: 30))

        icon.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: nil)
        icon.image?.isTemplate = true
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false

        slider.minValue = 0
        slider.maxValue = 1
        slider.doubleValue = volume
        slider.isContinuous = true
        slider.controlSize = .small
        slider.isEnabled = enabled
        slider.target = self
        slider.action = #selector(changed(_:))
        slider.setAccessibilityLabel("Sound volume")
        slider.translatesAutoresizingMaskIntoConstraints = false

        addSubview(icon)
        addSubview(slider)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            slider.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    var volume: Double {
        get { slider.doubleValue }
        set { if !isDragging { slider.doubleValue = newValue } }
    }

    var isEnabled: Bool {
        get { slider.isEnabled }
        set {
            slider.isEnabled = newValue
            icon.contentTintColor = newValue ? .secondaryLabelColor : .tertiaryLabelColor
        }
    }

    @objc private func changed(_ sender: NSSlider) {
        let released = NSApp.currentEvent?.type == .leftMouseUp
        isDragging = !released
        onChange(sender.doubleValue, released)
    }
}
