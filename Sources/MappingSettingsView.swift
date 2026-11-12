import SwiftUI
import AppKit
import Foundation

private enum MappingMode: String, CaseIterable, Identifiable {
    case manual
    case physical

    var id: String { rawValue }
    var label: String {
        switch self {
        case .manual: return "手动列表"
        case .physical: return "实体遥控器"
        }
    }
}

private enum MappingSide {
    case left
    case right
}

private struct MappingEntry: Identifiable {
    let button: RemoteButton
    let side: MappingSide
    let y: CGFloat
    let source: CGPoint

    var id: String { button.rawValue }

    var title: String {
        switch button {
        case .ringUp: return "方向上"
        case .ringDown: return "方向下"
        case .ringLeft: return "方向左"
        case .ringRight: return "方向右"
        default: return button.label
        }
    }
}

private let mappingEntries: [MappingEntry] = [
    .init(button: .ringUp, side: .left, y: 80, source: CGPoint(x: 450, y: 50)),
    .init(button: .ringLeft, side: .left, y: 175, source: CGPoint(x: 403, y: 97)),
    .init(button: .select, side: .left, y: 270, source: CGPoint(x: 450, y: 97)),
    .init(button: .back, side: .left, y: 365, source: CGPoint(x: 415.5, y: 199)),
    .init(button: .playPause, side: .left, y: 460, source: CGPoint(x: 415.5, y: 265)),
    .init(button: .tv, side: .right, y: 120, source: CGPoint(x: 484.5, y: 199)),
    .init(button: .siri, side: .right, y: 230, source: CGPoint(x: 524, y: 181)),
    .init(button: .ringRight, side: .right, y: 340, source: CGPoint(x: 497, y: 97)),
    .init(button: .ringDown, side: .right, y: 450, source: CGPoint(x: 450, y: 205))
]

private let xiaomiMappingEntries: [MappingEntry] = [
    .init(button: .siri, side: .left, y: 80, source: CGPoint(x: 450, y: 40)),
    .init(button: .ringUp, side: .left, y: 155, source: CGPoint(x: 450, y: 72)),
    .init(button: .ringLeft, side: .left, y: 240, source: CGPoint(x: 405, y: 125)),
    .init(button: .select, side: .left, y: 325, source: CGPoint(x: 450, y: 125)),
    .init(button: .back, side: .left, y: 410, source: CGPoint(x: 420, y: 250)),
    .init(button: .tv, side: .right, y: 140, source: CGPoint(x: 450, y: 250)),
    .init(button: .ringRight, side: .right, y: 250, source: CGPoint(x: 495, y: 125)),
    .init(button: .ringDown, side: .right, y: 370, source: CGPoint(x: 450, y: 178))
]

private func actionColor(_ action: ButtonAction, isDark: Bool) -> Color {
    switch action {
    case .dictation:
        return isDark ? Color(red: 1.0, green: 0.66, blue: 0.28) : Color(red: 0.82, green: 0.43, blue: 0.08)
    case .send, .sendCommandReturn:
        return isDark ? Color(red: 0.35, green: 0.90, blue: 0.64) : Color(red: 0.08, green: 0.55, blue: 0.33)
    case .stop:
        return isDark ? Color(red: 1.0, green: 0.40, blue: 0.38) : Color(red: 0.80, green: 0.16, blue: 0.18)
    case .leftClick, .rightClick:
        return isDark ? Color(red: 0.42, green: 0.60, blue: 1.0) : Color(red: 0.16, green: 0.34, blue: 0.80)
    case .moveUp, .moveDown, .moveLeft, .moveRight:
        return isDark ? Color(red: 0.32, green: 0.82, blue: 0.96) : Color(red: 0.02, green: 0.50, blue: 0.66)
    case .scrollUp, .scrollDown, .toggleScroll:
        return isDark ? Color(red: 0.58, green: 0.48, blue: 1.0) : Color(red: 0.38, green: 0.26, blue: 0.82)
    case .arrowUp, .arrowDown, .arrowLeft, .arrowRight:
        return isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.45)
    case .none:
        return isDark ? Color.white.opacity(0.25) : Color.black.opacity(0.22)
    }
}

private struct MappingPanelBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = VibeTheme(colorScheme)
        ZStack {
            LinearGradient(
                colors: [
                    theme.panelTop,
                    theme.panelBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [theme.glowBlue, .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 500
            )
            RadialGradient(
                colors: [theme.glowPurple, .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 460
            )
        }
    }
}

private struct RemoteFaceKey: View {
    var systemName: String
    var iconSize: CGFloat = 15
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.23, green: 0.235, blue: 0.25),
                        Color(red: 0.12, green: 0.125, blue: 0.14),
                        Color(red: 0.075, green: 0.08, blue: 0.09)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.34),
                    startRadius: 0,
                    endRadius: 30
                )
            )
            .overlay(Circle().strokeBorder(.black.opacity(0.55), lineWidth: 1))
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(Color(red: 0.72, green: 0.74, blue: 0.78))
            )
            .overlay(
                Circle().strokeBorder(selected ? Color(red: 1.0, green: 0.70, blue: 0.30) : .clear, lineWidth: 2)
            )
            .frame(width: 46, height: 46)
            .shadow(color: .black.opacity(0.28), radius: 2, y: 2)
            .onTapGesture(perform: action)
    }
}

private struct RingKey: Identifiable {
    let button: RemoteButton
    let point: CGPoint
    let symbol: String
    var id: String { button.rawValue }
}

private let ringKeys: [RingKey] = [
    RingKey(button: .ringUp, point: CGPoint(x: 75, y: 50), symbol: "chevron.up"),
    RingKey(button: .ringLeft, point: CGPoint(x: 28, y: 97), symbol: "chevron.left"),
    RingKey(button: .ringRight, point: CGPoint(x: 122, y: 97), symbol: "chevron.right"),
    RingKey(button: .ringDown, point: CGPoint(x: 75, y: 205), symbol: "chevron.down")
]

struct RemoteDiagram: View {
    var selected: RemoteButton
    var onSelect: (RemoteButton) -> Void

    private let bodyShape = RoundedRectangle(cornerRadius: 34, style: .continuous)

    var body: some View {
        ZStack {
            bodyShape
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.95, green: 0.96, blue: 0.97), location: 0),
                            .init(color: Color(red: 0.85, green: 0.86, blue: 0.89), location: 0.46),
                            .init(color: Color(red: 0.71, green: 0.73, blue: 0.77), location: 1)
                        ],
                        startPoint: UnitPoint(x: 0.35, y: 0),
                        endPoint: UnitPoint(x: 0.65, y: 1)
                    )
                )
                .overlay(
                    bodyShape.fill(
                        LinearGradient(
                            colors: [.clear, Color(red: 0.36, green: 0.39, blue: 0.44).opacity(0.24)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                )
                .overlay(bodyShape.strokeBorder(Color(red: 0.55, green: 0.58, blue: 0.63), lineWidth: 1))
                .overlay(
                    bodyShape.strokeBorder(.white.opacity(0.55), lineWidth: 1)
                        .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
                )
                .shadow(color: .black.opacity(0.55), radius: 20, y: 14)

            Image(systemName: "mic")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(Color(red: 0.55, green: 0.57, blue: 0.61))
                .position(x: 75, y: 22)

            Image(systemName: "power")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.46, green: 0.48, blue: 0.52))
                .frame(width: 20, height: 20)
                .position(x: 124.5, y: 29.5)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.70, green: 0.72, blue: 0.76), Color(red: 0.55, green: 0.58, blue: 0.63)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: 62)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(selected == .siri ? Color(red: 1.0, green: 0.70, blue: 0.30) : .clear, lineWidth: 2)
                )
                .onTapGesture { onSelect(.siri) }
                .position(x: 149, y: 181)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.10, green: 0.105, blue: 0.12), Color(red: 0.045, green: 0.048, blue: 0.055)],
                            center: UnitPoint(x: 0.5, y: 0.4),
                            startRadius: 0,
                            endRadius: 90
                        )
                    )
                    .overlay(Circle().strokeBorder(.black.opacity(0.8), lineWidth: 1))

                Circle()
                    .strokeBorder(.white.opacity(0.045), lineWidth: 1)
                    .padding(20)

                ForEach(ringKeys) { item in
                    Text(item.symbol == "chevron.up" ? "▲" : item.symbol == "chevron.down" ? "▼" : item.symbol == "chevron.left" ? "◀" : "▶")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(red: 0.62, green: 0.65, blue: 0.70).opacity(0.55))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().strokeBorder(selected == item.button ? Color(red: 1.0, green: 0.70, blue: 0.30) : .clear, lineWidth: 1.5)
                        )
                        .position(item.point)
                        .onTapGesture { onSelect(item.button) }
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.095, green: 0.10, blue: 0.11), Color(red: 0.055, green: 0.058, blue: 0.065)],
                            center: UnitPoint(x: 0.5, y: 0.42),
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .overlay(Circle().strokeBorder(.white.opacity(0.04), lineWidth: 1))
                    .overlay(
                        Circle().strokeBorder(selected == .select ? Color(red: 1.0, green: 0.70, blue: 0.30) : .clear, lineWidth: 2)
                    )
                    .frame(width: 52, height: 52)
                    .onTapGesture { onSelect(.select) }
            }
            .frame(width: 122, height: 122)
            .shadow(color: .black.opacity(0.32), radius: 3, y: 3)
            .position(x: 75, y: 97)

            RemoteFaceKey(systemName: "chevron.backward", selected: selected == .back, action: { onSelect(.back) })
                .position(x: 40.5, y: 199)

            RemoteFaceKey(systemName: "tv", iconSize: 16, selected: selected == .tv, action: { onSelect(.tv) })
                .position(x: 109.5, y: 199)

            RemoteFaceKey(systemName: "playpause", selected: selected == .playPause, action: { onSelect(.playPause) })
                .position(x: 40.5, y: 265)

            ZStack {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.22, green: 0.23, blue: 0.25), location: 0),
                                .init(color: Color(red: 0.12, green: 0.125, blue: 0.14), location: 0.5),
                                .init(color: Color(red: 0.075, green: 0.08, blue: 0.09), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(.black.opacity(0.55), lineWidth: 1))
                Rectangle().fill(.white.opacity(0.05)).frame(height: 1)
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.72, green: 0.74, blue: 0.78))
                    .offset(y: -28)
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.72, green: 0.74, blue: 0.78))
                    .offset(y: 28)
            }
            .frame(width: 46, height: 112)
            .position(x: 109.5, y: 298)

            Image(systemName: "speaker.slash")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.72, green: 0.74, blue: 0.78))
                .frame(width: 46, height: 46)
                .background(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.23, green: 0.235, blue: 0.25), Color(red: 0.075, green: 0.08, blue: 0.09)],
                                center: UnitPoint(x: 0.5, y: 0.34),
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .overlay(Circle().strokeBorder(.black.opacity(0.55), lineWidth: 1))
                )
                .position(x: 40.5, y: 331)

            VStack(spacing: 2) {
                Text("A2854")
                    .font(.system(size: 5.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.38, green: 0.40, blue: 0.44).opacity(0.55))
                Text("SIRI REMOTE")
                    .font(.system(size: 4.5, weight: .medium, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(Color(red: 0.38, green: 0.40, blue: 0.44).opacity(0.35))
            }
            .position(x: 75, y: 470)
        }
        .frame(width: 150, height: 512)
    }
}

private struct XiaomiRingKey: Identifiable {
    let button: RemoteButton
    let point: CGPoint
    let symbol: String
    var id: String { button.rawValue }
}

struct XiaomiRemoteDiagram: View {
    var selected: RemoteButton
    var onSelect: (RemoteButton) -> Void

    private let bodyShape = RoundedRectangle(cornerRadius: 34, style: .continuous)
    private let accent = Color(red: 1.0, green: 0.66, blue: 0.28)

    private let ring: [XiaomiRingKey] = [
        XiaomiRingKey(button: .ringUp, point: CGPoint(x: 60, y: 22), symbol: "▲"),
        XiaomiRingKey(button: .ringLeft, point: CGPoint(x: 22, y: 60), symbol: "◀"),
        XiaomiRingKey(button: .ringRight, point: CGPoint(x: 98, y: 60), symbol: "▶"),
        XiaomiRingKey(button: .ringDown, point: CGPoint(x: 60, y: 98), symbol: "▼")
    ]

    var body: some View {
        ZStack {
            bodyShape
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.16, green: 0.17, blue: 0.19), location: 0),
                            .init(color: Color(red: 0.075, green: 0.08, blue: 0.09), location: 0.5),
                            .init(color: Color(red: 0.045, green: 0.05, blue: 0.058), location: 1)
                        ],
                        startPoint: UnitPoint(x: 0.28, y: 0),
                        endPoint: UnitPoint(x: 0.72, y: 1)
                    )
                )
                .overlay(bodyShape.strokeBorder(.white.opacity(0.10), lineWidth: 1))
                .overlay(bodyShape.strokeBorder(.black.opacity(0.7), lineWidth: 1).padding(1))
                .shadow(color: .black.opacity(0.5), radius: 20, y: 14)
                .frame(width: 150, height: 470)
                .position(x: 75, y: 255)

            // Top microphone and power markings.
            RemoteFaceKey(systemName: "mic", iconSize: 12, selected: selected == .siri, action: { onSelect(.siri) })
                .position(x: 40, y: 48)
            Image(systemName: "power")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.34))
                .position(x: 110, y: 48)

            // Circular direction pad with OK in the center.
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.12, green: 0.125, blue: 0.14), Color(red: 0.045, green: 0.048, blue: 0.055)],
                            center: UnitPoint(x: 0.5, y: 0.38),
                            startRadius: 0,
                            endRadius: 70
                        )
                    )
                    .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                    .overlay(Circle().strokeBorder(.black.opacity(0.75), lineWidth: 1).padding(1))

                Circle()
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                    .padding(15)

                ForEach(ring) { item in
                    Text(item.symbol)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.48))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle().strokeBorder(selected == item.button ? accent : .clear, lineWidth: 1.5)
                        )
                        .position(item.point)
                        .onTapGesture { onSelect(item.button) }
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.16, green: 0.17, blue: 0.19), Color(red: 0.06, green: 0.065, blue: 0.075)],
                            center: UnitPoint(x: 0.5, y: 0.42),
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .overlay(Circle().strokeBorder(.white.opacity(0.10), lineWidth: 1))
                    .overlay(Circle().strokeBorder(selected == .select ? accent : .clear, lineWidth: 2))
                    .frame(width: 50, height: 50)
                    .onTapGesture { onSelect(.select) }
            }
            .frame(width: 120, height: 120)
            .position(x: 75, y: 125)
            .shadow(color: .black.opacity(0.35), radius: 4, y: 3)

            // Back / home / menu row.
            RemoteFaceKey(systemName: "chevron.backward", iconSize: 13, selected: selected == .back, action: { onSelect(.back) })
                .position(x: 40, y: 250)
            RemoteFaceKey(systemName: "house", iconSize: 13, selected: selected == .tv, action: { onSelect(.tv) })
                .position(x: 75, y: 250)
            RemoteFaceKey(systemName: "line.3.horizontal", iconSize: 13, selected: false, action: {})
                .position(x: 110, y: 250)

            // Volume rocker is decorative for now.
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .frame(width: 5, height: 64)
                .overlay(
                    VStack(spacing: 10) {
                        Text("+").font(.system(size: 9, weight: .semibold))
                        Text("−").font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.35))
                )
                .position(x: 145, y: 160)

            VStack(spacing: 2) {
                Text("RC003")
                    .font(.system(size: 5.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.32))
                Text("MI REMOTE")
                    .font(.system(size: 4.5, weight: .medium, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.20))
            }
            .position(x: 75, y: 455)
        }
        .frame(width: 150, height: 512)
    }
}

struct MappingSettingsView: View {
    @ObservedObject var model: VibeRemoteModel
    @ObservedObject var bindings: ButtonBindingStore
    @State private var mode: MappingMode = .manual
    @State private var selected: RemoteButton = .siri
    @Environment(\.colorScheme) private var systemScheme

    private var resolvedScheme: ColorScheme { model.appearanceMode.colorScheme ?? systemScheme }
    private var theme: VibeTheme { VibeTheme(resolvedScheme) }

    private var isXiaomi: Bool {
        model.resolvedRemoteKind == .xiaomi
            || ProcessInfo.processInfo.arguments.contains("--xiaomi-preview")
    }

    private var activeEntries: [MappingEntry] {
        isXiaomi ? xiaomiMappingEntries : mappingEntries
    }

    private var remoteLayoutName: String {
        isXiaomi ? "Xiaomi RC003" : "Siri Remote A2854"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            toolbar
            diagram
            inspector
            footer
        }
        .frame(width: 900, height: 720)
        .background(MappingPanelBackground())
        .environment(\.colorScheme, resolvedScheme)
        .preferredColorScheme(model.preferredColorScheme)
        .onReceive(model.physicalButtonEvents) { button in
            selected = button
        }
        .onChange(of: isXiaomi) { xiaomi in
            if xiaomi, !xiaomiMappingEntries.contains(where: { $0.button == selected }) {
                selected = .siri
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("遥控器映射")
                    .font(.system(size: 20, weight: .semibold))
                Text("正在编辑：\(model.modeDisplay) · 当前布局：\(remoteLayoutName)")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.text(0.42))
            }

            Spacer()

            connectionBadge
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var connectionBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.connected ? Color(red: 0.22, green: 0.78, blue: 0.48) : theme.text(0.24))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(model.connected ? "已连接" : "未连接")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(theme.text(model.connected ? 0.82 : 0.48))
                Text(connectionDetail)
                    .font(.system(size: 8))
                    .foregroundStyle(theme.text(0.40))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(theme.text(0.045))
                .overlay(Capsule().strokeBorder(theme.text(0.07), lineWidth: 1))
        )
    }

    private var connectionDetail: String {
        guard model.connected else { return "等待遥控器连接" }
        let transport = model.isWired ? "USB" : "蓝牙"
        let name = model.remoteName.isEmpty ? model.resolvedRemoteKind.label : model.remoteName
        if model.remoteType != .automatic,
           let previewKind = model.remoteType.kind,
           previewKind != model.connectedRemoteKind {
            return "\(name) · \(transport) · 预览 \(previewKind.shortLabel)"
        }
        return "\(name) · \(transport)"
    }

    private var toolbar: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("编辑方式")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(theme.text(0.35))
                HStack(spacing: 2) {
                    ForEach(MappingMode.allCases) { item in
                        Button {
                            mode = item
                        } label: {
                            Text(item.label)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(mode == item ? theme.selectedText : theme.text(0.52))
                                .frame(maxWidth: .infinity, minHeight: 24)
                                .background(
                                    Capsule().fill(mode == item ? theme.selectedFill : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .frame(width: 180)
                .background(
                    Capsule()
                        .fill(theme.text(0.055))
                        .overlay(Capsule().strokeBorder(theme.text(0.07), lineWidth: 1))
                )
            }

            Divider().frame(height: 30).opacity(0.6)

            VStack(alignment: .leading, spacing: 3) {
                Text("遥控器")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(theme.text(0.35))
                Picker("", selection: Binding(
                    get: { model.remoteType },
                    set: { model.setRemoteType($0) }
                )) {
                    ForEach(RemoteType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 200)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("映射方案")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(theme.text(0.35))

                HStack(spacing: 2) {
                    ForEach(ButtonPreset.allCases) { preset in
                        Button {
                            bindings.apply(preset)
                        } label: {
                            Text(preset.title)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(bindings.activePreset == preset ? theme.selectedText : theme.text(0.52))
                                .frame(width: 76, height: 24)
                                .background(
                                    Capsule().fill(bindings.activePreset == preset ? theme.selectedFill : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(preset.detail)
                    }
                }
                .padding(2)
                .background(
                    Capsule()
                        .fill(theme.text(0.055))
                        .overlay(Capsule().strokeBorder(theme.text(0.07), lineWidth: 1))
                )

                HStack(spacing: 8) {
                    Text(bindings.activePreset?.detail ?? "自定义：已单独调整按键")
                        .font(.system(size: 7.5))
                        .foregroundStyle(theme.text(0.38))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Button("恢复默认") { bindings.reset() }
                        .buttonStyle(.plain)
                        .font(.system(size: 8))
                        .foregroundStyle(theme.text(0.38))
                }
                .frame(width: 280, alignment: .trailing)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
    }

    private var diagram: some View {
        let entries = activeEntries
        return ZStack(alignment: .topLeading) {
            Canvas { context, size in
                for entry in entries {
                    let action = bindings.action(for: entry.button)
                    let color = actionColor(action, isDark: theme.isDark)
                    let endX: CGFloat = entry.side == .left ? 330 : 570
                    let end = CGPoint(x: endX, y: entry.y)
                    let mid = CGPoint(x: (entry.source.x + end.x) / 2, y: entry.y)
                    var path = Path()
                    path.move(to: entry.source)
                    path.addCurve(
                        to: end,
                        control1: CGPoint(x: mid.x, y: entry.source.y),
                        control2: CGPoint(x: mid.x, y: end.y)
                    )
                    context.stroke(
                        path,
                        with: .color(color.opacity(selected == entry.button ? 0.95 : 0.28)),
                        lineWidth: selected == entry.button ? 1.8 : 1
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(x: entry.source.x - 2.5, y: entry.source.y - 2.5, width: 5, height: 5)),
                        with: .color(color.opacity(selected == entry.button ? 1 : 0.55))
                    )
                }
            }
            .frame(width: 900, height: 512)
            .allowsHitTesting(false)

            if isXiaomi {
                XiaomiRemoteDiagram(selected: selected) { button in
                    selected = button
                }
                .position(x: 450, y: 256)
            } else {
                RemoteDiagram(selected: selected) { button in
                    selected = button
                }
                .position(x: 450, y: 256)
            }

            ForEach(entries) { entry in
                mappingCard(entry)
                    .frame(width: 280, height: 42)
                    .position(x: entry.side == .left ? 180 : 720, y: entry.y)
            }
        }
        .frame(width: 900, height: 512)
    }

    private func mappingCard(_ entry: MappingEntry) -> some View {
        let action = bindings.action(for: entry.button)
        let isSelected = selected == entry.button
        let color = actionColor(action, isDark: theme.isDark)

        return HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(isSelected ? 0.22 : 0.1))
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(entry.title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(theme.text(0.84))
                    .lineLimit(1)
                Text(entry.button.rawValue)
                    .font(.system(size: 6.5, design: .monospaced))
                    .foregroundStyle(theme.text(0.24))
            }
            .frame(width: 68, alignment: .leading)

            Spacer(minLength: 4)

            if mode == .manual {
                Picker("", selection: Binding(
                    get: { action },
                    set: { bindings.set($0, for: entry.button) }
                )) {
                    ForEach(ButtonAction.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 148)
            } else {
                Text(action.label)
                    .font(.system(size: 9))
                    .foregroundStyle(theme.text(0.56))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(theme.text(isSelected ? 0.085 : 0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            isSelected ? color.opacity(0.55) : theme.text(0.06),
                            lineWidth: isSelected ? 1.2 : 1
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { selected = entry.button }
    }

    private var inspector: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("已选：\(selected.label)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.text(0.78))
                Text(mode == .physical ? "点击左侧按键，或直接按下遥控器实体键" : "下拉框直接修改；也可以点击左侧按键定位")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.text(0.32))
            }

            Spacer()

            Picker("", selection: Binding(
                get: { bindings.action(for: selected) },
                set: { bindings.set($0, for: selected) }
            )) {
                ForEach(ButtonAction.allCases) { action in
                    Text(action.label).tag(action)
                }
            }
            .labelsHidden()
            .frame(width: 250)
            .controlSize(.small)

            Text("选中后立即保存")
                .font(.system(size: 7.5))
                .foregroundStyle(theme.text(0.26))
        }
        .padding(.horizontal, 22)
        .frame(height: 48)
        .background(theme.text(0.025))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model.isMappingWindowOpen ? Color(red: 1.0, green: 0.66, blue: 0.28) : theme.text(0.25))
                .frame(width: 4, height: 4)
            Text("语音使用 Mac 麦克风 + Fn；遥控器麦克风不被 macOS 暴露")
                .font(.system(size: 8))
                .foregroundStyle(theme.text(0.28))
            Spacer()
            Text("VibeRemote 1.7 · 映射立即生效")
                .font(.system(size: 7.5))
                .foregroundStyle(theme.text(0.24))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
    }
}

@MainActor
final class MappingWindowController: NSObject, NSWindowDelegate {
    var onClose: (() -> Void)?
    private var window: NSWindow?

    func show(model: VibeRemoteModel) {
        if window == nil {
            let hosting = NSHostingView(rootView: MappingSettingsView(model: model, bindings: model.bindings))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 720),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "VibeRemote 遥控器映射"
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
            window.titlebarSeparatorStyle = .none
            window.backgroundColor = .windowBackgroundColor
            window.isOpaque = true
            window.contentView = hosting
            window.isReleasedWhenClosed = false
            window.isMovableByWindowBackground = true
            window.center()
            window.delegate = self
            self.window = window
        }
        if let scheme = model.preferredColorScheme {
            window?.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        } else {
            window?.appearance = nil
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
