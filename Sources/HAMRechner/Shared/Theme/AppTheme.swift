import SwiftUI

// MARK: - AppTheme

enum AppTheme: String, CaseIterable, Identifiable {
    case hamStyle   = "light"
    case dark       = "dark"
    case hamClassic = "ham"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hamStyle:   return "HAM Style"
        case .dark:       return "Dark"
        case .hamClassic: return "Ham Classic"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .hamStyle: return .light
        case .dark, .hamClassic: return .dark
        }
    }

    // MARK: Backgrounds
    var bgApp: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#ffffff")
        case .dark:       return Color(hex: "#1a1a2e")
        case .hamClassic: return Color(hex: "#0d0d00")
        }
    }
    var bgCard: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#ffffff")
        case .dark:       return Color(hex: "#16213e")
        case .hamClassic: return Color(hex: "#111100")
        }
    }
    var bgCard2: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#f9f9f9")
        case .dark:       return Color(hex: "#1a2244")
        case .hamClassic: return Color(hex: "#161600")
        }
    }
    var bgPanel: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#f5f5f5")
        case .dark:       return Color(hex: "#1e293b")
        case .hamClassic: return Color(hex: "#151500")
        }
    }
    var bgSubPanel: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#f0f0f0")
        case .dark:       return Color(hex: "#273549")
        case .hamClassic: return Color(hex: "#1c1c00")
        }
    }
    var bgHover: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#e6f3ff")
        case .dark:       return Color(hex: "#2a3f5e")
        case .hamClassic: return Color(hex: "#222200")
        }
    }
    var bgLog: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#1a1a1a")
        case .dark:       return Color(hex: "#0a0a14")
        case .hamClassic: return Color(hex: "#000000")
        }
    }
    var separator: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#e0e0e0")
        case .dark:       return Color(hex: "#334155")
        case .hamClassic: return Color(hex: "#2d2d00")
        }
    }

    // MARK: Text
    var textPrimary: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#1D1D1F")
        case .dark:       return Color(hex: "#e2e8f0")
        case .hamClassic: return Color(hex: "#ffcc33")
        }
    }
    var textSecondary: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#6E6E73")
        case .dark:       return Color(hex: "#94a3b8")
        case .hamClassic: return Color(hex: "#cc9922")
        }
    }
    var textDim: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#86868B")
        case .dark:       return Color(hex: "#64748b")
        case .hamClassic: return Color(hex: "#997711")
        }
    }
    var logText: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#33dd44")
        case .dark:       return Color(hex: "#4ade80")
        case .hamClassic: return Color(hex: "#ffcc33")
        }
    }

    // MARK: Accents
    var accentBlue: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#007AFF")
        case .dark:       return Color(hex: "#60a5fa")
        case .hamClassic: return Color(hex: "#ffaa00")
        }
    }
    var accentGreen: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#34C759")
        case .dark:       return Color(hex: "#4ade80")
        case .hamClassic: return Color(hex: "#88dd00")
        }
    }
    var accentRed: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#FF3B30")
        case .dark:       return Color(hex: "#f87171")
        case .hamClassic: return Color(hex: "#ff2200")
        }
    }
    var accentYellow: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#FFCC00")
        case .dark:       return Color(hex: "#fbbf24")
        case .hamClassic: return Color(hex: "#ffdd00")
        }
    }
    var accentOrange: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#FF9500")
        case .dark:       return Color(hex: "#fb923c")
        case .hamClassic: return Color(hex: "#ff8800")
        }
    }
    var accentPink: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#8B008B")
        case .dark:       return Color(hex: "#f472b6")
        case .hamClassic: return Color(hex: "#ff88bb")
        }
    }

    // Source colors (DX / SOTA / POTA / WWFF)
    var colorDX: Color   { accentBlue }
    var colorSOTA: Color { accentOrange }
    var colorPOTA: Color { accentGreen }
    var colorWWFF: Color { accentPink }
}

// MARK: - Color(hex:)

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - ThemeManager

final class ThemeManager: ObservableObject {
    @Published var theme: AppTheme = .hamStyle

    init() {
        let raw = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.hamStyle.rawValue
        theme = AppTheme(rawValue: raw) ?? .hamStyle
    }

    func setTheme(_ newTheme: AppTheme) {
        theme = newTheme
        UserDefaults.standard.set(newTheme.rawValue, forKey: "appTheme")
    }
}
