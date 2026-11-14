import Foundation
import SwiftUI

enum ButtonAction: String, CaseIterable, Identifiable {
    case dictation
    case send
    case sendCommandReturn
    case stop
    case leftClick
    case rightClick
    case moveUp
    case moveDown
    case moveLeft
    case moveRight
    case scrollUp
    case scrollDown
    case toggleScroll
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
    case confirm
    case deleteBackward
    case pageUp
    case pageDown
    case none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dictation: return "语音听写（切换）"
        case .send: return "发送 / Return"
        case .sendCommandReturn: return "发送 / Command+Return"
        case .stop: return "停止 / Escape"
        case .leftClick: return "鼠标左键"
        case .rightClick: return "鼠标右键"
        case .moveUp: return "光标上移"
        case .moveDown: return "光标下移"
        case .moveLeft: return "光标左移"
        case .moveRight: return "光标右移"
        case .scrollUp: return "向上滚动"
        case .scrollDown: return "向下滚动"
        case .toggleScroll: return "切换滚动 / 光标"
        case .arrowUp: return "方向键 ↑"
        case .arrowDown: return "方向键 ↓"
        case .arrowLeft: return "方向键 ←"
        case .arrowRight: return "方向键 →"
        case .confirm: return "确认 / Return"
        case .deleteBackward: return "删除 / Backspace"
        case .pageUp: return "向上翻页 / Page Up"
        case .pageDown: return "向下翻页 / Page Down"
        case .none: return "不操作"
        }
    }

    var shortLabel: String {
        switch self {
        case .dictation: return "语音"
        case .send: return "发送"
        case .sendCommandReturn: return "⌘发送"
        case .stop: return "停止"
        case .leftClick: return "左键"
        case .rightClick: return "右键"
        case .moveUp: return "上移"
        case .moveDown: return "下移"
        case .moveLeft: return "左移"
        case .moveRight: return "右移"
        case .scrollUp: return "上滚"
        case .scrollDown: return "下滚"
        case .toggleScroll: return "滚动"
        case .arrowUp: return "↑"
        case .arrowDown: return "↓"
        case .arrowLeft: return "←"
        case .arrowRight: return "→"
        case .confirm: return "确认"
        case .deleteBackward: return "删除"
        case .pageUp: return "上页"
        case .pageDown: return "下页"
        case .none: return "无"
        }
    }
}

enum ButtonPreset: String, CaseIterable, Identifiable {
    case mouse
    case dshKeyboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mouse: return "鼠标模式"
        case .dshKeyboard: return "DeepSeek 键盘"
        }
    }

    var detail: String {
        switch self {
        case .mouse: return "方向环移动光标 · Select 左键 · 播放切换滚动"
        case .dshKeyboard: return "方向环方向键 · Select/TV 发送 · 返回停止"
        }
    }
}

@MainActor
final class ButtonBindingStore: ObservableObject {
    @Published private(set) var bindings: [RemoteButton: ButtonAction]
    @Published private(set) var activePreset: ButtonPreset?

    private(set) var profile: AppMode = .dsh
    private static let legacyKey = "vibeRemote.buttonBindings"

    init(profile: AppMode = .dsh) {
        self.profile = profile
        bindings = ButtonBindingStore.defaultBindings(for: .mouse)
        activePreset = .mouse
        load(profile: profile)
        refreshActivePreset()
    }

    func action(for button: RemoteButton) -> ButtonAction {
        bindings[button] ?? .none
    }

    func set(_ action: ButtonAction, for button: RemoteButton) {
        bindings[button] = action
        refreshActivePreset()
        save()
    }

    func apply(_ preset: ButtonPreset) {
        bindings = ButtonBindingStore.defaultBindings(for: preset)
        activePreset = preset
        save()
    }

    func switchProfile(_ profile: AppMode) {
        guard profile != self.profile else { return }
        save()
        self.profile = profile
        bindings = ButtonBindingStore.defaultBindings(for: .mouse)
        activePreset = .mouse
        load(profile: profile)
        refreshActivePreset()
    }

    func reset() {
        apply(.mouse)
    }

    private func load(profile: AppMode) {
        if let raw = UserDefaults.standard.dictionary(forKey: storageKey(for: profile)) as? [String: String] {
            load(raw)
            return
        }

        // Migrate the single-profile mapping from 1.4 and earlier into DSH.
        if profile == .dsh,
           let raw = UserDefaults.standard.dictionary(forKey: Self.legacyKey) as? [String: String] {
            load(raw)
            save()
        }
    }

    private func load(_ raw: [String: String]) {
        for (key, value) in raw {
            guard let button = RemoteButton(rawValue: key),
                  let action = ButtonAction(rawValue: value) else { continue }
            bindings[button] = action
        }
    }

    private func save() {
        var raw: [String: String] = [:]
        for (button, action) in bindings {
            raw[button.rawValue] = action.rawValue
        }
        UserDefaults.standard.set(raw, forKey: storageKey(for: profile))
    }

    private func refreshActivePreset() {
        if bindings == ButtonBindingStore.defaultBindings(for: .mouse) {
            activePreset = .mouse
        } else if bindings == ButtonBindingStore.defaultBindings(for: .dshKeyboard) {
            activePreset = .dshKeyboard
        } else {
            activePreset = nil
        }
    }

    private func storageKey(for profile: AppMode) -> String {
        "vibeRemote.buttonBindings.\(profile.rawValue)"
    }

    static func defaultBindings(for preset: ButtonPreset) -> [RemoteButton: ButtonAction] {
        switch preset {
        case .mouse:
            return [
                .siri: .dictation,
                .tv: .send,
                .playPause: .toggleScroll,
                .back: .stop,
                .select: .leftClick,
                .ringUp: .moveUp,
                .ringDown: .moveDown,
                .ringLeft: .moveLeft,
                .ringRight: .moveRight
            ]
        case .dshKeyboard:
            return [
                .siri: .dictation,
                .tv: .send,
                .playPause: .send,
                .back: .stop,
                .select: .send,
                .ringUp: .arrowUp,
                .ringDown: .arrowDown,
                .ringLeft: .arrowLeft,
                .ringRight: .arrowRight
            ]
        }
    }
}
