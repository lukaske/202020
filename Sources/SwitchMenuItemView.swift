import AppKit

/// A real on/off switch living in the menu, rather than a checkmark.
final class SwitchMenuItemView: NSView {

    private let label = NSTextField(labelWithString: "")
    private let toggle = NSSwitch()
    private let onToggle: (Bool) -> Void

    init(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        self.onToggle = onToggle
        super.init(frame: NSRect(x: 0, y: 0, width: 230, height: 34))

        label.stringValue = title
        label.font = .menuFont(ofSize: 0)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        toggle.state = isOn ? .on : .off
        toggle.target = self
        toggle.action = #selector(switched(_:))
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.controlSize = .small

        addSubview(label)
        addSubview(toggle)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggle.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 16),
            heightAnchor.constraint(equalToConstant: 34),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    var isOn: Bool {
        get { toggle.state == .on }
        set { toggle.state = newValue ? .on : .off }
    }

    @objc private func switched(_ sender: NSSwitch) {
        onToggle(sender.state == .on)
        // Let the switch finish its animation before the menu closes.
        let menu = enclosingMenuItem?.menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            menu?.cancelTracking()
        }
    }
}
