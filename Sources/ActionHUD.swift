import AppKit

final class ActionHUD {
    private var panel: NSPanel?
    private var iconView: NSImageView?
    private var label: NSTextField?
    private var hideWork: DispatchWorkItem?

    func show(_ text: String, symbol: String, duration: TimeInterval = 1.2) {
        DispatchQueue.main.async {
            let panel = self.makePanelIfNeeded()
            self.iconView?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            self.label?.stringValue = text

            if let screen = NSScreen.main {
                let frame = screen.visibleFrame
                panel.setFrameOrigin(NSPoint(
                    x: frame.midX - panel.frame.width / 2,
                    y: frame.maxY - panel.frame.height - 24
                ))
            }

            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                panel.animator().alphaValue = 1
            }

            self.hideWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, let panel = self.panel else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.22
                    panel.animator().alphaValue = 0
                } completionHandler: {
                    panel.orderOut(nil)
                }
            }
            self.hideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
        }
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false

        let effect = NSVisualEffectView(frame: panel.contentView!.bounds)
        effect.autoresizingMask = [.width, .height]
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentTintColor = NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.30, alpha: 1)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)

        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail

        effect.addSubview(icon)
        effect.addSubview(label)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 18),
            icon.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: effect.centerYAnchor)
        ])

        panel.contentView = effect
        self.panel = panel
        self.iconView = icon
        self.label = label
        return panel
    }
}
