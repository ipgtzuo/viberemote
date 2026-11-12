import SwiftUI
import AppKit

final class VibeRemoteAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        VibeRemoteModel.shared?.shutdown()
    }
}

@main
struct VibeRemoteApp: App {
    @NSApplicationDelegateAdaptor(VibeRemoteAppDelegate.self) private var appDelegate
    @StateObject private var model = VibeRemoteModel()

    init() {
        guard CommandLine.arguments.contains("--mapping") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            VibeRemoteModel.shared?.openMappingSettings()
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
