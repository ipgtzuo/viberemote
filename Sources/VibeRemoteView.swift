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
                    theme.panelTop.opacity(0.985),
                    theme.panelBottom.opacity(0.99)
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
                .allowsHitTesting(false)
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
                .allowsHitTesting(false)
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
                .foregroundStyle(theme.label(0.55))
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
                    .foregroundStyle(theme.label(granted ? 0.6 : 0.8))
                Text(granted ? "已授权" : "去授权")
                    .font(.system(size: 7))
                    .foregroundStyle(theme.label(0.32))
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
    @State private var showRemotePicker = false
    @State private var showModePicker = false
    @State private var actionEditor: RemoteButton?
    @Environment(\.vibePreview) private var previewMode
    @Environment(\.colorScheme) private var systemScheme

    private var resolvedScheme: ColorScheme { model.appearanceMode.colorScheme ?? systemScheme }
    private var theme: VibeTheme { VibeTheme(resolvedScheme) }

    private var displayKind: RemoteKind {
        model.resolvedRemoteKind
    }

    private var remoteStatusDetail: String {
        if model.selectedRemoteConnected {
            if displayKind == .xiaomi {
                return "小米 RC003-MS · 蓝牙"
            }
            let name = model.remoteName(for: .apple)
            return "\(name) · \(model.batteryText)"
        }
        if model.connected, let actual = model.connectedRemoteKind {
            return "\(actual.shortLabel) 已连接 · 等待 \(displayKind.shortLabel)"
        }
        return "打开蓝牙并唤醒"
    }

    private var remoteDisplayName: String {
        switch displayKind {
        case .apple: return "Siri Remote A2540"
        case .xiaomi: return "小米遥控器 2 Pro"
        }
    }

    private var voiceKeyLabel: String {
        displayKind == .xiaomi ? "语音" : "Siri"
    }

    private var presetDisplay: String {
        bindings.activePreset?.title ?? "自定义"
    }

    private var sendHint: String {
        let action = bindings.action(for: .tv)
        switch action {
        case .send: return "松开 TV 发送"
        case .sendCommandReturn: return "松开 TV ⌘发送"
        default: return "松开 TV \(action.shortLabel)"
        }
    }

    private var mappingButtons: [RemoteButton] {
        [.siri, .tv, .select, .back, .playPause, .ringUp, .ringDown, .ringLeft, .ringRight]
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 8) {
                voiceCard
                statusRow
                mappingCard
                permissionsRow
            }
            .padding(.horizontal, 14)

            Spacer(minLength: 4)
            footer
        }
        .frame(width: 360, height: 410)
        .background(VibePanelBackground())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.text(0.09), lineWidth: 1)
        }
        .environment(\.colorScheme, resolvedScheme)
        .preferredColorScheme(model.preferredColorScheme)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.44, green: 0.50, blue: 1.0),
                                Color(red: 0.80, green: 0.37, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RemoteGlyph(kind: displayKind)
                    .frame(width: 22, height: 24)
                    .foregroundStyle(.white.opacity(0.94))
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("VibeRemote")
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 5) {
                    Circle()
                        .fill(model.selectedRemoteConnected ? Color(red: 0.36, green: 0.92, blue: 0.64) : theme.text(0.25))
                        .frame(width: 4, height: 4)
                    Text(model.selectedRemoteConnected ? remoteDisplayName : (model.connected ? "等待 \(displayKind.shortLabel)" : "等待遥控器"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.label(0.48))
                    Text("· \(model.modeDisplay)")
                        .font(.system(size: 8))
                        .foregroundStyle(theme.label(0.3))
                }
            }

            Spacer(minLength: 4)

            Text(model.selectedRemoteConnected ? "已连接" : "未连接")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(theme.label(model.selectedRemoteConnected ? 0.55 : 0.34))
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(
                    Capsule()
                        .fill(theme.text(0.055))
                        .overlay(Capsule().strokeBorder(theme.text(0.07), lineWidth: 1))
                )

            if previewMode {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.label(0.45))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(theme.text(0.055)))
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
                    Button("语音自检…") { model.openVoiceSelfTest() }
                    Button("首次设置向导…") { model.showOnboarding() }
                    Button("打开按键映射…") { model.openMappingSettings() }
                    Button("重新连接遥控器") { model.restartRemote() }
                    Divider()
                    Button("打开辅助功能设置") { model.openAccessibilitySettings() }
                    Button("打开输入监控设置") { model.openInputMonitoringSettings() }
                    Button("打开蓝牙设置") { model.openBluetoothSettings() }
                    Divider()
                    Button("退出 VibeRemote") { model.quit() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.label(0.45))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(theme.text(0.055))
                                .overlay(Circle().strokeBorder(theme.text(0.07), lineWidth: 1))
                        )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var voiceCard: some View {
        let listening = model.isDictating
        let accent = listening ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color(red: 0.44, green: 0.55, blue: 1.0)
        return VibeCard(accent: accent) {
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
                        .frame(width: 42, height: 42)
                    Image(systemName: listening ? "waveform" : "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(listening ? "正在听写…" : (displayKind == .xiaomi ? "按一下语音键开始" : "按一下 Siri 开始"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(listening ? Color(red: 1.0, green: 0.74, blue: 0.45) : theme.text(0.92))
                    Text(listening ? "再按一次结束" : (bindings.action(for: .siri) == .dictation ? "按下开始，再按结束" : "\(sendHint) · \(model.resolvedMode.label)"))
                        .font(.system(size: 8))
                        .foregroundStyle(theme.label(0.36))
                        .lineLimit(1)
                }

                Spacer(minLength: 2)

                VStack(alignment: .trailing, spacing: 3) {
                    Keycap(text: voiceKeyLabel, accent: theme.primary)
                    Text("切换")
                        .font(.system(size: 7))
                        .foregroundStyle(theme.label(0.28))
                }
            }
        }
    }

    private var statusRow: some View {
        VibeCard(accent: Color(red: 0.52, green: 0.56, blue: 0.94)) {
            HStack(spacing: 0) {
                ZStack {
                    HStack(spacing: 8) {
                        RemoteGlyph(kind: displayKind)
                            .foregroundStyle(model.selectedRemoteConnected ? Color(red: 0.36, green: 0.92, blue: 0.64) : theme.text(0.32))
                            .frame(width: 16, height: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("遥控器")
                                .font(.system(size: 7.0))
                                .foregroundStyle(theme.label(0.34))
                            Text(model.selectedRemoteConnected ? "已连接" : "等待连接")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(theme.label(0.84))
                            Text(remoteStatusDetail)
                                .font(.system(size: 7.0))
                                .foregroundStyle(theme.label(0.33))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(theme.label(0.28))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 8)

                    Button {
                        showRemotePicker = true
                    } label: {
                        Color.clear
                            .frame(width: 150, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showRemotePicker, arrowEdge: .bottom) {
                        remotePicker
                    }
                    .help("选择遥控器布局")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 6)

                Rectangle()
                    .fill(theme.divider)
                    .frame(width: 1)
                    .padding(.vertical, 2)


                ZStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("输入目标")
                            .font(.system(size: 7.0))
                            .foregroundStyle(theme.label(0.34))

                        HStack(spacing: 5) {
                            modeLogo(model.resolvedMode)
                            Text(model.resolvedMode.label)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(theme.label(0.84))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 6.5, weight: .semibold))
                                .foregroundStyle(theme.label(0.28))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(model.selectedMode.isAutomatic ? "跟随前台应用" : "固定模式")
                            .font(.system(size: 7.0))
                            .foregroundStyle(theme.label(0.33))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        showModePicker = true
                    } label: {
                        Color.clear
                            .frame(width: 150, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showModePicker, arrowEdge: .bottom) {
                        modePicker
                    }
                    .help("选择输入目标")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var mappingCard: some View {
        VibeCard(accent: Color(red: 0.46, green: 0.52, blue: 0.94)) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text("按键映射")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(theme.label(0.4))
                    Text(presetDisplay)
                        .font(.system(size: 7))
                        .foregroundStyle(theme.label(0.3))
                    Spacer(minLength: 0)
                    if !model.lastAction.isEmpty {
                        Text(model.lastAction)
                            .font(.system(size: 7))
                            .foregroundStyle(theme.label(0.28))
                    }
                    Button("编辑") { model.openMappingSettings() }
                        .buttonStyle(.plain)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(theme.label(0.55))
                }

                HStack(spacing: 5) {
                    ForEach(ButtonPreset.allCases) { preset in
                        presetChip(preset)
                    }
                    if bindings.activePreset == nil {
                        Text("自定义")
                            .font(.system(size: 7))
                            .foregroundStyle(theme.label(0.3))
                    }
                    Spacer(minLength: 0)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3),
                    spacing: 5
                ) {
                    ForEach(mappingButtons) { button in
                        mappingCell(button)
                    }
                }
            }
        }
    }

    private func presetChip(_ preset: ButtonPreset) -> some View {
        let active = bindings.activePreset == preset
        return Button {
            bindings.apply(preset)
        } label: {
            Text(preset.title)
                .font(.system(size: 7.5, weight: .medium))
                .foregroundStyle(active ? theme.selectedText : theme.text(0.52))
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(
                    Capsule()
                        .fill(active ? theme.selectedFill : theme.controlFill)
                        .overlay(
                            Capsule().strokeBorder(active ? .clear : theme.controlStroke, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func modeLogo(_ mode: AppMode) -> some View {
        if let name = mode.logoName, let image = NSImage(named: name) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 12, height: 12)
                .fixedSize()
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .opacity(0.95)
        } else {
            Image(systemName: mode.symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(red: 0.66, green: 0.54, blue: 1.0))
        }
    }

    private func mappingCell(_ button: RemoteButton) -> some View {
        let action = bindings.action(for: button)
        let cell = HStack(spacing: 4) {
            Keycap(text: buttonTitle(button))
            Text(actionDisplay(action))
                .font(.system(size: 7.5, weight: .medium))
                .foregroundStyle(action == .none ? theme.label(0.25) : theme.label(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(theme.controlFill.opacity(0.65))
        )

        return ZStack {
            cell

            Button {
                actionEditor = button
            } label: {
                Color.clear
                    .frame(width: 96, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: Binding(
                get: { actionEditor == button },
                set: { presented in
                    if !presented, actionEditor == button { actionEditor = nil }
                }
            ), arrowEdge: .bottom) {
                actionPicker(for: button)
            }
            .help("点击修改按键动作")
        }
    }

    private func actionDisplay(_ action: ButtonAction) -> String {
        switch action {
        case .dictation: return "听写"
        case .arrowUp: return "上键"
        case .arrowDown: return "下键"
        case .arrowLeft: return "左键"
        case .arrowRight: return "右键"
        default: return action.shortLabel
        }
    }

    private func buttonTitle(_ button: RemoteButton) -> String {
        switch button {
        case .siri: return displayKind == .xiaomi ? "语音" : "Siri"
        case .playPause: return displayKind == .xiaomi ? "菜单" : "播放"
        case .select: return "Select"
        case .tv: return "TV"
        case .back: return "返回"
        case .ringUp: return "↑"
        case .ringDown: return "↓"
        case .ringLeft: return "←"
        case .ringRight: return "→"
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

    private var remotePicker: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(RemoteType.allCases) { type in
                pickerRow(title: type.label, selected: model.remoteType == type) {
                    model.setRemoteType(type)
                    showRemotePicker = false
                }
            }
        }
        .padding(8)
        .frame(width: 190)
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(AppMode.allCases) { mode in
                modePickerRow(mode)
            }
        }
        .padding(8)
        .frame(width: 170)
    }

    private func actionPicker(for button: RemoteButton) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(ButtonAction.allCases) { action in
                    pickerRow(title: action.label, selected: bindings.action(for: button) == action) {
                        bindings.set(action, for: button)
                        actionEditor = nil
                    }
                }
            }
            .padding(6)
        }
        .frame(width: 190, height: 300)
    }

    private func modePickerRow(_ mode: AppMode) -> some View {
        let selected = model.selectedMode == mode
        return Button {
            model.setMode(mode)
            showModePicker = false
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .semibold))
                    .opacity(selected ? 1 : 0)
                    .frame(width: 10)
                modeLogo(mode)
                Text(mode.label)
                    .font(.system(size: 10))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .frame(height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pickerRow(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .semibold))
                    .opacity(selected ? 1 : 0)
                    .frame(width: 10)
                Text(title)
                    .font(.system(size: 10))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .frame(height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model.isDictating ? Color(red: 1.0, green: 0.58, blue: 0.25) : Color(red: 0.36, green: 0.92, blue: 0.64))
                .frame(width: 4, height: 4)
            Text(model.status)
                .font(.system(size: 7.5))
                .foregroundStyle(theme.label(0.32))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.8.3")")
                .font(.system(size: 7))
                .foregroundStyle(theme.label(0.22))
        }
        .padding(.horizontal, 14)
        .padding(.top, 7)
        .padding(.bottom, 10)
    }
}


struct RemoteGlyph: View {
    let kind: RemoteKind

    var body: some View {
        if kind == .apple {
            Image(systemName: "appletvremote.gen3")
                .resizable()
                .scaledToFit()
        } else {
            GeometryReader { proxy in
                let line = max(0.75, min(proxy.size.width, proxy.size.height) * 0.055)
                XiaomiRemoteGlyph()
                    .stroke(style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct XiaomiRemoteGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.addRoundedRect(
            in: CGRect(x: rect.minX + w * 0.18, y: rect.minY + h * 0.03,
                       width: w * 0.64, height: h * 0.94),
            cornerSize: CGSize(width: w * 0.20, height: w * 0.20)
        )

        path.addEllipse(in: CGRect(x: rect.minX + w * 0.33, y: rect.minY + h * 0.11,
                                   width: w * 0.34, height: w * 0.34))

        path.addRoundedRect(
            in: CGRect(x: rect.minX + w * 0.44, y: rect.minY + h * 0.64,
                       width: w * 0.12, height: h * 0.18),
            cornerSize: CGSize(width: w * 0.06, height: w * 0.06)
        )

        return path
    }
}

struct VibeRemoteMenuLabel: View {
    @ObservedObject var model: VibeRemoteModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: model.resolvedRemoteKind == .apple ? "appletvremote.gen3" : "appletvremote.gen4")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(model.isDictating ? Color.orange : Color.primary)
            Circle()
                .fill(model.connected ? Color(red: 0.36, green: 0.92, blue: 0.64) : Color.gray.opacity(0.5))
                .frame(width: 4, height: 4)
        }
        .help(model.selectedRemoteConnected
              ? "VibeRemote — \(model.resolvedRemoteKind.label) 已连接"
              : "VibeRemote — 等待 \(model.resolvedRemoteKind.shortLabel)")
    }
}
