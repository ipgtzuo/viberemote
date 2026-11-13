import AppKit
import SwiftUI

// MARK: - Windows

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?
    private weak var model: VibeRemoteModel?

    func show(model: VibeRemoteModel) {
        self.model = model
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let view = OnboardingView(model: model) { [weak self] in self?.close() }
        let host = NSHostingController(rootView: view)
        let panel = NSWindow(contentViewController: host)
        panel.title = "VibeRemote 设置"
        panel.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.setContentSize(NSSize(width: 520, height: 620))
        panel.center()
        panel.delegate = self
        window = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        model?.onboardingWindowDidClose()
        window = nil
    }
}

@MainActor
final class VoiceSelfTestWindowController: NSObject, NSWindowDelegate {
    static let shared = VoiceSelfTestWindowController()

    private var window: NSWindow?
    private weak var model: VibeRemoteModel?

    func show(model: VibeRemoteModel) {
        self.model = model
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let view = VoiceSelfTestView(model: model) { [weak self] in self?.close() }
        let host = NSHostingController(rootView: view)
        let panel = NSWindow(contentViewController: host)
        panel.title = "VibeRemote 语音自检"
        panel.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.setContentSize(NSSize(width: 520, height: 640))
        panel.center()
        panel.delegate = self
        window = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        model?.voiceSelfTestWindowDidClose()
        window = nil
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @ObservedObject var model: VibeRemoteModel
    var onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var theme: VibeTheme { VibeTheme(colorScheme) }

    var body: some View {
        ZStack {
            VibePanelBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    connectionStep
                    permissionStep
                    testStep
                    footer
                }
                .padding(24)
            }
        }
        .frame(width: 520, height: 620)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("欢迎使用 VibeRemote")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.primary)
                Text("把电视遥控器变成 Vibe Coding 手柄")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text(0.55))
            }

            Spacer(minLength: 8)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.text(0.55))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(theme.controlFill))
            }
            .buttonStyle(.plain)
        }
    }

    private var connectionStep: some View {
        OnboardingStep(number: "01", title: "连接遥控器", detail: "按住配对键，在蓝牙里连接") {
            HStack(spacing: 9) {
                Circle()
                    .fill(model.connected ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(model.connected
                     ? "已连接 \(max(model.connectedRemoteKinds.count, 1)) 个遥控器"
                     : "还没有连接遥控器")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.primary)
                Spacer()
                Button("打开蓝牙设置") { model.openBluetoothSettings() }
                    .buttonStyle(OnboardingSmallButton())
            }

            HStack(spacing: 8) {
                Label("Siri Remote A2540", systemImage: "appletvremote.gen3")
                Text("·").foregroundStyle(theme.text(0.3))
                Label("小米 RC003-MS", systemImage: "appletvremote.gen4")
            }
            .font(.system(size: 11))
            .foregroundStyle(theme.text(0.55))
        }
    }

    private var permissionStep: some View {
        OnboardingStep(number: "02", title: "授权两个权限", detail: "只在本机读取按键，不上传") {
            PermissionStatusRow(
                title: "输入监控",
                detail: "读取遥控器按键和方向环",
                granted: model.inputMonitoringGranted,
                action: { model.requestInputMonitoring() }
            )
            PermissionStatusRow(
                title: "辅助功能",
                detail: "把按键转换成听写、发送等操作",
                granted: model.accessibilityGranted,
                action: { model.requestAccessibility() }
            )
        }
    }

    private var testStep: some View {
        OnboardingStep(number: "03", title: "试一下语音", detail: "把光标放进输入框，按语音键") {
            Text("建议先跑一次语音自检，确认系统听写、麦克风和遥控器按键都能工作。")
                .font(.system(size: 11.5))
                .foregroundStyle(theme.text(0.55))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button {
                    model.openVoiceSelfTest()
                } label: {
                    Label("打开语音自检", systemImage: "waveform.and.mic")
                }
                .buttonStyle(OnboardingPrimaryButton())

                Button {
                    model.restartRemote()
                } label: {
                    Label("重新连接", systemImage: "arrow.clockwise")
                }
                .buttonStyle(OnboardingSmallButton())
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("稍后设置") { model.finishOnboarding() }
                .buttonStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(theme.text(0.45))

            Spacer()

            Button("完成") { model.finishOnboarding() }
                .buttonStyle(OnboardingPrimaryButton())
        }
        .padding(.top, 2)
    }
}

private struct OnboardingStep<Content: View>: View {
    let number: String
    let title: String
    let detail: String
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var colorScheme
    private var theme: VibeTheme { VibeTheme(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(number)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 20)
                    .background(
                        Capsule().fill(Color.accentColor.opacity(0.12))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(theme.primary)
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.text(0.45))
                }
            }
            content
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(theme.cardStroke, lineWidth: 0.7)
                )
        )
    }
}

private struct PermissionStatusRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var theme: VibeTheme { VibeTheme(colorScheme) }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(granted ? Color.green : Color.orange)
                .frame(width: 17)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.primary)
                Text(granted ? detail : "未授权 · \(detail)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.text(granted ? 0.45 : 0.6))
            }

            Spacer(minLength: 6)

            Button(granted ? "设置" : "去授权", action: action)
                .buttonStyle(OnboardingSmallButton())
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Voice self test

struct VoiceSelfTestView: View {
    @ObservedObject var model: VibeRemoteModel
    var onClose: () -> Void

    @State private var testText = ""
    @State private var copied = false
    @FocusState private var inputFocused: Bool

    @Environment(\.colorScheme) private var colorScheme
    private var theme: VibeTheme { VibeTheme(colorScheme) }

    var body: some View {
        ZStack {
            VibePanelBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    statusCard
                    testCard
                    diagnosticCard
                }
                .padding(22)
            }
        }
        .frame(width: 520, height: 640)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 0.48, green: 0.40, blue: 0.98), Color(red: 0.58, green: 0.33, blue: 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("语音自检")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.primary)
                Text("先确认权限，再在输入框里说一句话")
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.text(0.52))
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.text(0.55))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(theme.controlFill))
            }
            .buttonStyle(.plain)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("运行状态")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.text(0.5))

            selfTestRow("输入监控", model.inputMonitoringGranted ? "已授权" : "未授权", good: model.inputMonitoringGranted)
            selfTestRow("辅助功能", model.accessibilityGranted ? "已授权" : "未授权", good: model.accessibilityGranted)
            selfTestRow("遥控器", remoteSummary, good: model.connected)
            selfTestRow("最近按键", model.lastRaw.isEmpty ? "还没有收到按键" : model.lastRaw, good: !model.lastRaw.isEmpty)
            selfTestRow("最近动作", model.lastAction.isEmpty ? "无" : model.lastAction, good: !model.lastAction.isEmpty)

            if !model.inputMonitoringGranted || !model.accessibilityGranted {
                HStack(spacing: 7) {
                    Button("打开输入监控") { model.openInputMonitoringSettings() }
                    Button("打开辅助功能") { model.openAccessibilitySettings() }
                }
                .buttonStyle(OnboardingSmallButton())
            }
        }
        .padding(13)
        .background(cardBackground)
    }

    private var testCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("测试输入框")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.text(0.5))
                Spacer()
                Text(model.selfTestDictating ? "正在听写" : "等待语音")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(model.selfTestDictating ? Color.red : theme.text(0.4))
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $testText)
                    .font(.system(size: 12.5))
                    .scrollContentBackground(.hidden)
                    .padding(7)
                    .frame(height: 112)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(theme.controlFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(inputFocused ? Color.accentColor.opacity(0.6) : theme.controlStroke, lineWidth: 0.8)
                            )
                    )
                    .focused($inputFocused)

                if testText.isEmpty {
                    Text("点这里，然后按一下遥控器语音键，或点下方按钮；开始后说一句话，再按一次结束。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(theme.text(0.3))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 13)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 8) {
                Button {
                    inputFocused = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        model.toggleSelfTestDictation()
                    }
                } label: {
                    Label(model.selfTestDictating ? "结束听写" : "开始听写",
                          systemImage: model.selfTestDictating ? "stop.fill" : "mic.fill")
                }
                .buttonStyle(OnboardingPrimaryButton())

                Button("清空") { testText = "" }
                    .buttonStyle(OnboardingSmallButton())

                Spacer()

                Text("Fn 🌐")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.text(0.32))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.controlFill))
            }

            Text("正常模式会优先用输入 App 的“开始听写”菜单；这里测试的是系统 Fn 听写，快捷键需与“键盘 → 听写”设置一致。")
                .font(.system(size: 10))
                .foregroundStyle(theme.text(0.4))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .background(cardBackground)
    }

    private var diagnosticCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("诊断信息")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.text(0.5))
                Spacer()
                Button(copied ? "已复制" : "复制") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(model.voiceDiagnosticReport(), forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
                }
                .buttonStyle(OnboardingSmallButton())
            }

            Text(model.voiceDiagnosticReport())
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(theme.text(0.48))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(13)
        .background(cardBackground)
    }

    private var remoteSummary: String {
        let names = RemoteKind.allCases
            .filter { model.connectedRemoteKinds.contains($0) }
            .map { $0.shortLabel }
        return names.isEmpty ? "未连接" : names.joined(separator: " / ")
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(theme.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(theme.cardStroke, lineWidth: 0.7)
            )
    }

    private func selfTestRow(_ title: String, _ value: String, good: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: good ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(good ? Color.green : Color.orange)
                .frame(width: 15)
            Text(title)
                .font(.system(size: 11.5))
                .foregroundStyle(theme.text(0.55))
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.text(0.8))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Buttons

private struct OnboardingPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 0.36, green: 0.39, blue: 0.95).opacity(configuration.isPressed ? 0.75 : 1))
            )
    }
}

private struct OnboardingSmallButton: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    private var theme: VibeTheme { VibeTheme(colorScheme) }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(theme.text(0.75))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(theme.controlFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(theme.controlStroke, lineWidth: 0.7)
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
