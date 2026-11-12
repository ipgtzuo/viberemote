import Foundation

enum AppMode: String, CaseIterable, Identifiable {
    case automatic
    case dsh
    case workBuddy
    case doubao
    case generic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic: return "自动"
        case .dsh: return "DSH"
        case .workBuddy: return "WorkBuddy"
        case .doubao: return "豆包"
        case .generic: return "通用"
        }
    }

    var symbol: String {
        switch self {
        case .automatic: return "circle.lefthalf.filled"
        case .dsh: return "terminal"
        case .workBuddy: return "briefcase"
        case .doubao: return "bubble.left.and.bubble.right"
        case .generic: return "cursorarrow"
        }
    }

    var bundleID: String? {
        switch self {
        case .dsh: return "com.deepseek.dsh"
        case .workBuddy: return "com.tencent.workbuddy.mac"
        case .doubao: return "com.bot.neotix.doubao"
        case .automatic, .generic: return nil
        }
    }

    var isAutomatic: Bool { self == .automatic }

    static func detect(bundleID: String?) -> AppMode {
        guard let bundleID else { return .generic }
        switch bundleID {
        case "com.deepseek.dsh": return .dsh
        case "com.tencent.workbuddy.mac": return .workBuddy
        case "com.bot.neotix.doubao": return .doubao
        default: return .generic
        }
    }
}
