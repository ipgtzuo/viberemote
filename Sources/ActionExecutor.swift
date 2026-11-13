import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics

@MainActor
final class ActionExecutor {
    var onAction: ((String, String) -> Void)?

    var targetBundleID: String? = "com.deepseek.dsh"
    private let bindings: ButtonBindingStore
    private var functionDown = false
    private var dictationViaMenu = false
    private var selfTestDictating = false
    private var selectDown = false
    private var scrollMode = false

    init(bindings: ButtonBindingStore) {
        self.bindings = bindings
    }

    var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    var isSelectDown: Bool { selectDown }
    var isSelfTestDictating: Bool { selfTestDictating }

    func movePointer(dx: CGFloat, dy: CGFloat) {
        guard dx != 0 || dy != 0 else { return }
        let current = cursorPoint
        let destination = CGPoint(x: current.x + dx, y: current.y + dy)
        let type: CGEventType = selectDown ? .leftMouseDragged : .mouseMoved
        postMouse(type, at: destination)
    }

    func scrollBy(dx: CGFloat, dy: CGFloat) {
        scroll(dy: Int32(dy), dx: Int32(dx))
    }

    func clickAtCurrent() {
        guard !selectDown else { return }
        postMouse(.leftMouseDown)
        postMouse(.leftMouseUp)
    }

    func handle(_ button: RemoteButton, pressed: Bool) {
        let action = bindings.action(for: button)

        switch action {
        case .dictation:
            if pressed {
                // Toggle: a quick BLE press/release otherwise starts and stops
                // dictation in the same instant.
                if functionDown { endDictation() } else { beginDictation() }
            }

        case .send:
            if pressed {
                sendReturn()
                onAction?("发送", "return")
            }

        case .sendCommandReturn:
            if pressed {
                sendCommandReturn()
                onAction?("⌘发送", "return")
            }

        case .stop:
            if pressed {
                sendEscape()
                onAction?("停止", "stop.fill")
            }

        case .leftClick:
            if button == .select {
                if pressed {
                    guard !selectDown else { return }
                    selectDown = true
                    postMouse(.leftMouseDown)
                    onAction?("按下 / 拖拽", "cursorarrow.click")
                } else if selectDown {
                    selectDown = false
                    postMouse(.leftMouseUp)
                    onAction?("点击", "cursorarrow.click")
                }
            } else if pressed {
                postMouse(.leftMouseDown)
                postMouse(.leftMouseUp)
                onAction?("左键", "cursorarrow.click")
            }

        case .rightClick:
            if pressed {
                postMouse(.rightMouseDown)
                postMouse(.rightMouseUp)
                onAction?("右键", "cursorarrow.click.2")
            }

        case .moveUp:
            if pressed { moveOrScroll(dx: 0, dy: -16, scroll: 34) }
        case .moveDown:
            if pressed { moveOrScroll(dx: 0, dy: 16, scroll: -34) }
        case .moveLeft:
            if pressed { moveOrScroll(dx: -16, dy: 0, scroll: 0) }
        case .moveRight:
            if pressed { moveOrScroll(dx: 16, dy: 0, scroll: 0) }

        case .scrollUp:
            if pressed { scroll(dy: 34, dx: 0) }
        case .scrollDown:
            if pressed { scroll(dy: -34, dx: 0) }

        case .toggleScroll:
            if pressed {
                scrollMode.toggle()
                onAction?(scrollMode ? "滚动模式" : "光标模式", "scroll")
            }

        case .arrowUp:
            if pressed { sendArrow(kVK_UpArrow) }
        case .arrowDown:
            if pressed { sendArrow(kVK_DownArrow) }
        case .arrowLeft:
            if pressed { sendArrow(kVK_LeftArrow) }
        case .arrowRight:
            if pressed { sendArrow(kVK_RightArrow) }

        case .none:
            break
        }
    }

    @discardableResult
    func toggleSelfTestDictation() -> Bool {
        guard AXIsProcessTrusted() else {
            onAction?("需要辅助功能权限", "exclamationmark.triangle")
            return false
        }
        NSApp.activate(ignoringOtherApps: true)
        postFunctionTap()
        selfTestDictating.toggle()
        onAction?(selfTestDictating ? "测试听写中…" : "测试听写结束", selfTestDictating ? "mic.fill" : "mic.slash")
        return selfTestDictating
    }

    func endSelfTestDictationIfNeeded() {
        guard selfTestDictating else { return }
        postFunctionTap()
        selfTestDictating = false
        onAction?("测试听写结束", "mic.slash")
    }

    func beginDictation() {
        guard !functionDown else { return }
        functionDown = true
        activateTarget()
        onAction?("听写中…", "mic.fill")

        // Prefer the app's Edit > Start Dictation menu item: it is independent of
        // the Globe-key shortcut, which can be assigned to the emoji picker.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self, self.functionDown else { return }
            if self.pressDictationMenuItem(stop: false) {
                self.dictationViaMenu = true
            } else {
                self.postFunctionTap()
            }
        }
    }

    func endDictation() {
        guard functionDown else { return }
        functionDown = false
        if dictationViaMenu {
            dictationViaMenu = false
            if !pressDictationMenuItem(stop: true) { postFunctionTap() }
        } else {
            postFunctionTap()
        }
        onAction?("听写结束", "mic.slash")
    }

    private func pressDictationMenuItem(stop: Bool) -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }
        let app = AXUIElementCreateApplication(front.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &value) == .success,
              let menuBar = value else { return false }
        let tokens = stop ? ["停止听写", "Stop Dictation"] : ["开始听写", "Start Dictation"]
        return pressMenuItem(menuBar as! AXUIElement, tokens: tokens)
    }

    private func pressMenuItem(_ element: AXUIElement, tokens: [String]) -> Bool {
        var titleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
        let title = titleValue as? String ?? ""
        if tokens.contains(where: { title.contains($0) }) {
            return AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
        }
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else { return false }
        for child in children {
            if pressMenuItem(child, tokens: tokens) { return true }
        }
        return false
    }

    private func postFunctionTap() {
        postKey(CGKeyCode(kVK_Function), down: true, flags: .maskSecondaryFn)
        postKey(CGKeyCode(kVK_Function), down: false, flags: .maskSecondaryFn)
    }

    func releaseAll() {
        endDictation()
        if selectDown {
            selectDown = false
            postMouse(.leftMouseUp)
        }
    }

    func activateTarget() {
        guard let bundleID = targetBundleID,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return
        }
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func sendReturn() {
        postKey(CGKeyCode(kVK_Return), down: true, flags: [])
        postKey(CGKeyCode(kVK_Return), down: false, flags: [])
    }

    func sendCommandReturn() {
        postKey(CGKeyCode(kVK_Return), down: true, flags: .maskCommand)
        postKey(CGKeyCode(kVK_Return), down: false, flags: .maskCommand)
    }

    func sendEscape() {
        postKey(CGKeyCode(kVK_Escape), down: true, flags: [])
        postKey(CGKeyCode(kVK_Escape), down: false, flags: [])
    }

    func sendArrow(_ key: Int) {
        postKey(CGKeyCode(key), down: true, flags: [])
        postKey(CGKeyCode(key), down: false, flags: [])
    }

    private func moveOrScroll(dx: CGFloat, dy: CGFloat, scroll amount: Int32) {
        if scrollMode {
            if dx != 0 {
                scroll(dy: 0, dx: dx > 0 ? 28 : -28)
            } else {
                scroll(dy: amount, dx: 0)
            }
        } else {
            let current = cursorPoint
            let destination = CGPoint(x: current.x + dx, y: current.y + dy)
            let type: CGEventType = selectDown ? .leftMouseDragged : .mouseMoved
            postMouse(type, at: destination)
        }
    }

    private func scroll(dy: Int32, dx: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: dx == 0 ? 1 : 2,
            wheel1: dy,
            wheel2: dx,
            wheel3: 0
        ) else { return }
        event.post(tap: .cghidEventTap)
    }

    private var cursorPoint: CGPoint {
        CGEvent(source: nil)?.location ?? NSEvent.mouseLocation
    }

    private func postMouse(_ type: CGEventType, at point: CGPoint? = nil) {
        let location = point ?? cursorPoint
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: location,
            mouseButton: type == .rightMouseDown || type == .rightMouseUp ? .right : .left
        ) else { return }
        event.post(tap: .cghidEventTap)
    }

    private func postKey(_ key: CGKeyCode, down: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: key, keyDown: down) else {
            return
        }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
}
