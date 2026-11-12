import Foundation

enum BluetoothBatteryReader {
    static func read(serialNumber: String? = nil) -> Int? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["-json", "SPBluetoothDataType"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let timeout = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 8, execute: timeout)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeout.cancel()
        guard process.terminationStatus == 0 else { return nil }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]] else {
            return nil
        }

        var fallback: Int?
        for section in sections {
            for key in ["device_connected", "device_not_connected"] {
                guard let entries = section[key] as? [[String: Any]] else { continue }
                for entry in entries {
                    for (name, value) in entry {
                        guard let info = value as? [String: Any] else { continue }
                        let lowerName = name.lowercased()
                        let productID = (info["device_productID"] as? String)?.lowercased()
                        let serial = info["device_serialNumber"] as? String
                        let isSiriRemote = lowerName.contains("siri")
                            || lowerName.contains("remote")
                            || productID == "0x0315"
                            || productID == "0x0314"
                            || (serialNumber != nil && serial == serialNumber)
                        guard isSiriRemote else { continue }

                        guard let battery = info["device_batteryLevelMain"] as? String,
                              let percent = parseInt(battery) else { continue }
                        if key == "device_connected" {
                            return percent
                        }
                        fallback = percent
                    }
                }
            }
        }
        return fallback
    }

    private static func parseInt(_ value: String) -> Int? {
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty, let number = Int(digits) else { return nil }
        return min(max(number, 0), 100)
    }
}
