import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ConfiguringView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ConfiguringView)?.configureWindow()
    }
}

private final class ConfiguringView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindow()
    }

    func configureWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }
            window.identifier = NSUserInterfaceItemIdentifier("main")
            window.minSize = NSSize(width: 900, height: 620)

            let isTooSmall = window.frame.width < 900 || window.frame.height < 620
            let isOffscreen = !NSScreen.screens.contains { $0.visibleFrame.intersects(window.frame) }
            if isTooSmall || isOffscreen {
                window.setContentSize(NSSize(width: 1120, height: 760))
                window.center()
            }
        }
    }
}
