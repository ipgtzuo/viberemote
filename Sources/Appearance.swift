import SwiftUI
import AppKit

enum AppearanceMode: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "自动"
        case .light: return "淡色"
        case .dark: return "深色"
        }
    }

    var symbol: String {
        switch self {
        case .auto: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct VibeTheme {
    let isDark: Bool

    init(_ scheme: ColorScheme) {
        isDark = scheme == .dark
    }

    var primary: Color {
        isDark ? .white : Color(red: 0.075, green: 0.085, blue: 0.11)
    }

    func text(_ alpha: Double) -> Color {
        primary.opacity(alpha)
    }

    /// Foreground text gets extra contrast in light appearance; keep fills
    /// and strokes on `text(_:)` so cards do not become muddy.
    func label(_ alpha: Double) -> Color {
        if isDark { return primary.opacity(alpha) }
        return primary.opacity(min(1.0, alpha * 1.50 + 0.12))
    }

    var cardFill: Color {
        isDark ? Color.white.opacity(0.052) : Color.black.opacity(0.045)
    }

    var cardFillStrong: Color {
        isDark ? Color.white.opacity(0.085) : Color.black.opacity(0.075)
    }

    var cardStroke: Color {
        isDark ? Color.white.opacity(0.075) : Color.black.opacity(0.11)
    }

    var controlFill: Color {
        isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.07)
    }

    var controlStroke: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.12)
    }

    var keyFill: Color {
        isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)
    }

    var keyStroke: Color {
        isDark ? Color.white.opacity(0.09) : Color.black.opacity(0.09)
    }

    var divider: Color {
        isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.08)
    }

    var shadow: Color {
        isDark ? Color.black.opacity(0.6) : Color.black.opacity(0.16)
    }

    var selectedFill: Color {
        isDark ? Color.white.opacity(0.88) : Color.black.opacity(0.82)
    }

    var selectedText: Color {
        isDark ? Color.black.opacity(0.82) : Color.white.opacity(0.94)
    }

    var panelTop: Color {
        isDark ? Color(red: 0.08, green: 0.09, blue: 0.13) : Color(red: 0.965, green: 0.965, blue: 0.985)
    }

    var panelBottom: Color {
        isDark ? Color(red: 0.035, green: 0.04, blue: 0.06) : Color(red: 0.885, green: 0.90, blue: 0.945)
    }

    var glowBlue: Color {
        isDark ? Color(red: 0.43, green: 0.48, blue: 1.0).opacity(0.16) : Color(red: 0.40, green: 0.52, blue: 0.95).opacity(0.12)
    }

    var glowPurple: Color {
        isDark ? Color(red: 0.82, green: 0.36, blue: 0.95).opacity(0.15) : Color(red: 0.72, green: 0.42, blue: 0.92).opacity(0.10)
    }

    var material: NSVisualEffectView.Material {
        isDark ? .hudWindow : .popover
    }
}
