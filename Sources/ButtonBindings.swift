import Foundation
import SwiftUI

enum ButtonAction: String, CaseIterable, Identifiable {
    case dictation
    case send
    case sendCommandReturn
    case stop
    case leftClick
    case rightClick
    case middleClick
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
    case browserBack
    case showAllWindows
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
        case .middleClick: return "鼠标中键"
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
        case .browserBack: return "浏览器上一页 / ⌘["
        case .showAllWindows: return "显示所有窗口 / Mission Control"
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
        case .middleClick: return "中键"
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
        case .browserBack: return "上一页"
        case .showAllWindows: return "所有窗口"
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
        case .dshKeyboard: return "Agent 模式"
        }
    }

    var detail: String {
        switch self {
        case .mouse: return "方向环移动 · Select 左键/双击窗口 · 返回右键 · TV 中键"
        case .dshKeyboard: return "方向键导航 · Select/TV 发送 · 返回停止"
        }
    }
}

@MainActor
final class ButtonBindingStore: ObservableObject {
    @Published private(set) var bindings: [RemoteButton: ButtonAction]
    @Published private(set) var doubleBindings: [RemoteButton: ButtonAction]
    @Published private(set) var activePreset: ButtonPreset = .mouse

    private(set) var profile: AppMode = .dsh
    private var presetBindings: [ButtonPreset: [RemoteButton: ButtonAction]] = [:]
    private var presetDoubles: [ButtonPreset: [RemoteButton: ButtonAction]] = [:]
    private static let legacyKey = "vibeRemote.buttonBindings"

    init(profile: AppMode = .dsh) {
        self.profile = profile
        bindings = ButtonBindingStore.defaultBindings(for: .mouse)
        doubleBindings = ButtonBindingStore.defaultDoubleBindings(for: .mouse)
        for preset in ButtonPreset.allCases {
            presetBindings[preset] = ButtonBindingStore.defaultBindings(for: preset)
            presetDoubles[preset] = ButtonBindingStore.defaultDoubleBindings(for: preset)
        }
        load(profile: profile)
    }

    func action(for button: RemoteButton) -> ButtonAction {
        bindings[button] ?? .none
    }

    func doubleAction(for button: RemoteButton) -> ButtonAction {
        doubleBindings[button] ?? .none
    }

    func set(_ action: ButtonAction, for button: RemoteButton) {
        bindings[button] = action
        presetBindings[activePreset] = bindings
        save()
    }

    func setDouble(_ action: ButtonAction, for button: RemoteButton) {
        doubleBindings[button] = action
        presetDoubles[activePreset] = doubleBindings
        save()
    }

    func apply(_ preset: ButtonPreset) {
        presetBindings[activePreset] = bindings
        presetDoubles[activePreset] = doubleBindings
        activePreset = preset
        bindings = presetBindings[preset] ?? ButtonBindingStore.defaultBindings(for: preset)
        doubleBindings = presetDoubles[preset] ?? ButtonBindingStore.defaultDoubleBindings(for: preset)
        presetBindings[preset] = bindings
        presetDoubles[preset] = doubleBindings
        save()
    }

    func switchProfile(_ profile: AppMode) {
        guard profile != self.profile else { return }
        save()
        self.profile = profile
        load(profile: profile)
    }

    func reset() {
        bindings = ButtonBindingStore.defaultBindings(for: activePreset)
        doubleBindings = ButtonBindingStore.defaultDoubleBindings(for: activePreset)
        presetBindings[activePreset] = bindings
        presetDoubles[activePreset] = doubleBindings
        save()
    }

    private func load(profile: AppMode) {
        let storedPresets = UserDefaults.standard.dictionary(forKey: presetBindingsKey(for: profile)) as? [String: [String: String]]
        let storedDoubles = UserDefaults.standard.dictionary(forKey: presetDoublesKey(for: profile)) as? [String: [String: String]]
        let savedPreset = UserDefaults.standard.string(forKey: activePresetKey(for: profile)).flatMap(ButtonPreset.init(rawValue:))

        if let storedPresets {
            for preset in ButtonPreset.allCases {
                if let raw = storedPresets[preset.rawValue] {
                    presetBindings[preset] = decode(raw)
                }
            }
            if let storedDoubles {
                for preset in ButtonPreset.allCases {
                    if let raw = storedDoubles[preset.rawValue] {
                        presetDoubles[preset] = decode(raw)
                    }
                }
            }
        } else if let raw = UserDefaults.standard.dictionary(forKey: storageKey(for: profile)) as? [String: String] {
            let legacy = decode(raw)
            let inferred: ButtonPreset
            if let savedPreset {
                inferred = savedPreset
            } else if legacy == ButtonBindingStore.defaultBindings(for: .dshKeyboard) {
                inferred = .dshKeyboard
            } else {
                inferred = .mouse
            }
            presetBindings[inferred] = legacy
            if let doubleRaw = UserDefaults.standard.dictionary(forKey: doubleStorageKey(for: profile)) as? [String: String] {
                presetDoubles[inferred] = decode(doubleRaw)
            }
        } else if profile == .dsh,
                  let raw = UserDefaults.standard.dictionary(forKey: Self.legacyKey) as? [String: String] {
            presetBindings[.mouse] = decode(raw)
        }

        activePreset = savedPreset ?? .mouse
        bindings = presetBindings[activePreset] ?? ButtonBindingStore.defaultBindings(for: activePreset)
        doubleBindings = presetDoubles[activePreset] ?? ButtonBindingStore.defaultDoubleBindings(for: activePreset)
        presetBindings[activePreset] = bindings
        presetDoubles[activePreset] = doubleBindings
        save()
    }

    private func save() {
        presetBindings[activePreset] = bindings
        presetDoubles[activePreset] = doubleBindings

        UserDefaults.standard.set(encode(bindings), forKey: storageKey(for: profile))
        UserDefaults.standard.set(encode(doubleBindings), forKey: doubleStorageKey(for: profile))
        UserDefaults.standard.set(activePreset.rawValue, forKey: activePresetKey(for: profile))

        var allBindings: [String: [String: String]] = [:]
        var allDoubles: [String: [String: String]] = [:]
        for preset in ButtonPreset.allCases {
            allBindings[preset.rawValue] = encode(presetBindings[preset] ?? ButtonBindingStore.defaultBindings(for: preset))
            allDoubles[preset.rawValue] = encode(presetDoubles[preset] ?? ButtonBindingStore.defaultDoubleBindings(for: preset))
        }
        UserDefaults.standard.set(allBindings, forKey: presetBindingsKey(for: profile))
        UserDefaults.standard.set(allDoubles, forKey: presetDoublesKey(for: profile))
    }

    private func encode(_ map: [RemoteButton: ButtonAction]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: map.map { ($0.key.rawValue, $0.value.rawValue) })
    }

    private func decode(_ raw: [String: String]) -> [RemoteButton: ButtonAction] {
        var map: [RemoteButton: ButtonAction] = [:]
        for (key, value) in raw {
            guard let button = RemoteButton(rawValue: key),
                  let action = ButtonAction(rawValue: value) else { continue }
            map[button] = action
        }
        return map
    }

    private func activePresetKey(for profile: AppMode) -> String {
        "vibeRemote.activePreset.\(profile.rawValue)"
    }

    private func presetBindingsKey(for profile: AppMode) -> String {
        "vibeRemote.presetBindings.\(profile.rawValue)"
    }

    private func presetDoublesKey(for profile: AppMode) -> String {
        "vibeRemote.presetDoubles.\(profile.rawValue)"
    }

    private func storageKey(for profile: AppMode) -> String {
        "vibeRemote.buttonBindings.\(profile.rawValue)"
    }

    private func doubleStorageKey(for profile: AppMode) -> String {
        "vibeRemote.doubleBindings.\(profile.rawValue)"
    }

    static func defaultBindings(for preset: ButtonPreset) -> [RemoteButton: ButtonAction] {
        switch preset {
        case .mouse:
            return [
                .siri: .dictation,
                .tv: .middleClick,
                .playPause: .toggleScroll,
                .back: .rightClick,
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

    static func defaultDoubleBindings(for preset: ButtonPreset) -> [RemoteButton: ButtonAction] {
        switch preset {
        case .mouse:
            return [.select: .showAllWindows]
        case .dshKeyboard:
            return [:]
        }
    }
}
