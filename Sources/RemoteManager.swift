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

private enum RemoteProfile: Equatable {
    case appleSiriRemote
    case xiaomiRC003

    var displayName: String {
        switch self {
        case .appleSiriRemote: return "Siri Remote (A2854)"
        case .xiaomiRC003: return "小米蓝牙遥控器 2 Pro (RC003)"
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
    private var xiaomiPressed: Set<RemoteButton> = []
    private var xiaomiDeviceCount = 0
    private var xiaomiActive: Bool { xiaomiDeviceCount > 0 }
    private var didReportConnection = false
    private var isRunning = false
    private(set) var transport: String?
    var isListening: Bool { isRunning }

    private let appleVendorID = 0x004C
    private let xiaomiVendorID = 0x2717
    private let xiaomiProductID = 0x32B8
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
        let xiaomiMatch: [String: Any] = [
            kIOHIDVendorIDKey: xiaomiVendorID,
            kIOHIDProductIDKey: xiaomiProductID
        ]
        let matching = [bluetoothMatch, usbMatch, xiaomiMatch]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, deviceAddedCallback, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterDeviceRemovalCallback(manager, deviceRemovedCallback, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterInputReportCallback(manager, inputReportCallback, Unmanaged.passUnretained(self).toOpaque())

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            onStatus?("无法打开 HID：\(ioErrorName(result))。请在系统设置中授予输入监控权限。")
            isRunning = false
            return
        }

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        onStatus?("正在等待遥控器")

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
        xiaomiPressed.removeAll()
        xiaomiDeviceCount = 0

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
        for device in set {
            if profile(for: device) != nil {
                open(device)
            }
        }
    }

    fileprivate func profile(for device: IOHIDDevice) -> RemoteProfile? {
        guard let vendor = numberProperty(device, kIOHIDVendorIDKey) else { return nil }
        let productID = numberProperty(device, kIOHIDProductIDKey)

        // A2854 also exposes a wired USB HID interface while charging.
        if vendor == 0x05AC, productID == 0x0314 {
            return .appleSiriRemote
        }

        if vendor == appleVendorID {
            if let productID, knownProductIDs.contains(productID) {
                return .appleSiriRemote
            }
            if let name = stringProperty(device, kIOHIDProductKey)?.lowercased(),
               name.contains("siri") || name.contains("remote") || name.contains("apple tv") {
                return .appleSiriRemote
            }
        }

        if vendor == xiaomiVendorID {
            if productID == xiaomiProductID { return .xiaomiRC003 }
            if let name = stringProperty(device, kIOHIDProductKey)?.lowercased(),
               name.contains("mi rc") || name.contains("xiaomi") || name.contains("remote") || name.contains("小米") || name.contains("遥控") {
                return .xiaomiRC003
            }
        }

        return nil
    }

    fileprivate func open(_ device: IOHIDDevice) {
        guard let remoteProfile = profile(for: device) else { return }
        guard !devices.contains(where: { CFEqual($0, device) }) else { return }

        var result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if result != kIOReturnSuccess {
            result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        guard result == kIOReturnSuccess else {
            onStatus?("找到遥控器但无法打开：\(ioErrorName(result))")
            return
        }

        if remoteProfile == .xiaomiRC003 {
            // RC003 sends a report-ID 1 array of little-endian HID usages.
            // The manager-level report callback filters on xiaomiActive.
            xiaomiDeviceCount += 1
        } else {
            IOHIDDeviceRegisterInputValueCallback(device, inputValueCallback, Unmanaged.passUnretained(self).toOpaque())
        }
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        devices.append(device)
        transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String

        if !didReportConnection {
            didReportConnection = true
            let displayName = remoteProfile.displayName
            onConnection?(true, displayName)
            onStatus?("已连接 \(displayName)")
        }
    }

    fileprivate func close(_ device: IOHIDDevice) {
        guard let index = devices.firstIndex(where: { CFEqual($0, device) }) else { return }
        let existing = devices[index]
        let closingProfile = profile(for: existing)
        IOHIDDeviceRegisterInputValueCallback(existing, nil, nil)
        IOHIDDeviceUnscheduleFromRunLoop(existing, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDDeviceClose(existing, IOOptionBits(kIOHIDOptionsTypeNone))
        if closingProfile == .xiaomiRC003 {
            xiaomiDeviceCount = max(0, xiaomiDeviceCount - 1)
            if xiaomiDeviceCount == 0 { xiaomiPressed.removeAll() }
        }
        devices.remove(at: index)

        if devices.isEmpty {
            didReportConnection = false
            transport = nil
            states.removeAll()
            xiaomiPressed.removeAll()
            onConnection?(false, nil)
            onStatus?("遥控器已断开")
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

    fileprivate func handleInputReport(reportID: UInt32, data: Data) {
        guard xiaomiActive, reportID == 1 else { return }
        var bytes = Array(data)
        if bytes.count == 7, bytes.first == UInt8(reportID) {
            bytes.removeFirst()
        }
        guard !bytes.isEmpty, bytes.count.isMultiple(of: 2) else { return }

        var usages = Set<UInt16>()
        for index in stride(from: 0, to: bytes.count, by: 2) {
            let usage = UInt16(bytes[index]) | UInt16(bytes[index + 1]) << 8
            if usage != 0 { usages.insert(usage) }
        }

        let buttons = Set(usages.compactMap(xiaomiButton(for:)))
        let pressed = buttons.subtracting(xiaomiPressed)
        let released = xiaomiPressed.subtracting(buttons)
        xiaomiPressed = buttons

        for usage in usages.sorted() {
            onRawEvent?(0x07, UInt32(usage), 1)
        }
        for button in pressed.sorted(by: { $0.rawValue < $1.rawValue }) {
            onButton?(button, true)
        }
        for button in released.sorted(by: { $0.rawValue < $1.rawValue }) {
            onButton?(button, false)
        }
    }

    private func xiaomiButton(for usage: UInt16) -> RemoteButton? {
        switch usage {
        case 0x3E: return .siri          // microphone F5
        case 0x28: return .select        // OK / enter
        case 0xF1: return .back          // back
        case 0x4F: return .ringRight
        case 0x50: return .ringLeft
        case 0x51: return .ringDown
        case 0x52: return .ringUp
        case 0x35: return .tv            // TV
        case 0x65: return .back          // menu
        case 0x4A: return .tv            // home
        default: return nil
        }
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

private func inputReportCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard let context, result == kIOReturnSuccess, reportLength > 0 else { return }
    let manager = Unmanaged<RemoteManager>.fromOpaque(context).takeUnretainedValue()
    let data = Data(bytes: report, count: reportLength)
    DispatchQueue.main.async {
        manager.handleInputReport(reportID: reportID, data: data)
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
    guard manager.profile(for: device) != nil else { return }
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
