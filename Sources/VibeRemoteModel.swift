import AppKit
import ApplicationServices
import Combine
import Foundation
import IOKit.hidsystem
import SwiftUI

@MainActor
final class VibeRemoteModel: ObservableObject {
    @Published private(set) var connected = false
    @Published private(set) var remoteName = ""
    @Published private(set) var status = "正在启动…"
    @Published private(set) var isDictating = false
    @Published private(set) var lastAction = ""
    @Published private(set) var lastRaw = ""
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var inputMonitoringGranted = false
    @Published private(set) var batteryPercent: Int?
    @Published private(set) var isWired = false
    @Published private(set) var batteryLoading = false
    @Published private(set) var isMappingWindowOpen = false
    @Published private(set) var appearanceMode: AppearanceMode = .auto
    @Published private(set) var selectedMode: AppMode = .dsh
    @Published private(set) var resolvedMode: AppMode = .dsh
    @Published private(set) var frontmostAppName = ""

    static weak var shared: VibeRemoteModel?
    let physicalButtonEvents = PassthroughSubject<RemoteButton, Never>()

    let bindings: ButtonBindingStore
    private let remote = RemoteManager()
    private let actions: ActionExecutor
    private let touchpad: TouchpadManager
    private let hud = ActionHUD()
    private var permissionTimer: Timer?
    private var batteryTimer: Timer?
    private var settingsController: MappingWindowController?
    private var workspaceObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    var preferredColorScheme: ColorScheme? {
        appearanceMode.colorScheme
    }

    var modeDisplay: String {
        selectedMode.isAutomatic ? "自动 · \(resolvedMode.label)" : resolvedMode.label
    }

    func setMode(_ mode: AppMode) {
        selectedMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "vibeRemote.appMode")

        if mode.isAutomatic {
            let front = NSWorkspace.shared.frontmostApplication
            resolvedMode = front?.bundleIdentifier == Bundle.main.bundleIdentifier
                ? resolvedMode
                : AppMode.detect(bundleID: front?.bundleIdentifier)
        } else {
            resolvedMode = mode
        }
        applyResolvedMode()
    }

    private func applyResolvedMode() {
        actions.releaseAll()
        bindings.switchProfile(resolvedMode)
        actions.targetBundleID = resolvedMode.bundleID
    }

    private func startWorkspaceObserver() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recoverAfterWake()
            }
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                self?.handleFrontmost(app)
            }
        }
    }

    private func recoverAfterWake() {
        actions.releaseAll()
        remote.stop()
        touchpad.stop()
        refreshPermissions()
        remote.start()
        touchpad.start()
        refreshBattery()
    }

    private func handleFrontmost(_ app: NSRunningApplication?) {
        if let name = app?.localizedName {
            frontmostAppName = name
        }
        guard selectedMode.isAutomatic else { return }
        guard app?.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        let detected = AppMode.detect(bundleID: app?.bundleIdentifier)
        guard detected != resolvedMode else { return }
        resolvedMode = detected
        applyResolvedMode()
    }

    func setAppearance(_ mode: AppearanceMode) {
        appearanceMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "vibeRemote.appearance")
    }

    init(preview: Bool = false) {
        if let raw = UserDefaults.standard.string(forKey: "vibeRemote.appearance"),
           let mode = AppearanceMode(rawValue: raw) {
            appearanceMode = mode
        }
        let savedMode = UserDefaults.standard.string(forKey: "vibeRemote.appMode")
            .flatMap(AppMode.init(rawValue:)) ?? .dsh
        let front = NSWorkspace.shared.frontmostApplication
        let detected = AppMode.detect(bundleID: front?.bundleIdentifier)
        let initialMode = savedMode.isAutomatic ? detected : savedMode
        selectedMode = savedMode
        resolvedMode = initialMode
        frontmostAppName = front?.localizedName ?? ""

        bindings = ButtonBindingStore(profile: initialMode)
        let executor = ActionExecutor(bindings: bindings)
        executor.targetBundleID = initialMode.bundleID
        actions = executor
        touchpad = TouchpadManager(actions: executor)
        VibeRemoteModel.shared = self

        if preview {
            connected = true
            remoteName = "Siri Remote (A2854)"
            status = "已连接 · 等待按键"
            accessibilityGranted = true
            inputMonitoringGranted = true
            batteryPercent = 82
            appearanceMode = .dark
        } else {
            configureRemote()
            refreshPermissions()
            remote.start()
            touchpad.start()
            startPermissionTimer()
            startBatteryTimer()
            startWorkspaceObserver()
        }
    }

    deinit {
        permissionTimer?.invalidate()
        batteryTimer?.invalidate()
    }

    var batteryText: String {
        if isWired { return "USB 充电" }
        if let batteryPercent { return "\(batteryPercent)%" }
        return connected ? "电量 —" : "—"
    }

    func shutdown() {
        permissionTimer?.invalidate()
        batteryTimer?.invalidate()
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
            self.workspaceObserver = nil
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        actions.releaseAll()
        touchpad.stop()
        remote.stop()
        isMappingWindowOpen = false
    }

    func refreshPermissions() {
        let hadInputMonitoring = inputMonitoringGranted
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted

        // If the user just granted Input Monitoring, recover without requiring a relaunch.
        if inputMonitoringGranted && !hadInputMonitoring && !remote.isListening {
            remote.start()
        }
    }

    func requestAccessibility() {
        refreshPermissions()
        if !accessibilityGranted {
            actions.requestAccessibility()
        }
    }

    func requestInputMonitoring() {
        let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        refreshPermissions()
        if !granted {
            openInputMonitoringSettings()
        }
    }

    func restartRemote() {
        status = "正在重新连接…"
        remote.stop()
        refreshPermissions()
        remote.start()
    }

    func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    func openBluetoothSettings() {
        if !open("x-apple.systempreferences:com.apple.Bluetooth-Settings.extension") {
            _ = open("x-apple.systempreferences:com.apple.preference.bluetooth")
        }
    }

    func openMappingSettings() {
        actions.releaseAll()
        touchpad.stop()
        isDictating = false
        isMappingWindowOpen = true

        if settingsController == nil {
            settingsController = MappingWindowController()
            settingsController?.onClose = { [weak self] in
                self?.isMappingWindowOpen = false
                self?.touchpad.start()
            }
        }
        settingsController?.show(model: self)
    }

    func refreshBattery() {
        guard connected, !isWired, !batteryLoading else {
            if isWired || !connected {
                batteryPercent = nil
            }
            return
        }
        batteryLoading = true
        DispatchQueue.global(qos: .utility).async {
            let percent = BluetoothBatteryReader.read()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.batteryPercent = percent
                self.batteryLoading = false
            }
        }
    }

    func quit() {
        shutdown()
        NSApplication.shared.terminate(nil)
    }

    private func configureRemote() {
        remote.onConnection = { [weak self] connected, name in
            guard let self else { return }
            self.connected = connected
            self.remoteName = name ?? ""
            self.isWired = self.remote.transport == "USB"
            if connected {
                self.refreshBattery()
            } else {
                self.isDictating = false
                self.actions.releaseAll()
                self.batteryPercent = nil
            }
        }

        remote.onStatus = { [weak self] message in
            self?.status = message
        }

        remote.onRawEvent = { [weak self] page, usage, value in
            guard let self, value != 0 else { return }
            self.lastRaw = String(format: "0x%02X / 0x%02X", page, usage)
        }

        remote.onButton = { [weak self] button, pressed in
            guard let self else { return }
            if pressed {
                self.physicalButtonEvents.send(button)
            }
            if self.isMappingWindowOpen {
                return
            }
            if button == .siri, self.bindings.action(for: .siri) == .dictation {
                self.isDictating = pressed
                if pressed {
                    self.hud.show("听写中…", symbol: "mic.fill", duration: 8)
                } else {
                    self.hud.show("听写结束", symbol: "mic.slash", duration: 0.8)
                }
            }
            self.actions.handle(button, pressed: pressed)
        }

        actions.onAction = { [weak self] text, symbol in
            guard let self else { return }
            self.lastAction = text
            self.hud.show(text, symbol: symbol)
        }
    }

    private func startBatteryTimer() {
        let timer = Timer(timeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshBattery()
            }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        batteryTimer = timer
    }

    private func startPermissionTimer() {
        let timer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissions()
            }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    @discardableResult
    private func open(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return NSWorkspace.shared.open(url)
    }
}
