import SwiftUI
import AppKit

private struct VibePreviewKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var vibePreview: Bool {
        get { self[VibePreviewKey.self] }
        set { self[VibePreviewKey.self] = newValue }
    }
}

struct VibeVisualEffect: NSViewRepresentable {
    var isDark: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = isDark ? .hudWindow : .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.state = .active
    }
}

struct VibePanelBackground: View {
    @Environment(\.vibePreview) private var preview
    @Environment(\.colorScheme) private var colorScheme

    private var theme: VibeTheme { VibeTheme(colorScheme) }

    var body: some View {
        ZStack {
            if preview {
                theme.panelTop
            } else {
                VibeVisualEffect(isDark: colorScheme == .dark)
            }
            LinearGradient(
                colors: [
                    theme.panelTop.opacity(0.92),
                    theme.panelBottom.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [theme.glowBlue, .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 240
            )
        }
        .ignoresSafeArea()
    }
}

private struct VibeCard<Content: View>: View {
    var accent: Color
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var colorScheme
    private var theme: VibeTheme { VibeTheme(colorScheme) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        content
            .padding(10)
            .background(
                shape.fill(
                    LinearGradient(
                        colors: [theme.text(0.07), theme.text(0.025)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [accent.opacity(0.12), accent.opacity(0.01)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [theme.text(0.13), theme.text(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
    }
}

private struct Keycap: View {
    var text: String
    var accent: Color? = nil
    @Environment(\.colorScheme) private var colorScheme
    private var theme: VibeTheme { VibeTheme(colorScheme) }

    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold, design: .rounded))
            .foregroundStyle((accent ?? theme.primary).opacity(0.75))
            .frame(minWidth: 30, minHeight: 19)
            .padding(.horizontal, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(theme.text(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(theme.text(0.09), lineWidth: 1)
                    )
            )
    }
}

private struct MappingRow: View {
    var key: String
    var action: String
    @Environment(\.colorScheme) private var colorScheme
    private var theme: VibeTheme { VibeTheme(colorScheme) }

    var body: some View {
        HStack(spacing: 7) {
            Keycap(text: key)
            Text(action)
                .font(.system(size: 9))
                .foregroundStyle(theme.text(0.55))
            Spacer(minLength: 0)
        }
    }
}

private struct PermissionChip: View {
    var title: String
    var granted: Bool
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    private var theme: VibeTheme { VibeTheme(colorScheme) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(granted ? Color(red: 0.36, green: 0.92, blue: 0.64) : Color(red: 1.0, green: 0.66, blue: 0.25))
                    .frame(width: 4, height: 4)
                Text(title)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(theme.text(granted ? 0.6 : 0.8))
                Text(granted ? "已授权" : "去授权")
                    .font(.system(size: 7))
                    .foregroundStyle(theme.text(0.32))
            }
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(
                Capsule()
                    .fill(granted ? theme.text(0.045) : Color(red: 1.0, green: 0.66, blue: 0.25).opacity(0.09))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                granted ? theme.text(0.06) : Color(red: 1.0, green: 0.66, blue: 0.25).opacity(0.18),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct VibeRemoteView: View {
    @ObservedObject var model: VibeRemoteModel
    @ObservedObject var bindings: ButtonBindingStore
    @Environment(\.vibePreview) private var previewMode
    @Environment(\.colorScheme) private var systemScheme

    private var resolvedScheme: ColorScheme { model.appearanceMode.colorScheme ?? systemScheme }
    private var theme: VibeTheme { VibeTheme(resolvedScheme) }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 7) {
                voiceCard
                connectionCard
                mappingCard
                permissionsRow
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 0)

            footer
        }
        .frame(width: 320, height: 344)
        .background(VibePanelBackground())
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(theme.text(0.09), lineWidth: 1)
        }
        .environment(\.colorScheme, resolvedScheme)
        .preferredColorScheme(model.preferredColorScheme)
    }

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.44, green: 0.50, blue: 1.0),
                                Color(red: 0.82, green: 0.36, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "appletvremote.gen3")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 27, height: 27)

            VStack(alignment: .leading, spacing: 0) {
                Text("VibeRemote")
                    .font(.system(size: 13, weight: .semibold))
                Text("Siri Remote → \(model.modeDisplay)")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.text(0.42))
            }

            Spacer(minLength: 6)

            HStack(spacing: 5) {
                Circle()
                    .fill(model.connected ? Color(red: 0.36, green: 0.92, blue: 0.64) : theme.text(0.25))
                    .frame(width: 4, height: 4)
                Text(model.connected ? "已连接" : "等待连接")
                    .font(.system(size: 7.5, weight: .medium))
                    .foregroundStyle(theme.text(model.connected ? 0.55 : 0.32))
            }

            if previewMode {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.text(0.5))
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(theme.text(0.055))
                            .overlay(Circle().strokeBorder(theme.text(0.06), lineWidth: 1))
                    )
            } else {
                Menu {
                    Menu("模式：\(model.modeDisplay)") {
                        ForEach(AppMode.allCases) { mode in
                            Button((model.selectedMode == mode ? "✓ " : "") + mode.label) {
                                model.setMode(mode)
                            }
                        }
                    }
                    Menu("主题：\(model.appearanceMode.label)") {
                        ForEach(AppearanceMode.allCases) { mode in
                            Button((model.appearanceMode == mode ? "✓ " : "") + mode.label) {
                                model.setAppearance(mode)
                            }
                        }
                    }
                    Divider()
                    Button("按键映射…") { model.openMappingSettings() }
                    Button("重新连接遥控器") { model.restartRemote() }
                    Divider()
                    Button("打开辅助功能设置") { model.openAccessibilitySettings() }
                    Button("打开输入监控设置") { model.openInputMonitoringSettings() }
                    Button("打开蓝牙设置") { model.openBluetoothSettings() }
                    Divider()
                    Button("退出 VibeRemote") { model.quit() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.text(0.5))
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(theme.text(0.055))
                                .overlay(Circle().strokeBorder(theme.text(0.06), lineWidth: 1))
                        )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(.horizontal, 13)
        .padding(.top, 11)
        .padding(.bottom, 8)
    }

    private var voiceCard: some View {
        let listening = model.isDictating
        return VibeCard(accent: listening ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color(red: 0.44, green: 0.55, blue: 1.0)) {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: listening
                                    ? [Color(red: 1.0, green: 0.58, blue: 0.25), Color(red: 1.0, green: 0.30, blue: 0.40)]
                                    : [Color(red: 0.40, green: 0.52, blue: 1.0), Color(red: 0.62, green: 0.38, blue: 0.96)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: listening ? "mic.fill" : "mic")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(listening ? "正在听写…" : "按住 Siri 说话")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(listening ? Color(red: 1.0, green: 0.74, blue: 0.45) : theme.text(0.92))
                    Text("松开按 TV 发送 · 先点 \(model.resolvedMode.label) 输入框")
                        .font(.system(size: 7.8))
                        .foregroundStyle(theme.text(0.36))
                        .lineLimit(1)
                }

                Spacer(minLength: 2)
                Keycap(text: "Siri", accent: theme.primary)
            }
        }
    }

    private var connectionCard: some View {
        VibeCard(accent: model.connected ? Color(red: 0.36, green: 0.92, blue: 0.64) : Color(red: 0.55, green: 0.58, blue: 0.68)) {
            HStack(spacing: 9) {
                Image(systemName: "appletvremote.gen3")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(model.connected ? Color(red: 0.36, green: 0.92, blue: 0.64) : theme.text(0.35))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.connected ? "Siri Remote 已连接" : "等待 Siri Remote")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(theme.text(0.85))
                    Text(model.connected ? "\(model.remoteName) · \(model.batteryText)" : "Back + 音量+ 按住 5 秒配对")
                        .font(.system(size: 7.5))
                        .foregroundStyle(theme.text(0.35))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)
                Button("蓝牙") {
                    model.openBluetoothSettings()
                }
                .buttonStyle(.plain)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(theme.text(0.55))
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(
                    Capsule()
                        .fill(theme.text(0.06))
                        .overlay(Capsule().strokeBorder(theme.text(0.07), lineWidth: 1))
                )
            }
        }
    }

    private var mappingCard: some View {
        VibeCard(accent: Color(red: 0.46, green: 0.52, blue: 0.94)) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("遥控器映射")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(theme.text(0.4))
                    Spacer()
                    Text(model.lastAction.isEmpty ? "待命" : model.lastAction)
                        .font(.system(size: 7))
                        .foregroundStyle(theme.text(0.28))
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        MappingRow(key: "Siri", action: bindings.action(for: .siri).shortLabel)
                        MappingRow(key: "TV", action: bindings.action(for: .tv).shortLabel)
                        MappingRow(key: "播放", action: bindings.action(for: .playPause).shortLabel)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        MappingRow(key: "返回", action: bindings.action(for: .back).shortLabel)
                        MappingRow(key: "方向", action: directionLabel)
                        MappingRow(key: "Select", action: bindings.action(for: .select).shortLabel)
                    }
                }
            }
        }
    }

    private var directionLabel: String {
        let action = bindings.action(for: .ringUp)
        switch action {
        case .moveUp, .moveDown, .moveLeft, .moveRight: return "鼠标"
        case .arrowUp, .arrowDown, .arrowLeft, .arrowRight: return "方向键"
        case .scrollUp, .scrollDown: return "滚动"
        default: return action.shortLabel
        }
    }

    private var permissionsRow: some View {
        HStack(spacing: 6) {
            PermissionChip(title: "辅助功能", granted: model.accessibilityGranted) {
                if model.accessibilityGranted {
                    model.openAccessibilitySettings()
                } else {
                    model.requestAccessibility()
                }
            }
            PermissionChip(title: "输入监控", granted: model.inputMonitoringGranted) {
                if model.inputMonitoringGranted {
                    model.openInputMonitoringSettings()
                } else {
                    model.requestInputMonitoring()
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model.isDictating ? Color(red: 1.0, green: 0.58, blue: 0.25) : Color(red: 0.36, green: 0.92, blue: 0.64))
                .frame(width: 4, height: 4)
            Text(model.status)
                .font(.system(size: 7.5))
                .foregroundStyle(theme.text(0.32))
                .lineLimit(1)
            Spacer()
            if !model.lastRaw.isEmpty {
                Text(model.lastRaw)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(theme.text(0.2))
            }
            Text("VibeRemote 1.7")
                .font(.system(size: 7))
                .foregroundStyle(theme.text(0.2))
        }
        .padding(.horizontal, 13)
        .padding(.top, 7)
        .padding(.bottom, 9)
    }
}

struct VibeRemoteMenuLabel: View {
    @ObservedObject var model: VibeRemoteModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: model.isDictating ? "mic.fill" : "appletvremote.gen3")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(model.isDictating ? Color.orange : Color.primary)
            Circle()
                .fill(model.connected ? Color(red: 0.36, green: 0.92, blue: 0.64) : Color.gray.opacity(0.5))
                .frame(width: 4, height: 4)
        }
        .help(model.connected ? "VibeRemote — Siri Remote 已连接" : "VibeRemote — 等待 Siri Remote")
    }
}
