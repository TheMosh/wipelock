import AppKit

/// A borderless black window covering one screen, showing the seconds left in white.
final class OverlayWindow: NSWindow {
    private let numberLabel = NSTextField(labelWithString: "")

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        // Shielding level sits above the menu bar, Dock, notifications and full-screen apps.
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none

        let height = screen.frame.height
        numberLabel.font = .monospacedDigitSystemFont(ofSize: height * 0.4, weight: .medium)
        numberLabel.textColor = .white
        numberLabel.alignment = .center

        let caption = NSTextField(labelWithString: "Keyboard and mouse are disabled")
        caption.font = .systemFont(ofSize: max(14, height * 0.022), weight: .regular)
        caption.textColor = NSColor(white: 1, alpha: 0.45)

        let content = BlackView()
        for label in [numberLabel, caption] {
            label.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(label)
        }
        NSLayoutConstraint.activate([
            numberLabel.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: content.centerYAnchor, constant: -height * 0.03),
            caption.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            caption.topAnchor.constraint(equalTo: numberLabel.bottomAnchor, constant: height * 0.01),
        ])
        contentView = content
    }

    // Borderless windows refuse key status by default; taking it means any stray
    // keystroke lands here instead of in the app underneath.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func setSeconds(_ seconds: Int) {
        let text = String(seconds)
        if numberLabel.stringValue != text { numberLabel.stringValue = text }
    }
}

private final class BlackView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()
    }
}
