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
    private var heldDirections: Set<RemoteButton> = []
    private var pointerTimer: Timer?
    private var lastLeftClickAt: TimeInterval = 0
    private var pointerStart: TimeInterval = 0
    private var pointerLastAction: String?

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
                    let now = ProcessInfo.processInfo.systemUptime
                    if now - lastLeftClickAt < 0.35 {
                        lastLeftClickAt = 0
                        sendShowAllWindows()
                        onAction?("所有窗口", "rectangle.3.group")
                        return
                    }
                    lastLeftClickAt = now
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

        case .middleClick:
            if pressed {
                postMouse(.otherMouseDown, button: .center)
                postMouse(.otherMouseUp, button: .center)
                onAction?("中键", "cursorarrow.click")
            }

        case .moveUp, .moveDown, .moveLeft, .moveRight:
            if pressed {
                beginPointer(button)
            } else {
                endPointer(button)
            }

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

        case .confirm:
            if pressed {
                sendReturn()
                onAction?("确认", "return")
            }

        case .deleteBackward:
            if pressed {
                sendDelete()
                onAction?("删除", "delete.left")
            }

        case .pageUp:
            if pressed {
                sendPageUp()
                onAction?("向上翻页", "arrow.up.to.line")
            }

        case .pageDown:
            if pressed {
                sendPageDown()
                onAction?("向下翻页", "arrow.down.to.line")
            }

        case .browserBack:
            if pressed {
                sendBrowserBack()
                onAction?("浏览器上一页", "chevron.backward")
            }

        case .showAllWindows:
            if pressed {
                sendShowAllWindows()
                onAction?("所有窗口", "rectangle.3.group")
            }

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
        heldDirections.removeAll()
        stopPointerTimer()
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

    func sendDelete() {
        postKey(CGKeyCode(kVK_Delete), down: true, flags: [])
        postKey(CGKeyCode(kVK_Delete), down: false, flags: [])
    }

    func sendPageUp() {
        postKey(CGKeyCode(kVK_PageUp), down: true, flags: [])
        postKey(CGKeyCode(kVK_PageUp), down: false, flags: [])
    }

    func sendPageDown() {
        postKey(CGKeyCode(kVK_PageDown), down: true, flags: [])
        postKey(CGKeyCode(kVK_PageDown), down: false, flags: [])
    }

    func sendBrowserBack() {
        postKey(CGKeyCode(kVK_ANSI_LeftBracket), down: true, flags: .maskCommand)
        postKey(CGKeyCode(kVK_ANSI_LeftBracket), down: false, flags: .maskCommand)
    }

    func sendShowAllWindows() {
        postKey(CGKeyCode(kVK_UpArrow), down: true, flags: .maskControl)
        postKey(CGKeyCode(kVK_UpArrow), down: false, flags: .maskControl)
    }

    func sendArrow(_ key: Int) {
        postKey(CGKeyCode(key), down: true, flags: [])
        postKey(CGKeyCode(key), down: false, flags: [])
    }

    private func beginPointer(_ button: RemoteButton) {
        guard heldDirections.insert(button).inserted else { return }

        if pointerTimer == nil {
            pointerStart = Date.timeIntervalSinceReferenceDate
            pointerLastAction = nil
            // A tap should still nudge the pointer a little; holding accelerates
            // from a slow, precise speed to a faster glide.
            applyPointer(dx: vector(for: button).dx * 5, dy: vector(for: button).dy * 5)
            let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.pointerTick() }
            }
            RunLoop.main.add(timer, forMode: .common)
            pointerTimer = timer
        }
    }

    private func endPointer(_ button: RemoteButton) {
        heldDirections.remove(button)
        if heldDirections.isEmpty {
            stopPointerTimer()
        }
    }

    private func pointerTick() {
        guard pointerTimer != nil, !heldDirections.isEmpty else {
            stopPointerTimer()
            return
        }
        let elapsed = Date.timeIntervalSinceReferenceDate - pointerStart
        let speed = min(9.0, 2.0 + CGFloat(elapsed) * 14.0)
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        if heldDirections.contains(.ringLeft) { dx -= 1 }
        if heldDirections.contains(.ringRight) { dx += 1 }
        if heldDirections.contains(.ringUp) { dy -= 1 }
        if heldDirections.contains(.ringDown) { dy += 1 }
        guard dx != 0 || dy != 0 else { return }
        let length = sqrt(dx * dx + dy * dy)
        dx = dx / length * speed
        dy = dy / length * speed
        applyPointer(dx: dx, dy: dy)
    }

    private func applyPointer(dx: CGFloat, dy: CGFloat) {
        if scrollMode {
            let wheelX = Int32(dx * 5)
            let wheelY = Int32(dy * 5)
            guard wheelX != 0 || wheelY != 0 else { return }
            scroll(dy: wheelY, dx: wheelX)
            if pointerLastAction != "滚动" {
                pointerLastAction = "滚动"
                onAction?("滚动", "scroll")
            }
        } else {
            movePointer(dx: dx, dy: dy)
            if pointerLastAction != "鼠标移动" {
                pointerLastAction = "鼠标移动"
                onAction?("鼠标移动", "cursorarrow")
            }
        }
    }

    private func stopPointerTimer() {
        pointerTimer?.invalidate()
        pointerTimer = nil
        pointerLastAction = nil
    }

    private func vector(for button: RemoteButton) -> (dx: CGFloat, dy: CGFloat) {
        switch button {
        case .ringUp: return (0, -1)
        case .ringDown: return (0, 1)
        case .ringLeft: return (-1, 0)
        case .ringRight: return (1, 0)
        default: return (0, 0)
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

    private func postMouse(_ type: CGEventType, at point: CGPoint? = nil, button: CGMouseButton? = nil) {
        let location = point ?? cursorPoint
        let mouseButton = button ?? (type == .rightMouseDown || type == .rightMouseUp ? .right : .left)
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: location,
            mouseButton: mouseButton
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
