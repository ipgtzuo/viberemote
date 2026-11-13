import SwiftUI
import AppKit

final class VibeRemoteAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        VibeRemoteModel.shared?.shutdown()
    }
}


final class VibePanelPreviewController {
    static let shared = VibePanelPreviewController()
    private var window: NSWindow?

    func show(model: VibeRemoteModel) {
        let root = VibeRemoteView(model: model, bindings: model.bindings)
            .environment(\.vibePreview, true)
        let host = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 360, height: 462))
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

@main
struct VibeRemoteApp: App {
    @NSApplicationDelegateAdaptor(VibeRemoteAppDelegate.self) private var appDelegate
    @StateObject private var model = VibeRemoteModel()

    init() {
        if CommandLine.arguments.contains("--mapping") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                VibeRemoteModel.shared?.openMappingSettings()
            }
        }
        if CommandLine.arguments.contains("--panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                guard let model = VibeRemoteModel.shared else { return }
                VibePanelPreviewController.shared.show(model: model)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            VibeRemoteView(model: model, bindings: model.bindings)
        } label: {
            VibeRemoteMenuLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
