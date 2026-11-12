import AppKit
import CoreGraphics
import Darwin
import Foundation

private struct MTPoint {
    var x: Float
    var y: Float
}

private struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

private struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var pathIndex: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalizedVector: MTVector
    var zTotal: Float
    var field9: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absoluteVector: MTVector
    var field14: Int32
    var field15: Int32
    var zDensity: Float
}

private typealias MTDevice = UnsafeMutableRawPointer
private typealias MTFrameCallback = @convention(c) (MTDevice?, UnsafeMutableRawPointer?, Int, Double, Int, UnsafeMutableRawPointer?) -> Void
private typealias MTDeviceCreateListFn = @convention(c) () -> Unmanaged<CFArray>?
private typealias MTRegisterFn = @convention(c) (MTDevice?, MTFrameCallback?, UnsafeMutableRawPointer?) -> Void
private typealias MTUnregisterFn = @convention(c) (MTDevice?, MTFrameCallback?) -> Void
private typealias MTDeviceStartFn = @convention(c) (MTDevice?, Int32) -> Int32
private typealias MTDeviceStopFn = @convention(c) (MTDevice?) -> Int32
private typealias MTDeviceIsBuiltInFn = @convention(c) (MTDevice?) -> Bool
private typealias MTDeviceIsRunningFn = @convention(c) (MTDevice?) -> Bool

private final class MultitouchAPI {
    static let shared = MultitouchAPI()

    let createList: MTDeviceCreateListFn?
    let register: MTRegisterFn?
    let unregister: MTUnregisterFn?
    let startDevice: MTDeviceStartFn?
    let stopDevice: MTDeviceStopFn?
    let isBuiltIn: MTDeviceIsBuiltInFn?
    let isRunning: MTDeviceIsRunningFn?
    let loaded: Bool

    private init() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW) else {
            loaded = false
            createList = nil; register = nil; unregister = nil
            startDevice = nil; stopDevice = nil; isBuiltIn = nil; isRunning = nil
            return
        }

        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let ptr = dlsym(handle, name) else { return nil }
            return unsafeBitCast(ptr, to: T.self)
        }

        createList = symbol("MTDeviceCreateList", as: MTDeviceCreateListFn.self)
        register = symbol("MTRegisterContactFrameCallbackWithRefcon", as: MTRegisterFn.self)
        unregister = symbol("MTUnregisterContactFrameCallback", as: MTUnregisterFn.self)
        startDevice = symbol("MTDeviceStart", as: MTDeviceStartFn.self)
        stopDevice = symbol("MTDeviceStop", as: MTDeviceStopFn.self)
        isBuiltIn = symbol("MTDeviceIsBuiltIn", as: MTDeviceIsBuiltInFn.self)
        isRunning = symbol("MTDeviceIsRunning", as: MTDeviceIsRunningFn.self)
        loaded = createList != nil && register != nil && startDevice != nil
    }
}

private func touchFrameCallback(
    device: MTDevice?,
    touchesRaw: UnsafeMutableRawPointer?,
    count: Int,
    timestamp: Double,
    frame: Int,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let manager = Unmanaged<TouchpadManager>.fromOpaque(refcon).takeUnretainedValue()

    guard count > 0, let touchesRaw else {
        Task { @MainActor in manager.touchEnded() }
        return
    }

    let touches = touchesRaw.assumingMemoryBound(to: MTTouch.self)
    var sumX: Float = 0
    var sumY: Float = 0
    var active = 0
    for index in 0..<count {
        let touch = touches[index]
        guard touch.state == 3 || touch.state == 4 else { continue }
        sumX += touch.normalizedVector.position.x
        sumY += touch.normalizedVector.position.y
        active += 1
    }

    guard active > 0 else {
        Task { @MainActor in manager.touchEnded() }
        return
    }

    let x = sumX / Float(active)
    let y = sumY / Float(active)
    Task { @MainActor in
        manager.handleTouch(count: active, x: CGFloat(x), y: CGFloat(y))
    }
}

@MainActor
final class TouchpadManager {
    private let actions: ActionExecutor
    private let api = MultitouchAPI.shared
    private var device: MTDevice?
    private var reconnectTimer: Timer?
    private var lastPosition: CGPoint?
    private var lastCount = 0

    init(actions: ActionExecutor) {
        self.actions = actions
    }

    deinit {
        reconnectTimer?.invalidate()
    }

    func start() {
        guard api.loaded else { return }
        findDevice()
        guard reconnectTimer == nil else { return }
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reconnectIfNeeded()
            }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        reconnectTimer = timer
    }

    func stop() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        stopCurrentDevice()
    }

    private func reconnectIfNeeded() {
        if let device, let isRunning = api.isRunning, !isRunning(device) {
            stopCurrentDevice()
        }
        if device == nil {
            findDevice()
        }
    }

    private func findDevice() {
        guard let createList = api.createList,
              let list = createList()?.takeRetainedValue() else { return }

        let count = CFArrayGetCount(list)
        guard count > 0 else { return }

        var fallback: MTDevice?
        for index in 0..<count {
            guard let raw = CFArrayGetValueAtIndex(list, index) else { continue }
            let candidate = UnsafeMutableRawPointer(mutating: raw)
            if let isBuiltIn = api.isBuiltIn, !isBuiltIn(candidate) {
                startDevice(candidate)
                return
            }
            fallback = candidate
        }

        // If the private "is built-in" symbol is unavailable, use the last non-primary device.
        if api.isBuiltIn == nil, count > 1, let fallback {
            startDevice(fallback)
        }
    }

    private func startDevice(_ candidate: MTDevice) {
        stopCurrentDevice()
        device = candidate
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        api.register?(candidate, touchFrameCallback, refcon)
        _ = api.startDevice?(candidate, 0)
        lastPosition = nil
        lastCount = 0
    }

    private func stopCurrentDevice() {
        guard let device else { return }
        api.unregister?(device, touchFrameCallback)
        _ = api.stopDevice?(device)
        self.device = nil
        lastPosition = nil
        lastCount = 0
    }

    func handleTouch(count: Int, x: CGFloat, y: CGFloat) {
        guard count > 0 else {
            touchEnded()
            return
        }

        let current = CGPoint(x: x, y: y)
        guard let previous = lastPosition else {
            lastPosition = current
            lastCount = count
            return
        }

        let dx = current.x - previous.x
        let dy = current.y - previous.y

        if count == 1, lastCount == 1 {
            // The remote's clickpad is small; this scale gives a usable desktop range.
            actions.movePointer(dx: dx * 620, dy: -dy * 620)
        } else if count >= 2, lastCount >= 2 {
            actions.scrollBy(dx: -dx * 170, dy: dy * 170)
        }

        lastPosition = current
        lastCount = count
    }

    func touchEnded() {
        lastPosition = nil
        lastCount = 0
    }
}
