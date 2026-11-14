import SwiftUI
import AppKit
import Darwin

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
    @StateObject private var model: VibeRemoteModel
    private static var instanceLockFD: Int32 = -1

    init() {
        guard Self.acquireInstanceLock() else {
            if let bundleID = Bundle.main.bundleIdentifier,
               let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .first(where: { $0.processIdentifier != getpid() }) {
                running.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            }
            exit(0)
        }
        _model = StateObject(wrappedValue: VibeRemoteModel())
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
        if CommandLine.arguments.contains("--selftest") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                VibeRemoteModel.shared?.openVoiceSelfTest()
            }
        }
        let forceOnboarding = CommandLine.arguments.contains("--onboarding")
        let suppressOnboarding = CommandLine.arguments.contains("--panel")
            || CommandLine.arguments.contains("--mapping")
            || CommandLine.arguments.contains("--selftest")
        if forceOnboarding || (!suppressOnboarding && !UserDefaults.standard.bool(forKey: "vibeRemote.didOnboard")) {
            DispatchQueue.main.asyncAfter(deadline: .now() + (forceOnboarding ? 0.8 : 1.4)) {
                VibeRemoteModel.shared?.showOnboarding()
            }
        }
    }

    private static func acquireInstanceLock() -> Bool {
        let fileManager = FileManager.default
        guard let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return true
        }
        let directory = support.appendingPathComponent("VibeRemote", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("instance.lock").path
        let fd = open(path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return true }
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            return false
        }
        instanceLockFD = fd
        return true
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
