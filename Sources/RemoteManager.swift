import Foundation
import IOKit
import IOKit.hid

enum RemoteButton: String, CaseIterable, Identifiable {
    case siri
    case tv
    case select
    case playPause
    case back
    case ringUp
    case ringDown
    case ringLeft
    case ringRight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .siri: return "Siri"
        case .tv: return "TV"
        case .select: return "Select"
        case .playPause: return "播放/暂停"
        case .back: return "返回"
        case .ringUp: return "上"
        case .ringDown: return "下"
        case .ringLeft: return "左"
        case .ringRight: return "右"
        }
    }
}

final class RemoteManager {
    var onConnection: ((Bool, String?) -> Void)?
    var onButton: ((RemoteButton, Bool) -> Void)?
    var onRawEvent: ((UInt32, UInt32, Int) -> Void)?
    var onStatus: ((String) -> Void)?

    private var manager: IOHIDManager?
    private var devices: [IOHIDDevice] = []
    private var states: [String: Bool] = [:]
    private var didReportConnection = false
    private var isRunning = false
    private(set) var transport: String?
    var isListening: Bool { isRunning }

    private let appleVendorID = 0x004C
    private let knownProductIDs: Set<Int> = [
        0x0221, 0x0255, 0x0266, 0x0267, 0x0269,
        0x030D, 0x030E, 0x0314, 0x0315, 0x0C4E, 0x0C4F
    ]

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager

        let bluetoothMatch: [String: Any] = [kIOHIDVendorIDKey: appleVendorID]
        let usbMatch: [String: Any] = [
            kIOHIDVendorIDKey: 0x05AC,
            kIOHIDProductIDKey: 0x0314
        ]
        let matching = [bluetoothMatch, usbMatch]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, deviceAddedCallback, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterDeviceRemovalCallback(manager, deviceRemovedCallback, Unmanaged.passUnretained(self).toOpaque())

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            onStatus?("无法打开 HID：\(ioErrorName(result))。请在系统设置中授予输入监控权限。")
            isRunning = false
            return
        }

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        onStatus?("正在等待 Siri Remote")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.enumerateDevices()
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        for device in devices {
            IOHIDDeviceRegisterInputValueCallback(device, nil, nil)
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        devices.removeAll()
        states.removeAll()

        if let manager {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            self.manager = nil
        }

        didReportConnection = false
        onConnection?(false, nil)
    }

    private func enumerateDevices() {
        guard let manager,
              let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return }
        for device in set where isSiriRemote(device) {
            open(device)
        }
    }

    fileprivate func isSiriRemote(_ device: IOHIDDevice) -> Bool {
        guard let vendor = numberProperty(device, kIOHIDVendorIDKey) else { return false }
        let productID = numberProperty(device, kIOHIDProductIDKey)

        // A2854 also exposes a wired USB HID interface while charging.
        if vendor == 0x05AC, productID == 0x0314 {
            return true
        }

        guard vendor == appleVendorID else { return false }

        if let productID, knownProductIDs.contains(productID) {
            return true
        }

        if let name = stringProperty(device, kIOHIDProductKey)?.lowercased() {
            return name.contains("siri") || name.contains("remote") || name.contains("apple tv")
        }

        return false
    }

    fileprivate func open(_ device: IOHIDDevice) {
        guard !devices.contains(where: { CFEqual($0, device) }) else { return }

        var result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if result != kIOReturnSuccess {
            result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        guard result == kIOReturnSuccess else {
            onStatus?("找到遥控器但无法打开：\(ioErrorName(result))")
            return
        }

        IOHIDDeviceRegisterInputValueCallback(device, inputValueCallback, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        devices.append(device)
        transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String

        if !didReportConnection {
            didReportConnection = true
            let productID = numberProperty(device, kIOHIDProductIDKey)
            let name = stringProperty(device, kIOHIDProductKey)
            let displayName = productID == 0x0314 || productID == 0x0315
                ? "Siri Remote (A2854)"
                : (name.flatMap { $0.count > 2 && !$0.contains("Siri") && !$0.lowercased().contains("remote") ? "Siri Remote" : $0 } ?? "Siri Remote")
            onConnection?(true, displayName)
            onStatus?("已连接 \(displayName)")
        }
    }

    fileprivate func close(_ device: IOHIDDevice) {
        guard let index = devices.firstIndex(where: { CFEqual($0, device) }) else { return }
        let existing = devices[index]
        IOHIDDeviceRegisterInputValueCallback(existing, nil, nil)
        IOHIDDeviceUnscheduleFromRunLoop(existing, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDDeviceClose(existing, IOOptionBits(kIOHIDOptionsTypeNone))
        devices.remove(at: index)

        if devices.isEmpty {
            didReportConnection = false
            transport = nil
            states.removeAll()
            onConnection?(false, nil)
            onStatus?("Siri Remote 已断开")
        }
    }

    fileprivate func handleInput(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let integer = IOHIDValueGetIntegerValue(value)
        let pressed = integer != 0

        onRawEvent?(page, usage, integer)

        guard let button = identify(page: page, usage: usage) else { return }
        let key = button.rawValue
        if states[key] == pressed { return }
        states[key] = pressed

        onButton?(button, pressed)
    }

    private func identify(page: UInt32, usage: UInt32) -> RemoteButton? {
        switch (page, usage) {
        case (0x0C, 0x04), (0xFF00, _), (0x0B, 0x21), (0x0B, 0x2F):
            return .siri
        case (0x0C, 0x60), (0x0C, 0x223):
            return .tv
        case (0x0C, 0x80), (0x0C, 0x41), (0x09, 0x01):
            return .select
        case (0x0C, 0xCD):
            return .playPause
        case (0x0C, 0x224), (0x0C, 0x40), (0x01, 0x86):
            return .back
        case (0x0C, 0x42):
            return .ringUp
        case (0x0C, 0x43):
            return .ringDown
        case (0x0C, 0x44):
            return .ringLeft
        case (0x0C, 0x45):
            return .ringRight
        // Some remotes expose a keyboard HID interface instead of consumer controls.
        case (0x07, 0x28):
            return .tv
        case (0x07, 0x29):
            return .back
        case (0x07, 0x2C):
            return .select
        case (0x07, 0x50):
            return .ringLeft
        case (0x07, 0x4F):
            return .ringRight
        case (0x07, 0x51):
            return .ringDown
        case (0x07, 0x52):
            return .ringUp
        default:
            return nil
        }
    }

    private func numberProperty(_ device: IOHIDDevice, _ key: String) -> Int? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
    }

    private func stringProperty(_ device: IOHIDDevice, _ key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private func ioErrorName(_ code: IOReturn) -> String {
        if code == kIOReturnNotPermitted { return "没有输入监控权限" }
        if code == kIOReturnExclusiveAccess { return "设备被其他程序占用" }
        return String(format: "0x%X", code)
    }
}

private func deviceAddedCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    let manager = Unmanaged<RemoteManager>.fromOpaque(context).takeUnretainedValue()
    guard manager.isSiriRemote(device) else { return }
    DispatchQueue.main.async {
        manager.open(device)
    }
}

private func deviceRemovedCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    let manager = Unmanaged<RemoteManager>.fromOpaque(context).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.close(device)
    }
}

private func inputValueCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    value: IOHIDValue
) {
    guard let context else { return }
    let manager = Unmanaged<RemoteManager>.fromOpaque(context).takeUnretainedValue()
    manager.handleInput(value)
}
