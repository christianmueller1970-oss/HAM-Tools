import SwiftUI
import AppKit

// MARK: - AppTheme

enum AppTheme: String, CaseIterable, Identifiable {
    case hamStyle   = "light"
    case dark       = "dark"
    case hamClassic = "ham"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hamStyle:   return "Light"
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
        case .hamStyle:   return Color(hex: "#E8EEF4")   // kühles Blaugrau – Hintergrund-Canvas
        case .dark:       return Color(hex: "#1a1a2e")
        case .hamClassic: return Color(hex: "#0d0d00")
        }
    }
    var bgCard: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#FFFFFF")   // Karten: reines Weiß hebt sich ab
        case .dark:       return Color(hex: "#16213e")
        case .hamClassic: return Color(hex: "#111100")
        }
    }
    var bgCard2: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#F3F7FB")   // innere Karten – leicht blaugrau
        case .dark:       return Color(hex: "#1a2244")
        case .hamClassic: return Color(hex: "#161600")
        }
    }
    var bgPanel: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#D6DFE9")   // Sidebar – deutlich dunkler als Canvas
        case .dark:       return Color(hex: "#1e293b")
        case .hamClassic: return Color(hex: "#151500")
        }
    }
    var bgSubPanel: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#C8D4E0")   // Sub-Panels – noch eine Stufe tiefer
        case .dark:       return Color(hex: "#273549")
        case .hamClassic: return Color(hex: "#1c1c00")
        }
    }
    var bgHover: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#D6EAFF")   // Hover: kräftiges Blau
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
        case .hamStyle:   return Color(hex: "#B4C4D4")   // klar sichtbare Trennlinien
        case .dark:       return Color(hex: "#334155")
        case .hamClassic: return Color(hex: "#2d2d00")
        }
    }

    // MARK: Text
    var textPrimary: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#0F1923")   // fast Schwarz – hoher Kontrast
        case .dark:       return Color(hex: "#e2e8f0")
        case .hamClassic: return Color(hex: "#ffcc33")
        }
    }
    var textSecondary: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#3D5166")   // dunkles Blaugrau statt blassgem Grau
        case .dark:       return Color(hex: "#94a3b8")
        case .hamClassic: return Color(hex: "#cc9922")
        }
    }
    var textDim: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#5E7487")   // sichtbar aber zurückgesetzt
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
        case .hamStyle:   return Color(hex: "#0060CC")   // kräftiges Blau
        case .dark:       return Color(hex: "#60a5fa")
        case .hamClassic: return Color(hex: "#ffaa00")
        }
    }
    var accentGreen: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#1A9E40")   // satteres Grün
        case .dark:       return Color(hex: "#4ade80")
        case .hamClassic: return Color(hex: "#88dd00")
        }
    }
    var accentRed: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#D92B22")   // tiefes Rot
        case .dark:       return Color(hex: "#f87171")
        case .hamClassic: return Color(hex: "#ff2200")
        }
    }
    var accentYellow: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#E6A800")   // goldenes Gelb statt blass
        case .dark:       return Color(hex: "#fbbf24")
        case .hamClassic: return Color(hex: "#ffdd00")
        }
    }
    var accentOrange: Color {
        switch self {
        case .hamStyle:   return Color(hex: "#E07000")   // sattes Orange
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
    @Published var theme: AppTheme = .hamClassic

    // Theme-Auswahl liegt in einer stabilen Suite, damit sie über alle Build-
    // Varianten hinweg dieselbe bleibt. Hintergrund: UserDefaults.standard hängt
    // am Bundle-Identifier; ein Swift-Package-Build (kein Bundle-ID) fällt auf
    // den Executable-Namen zurück, ein Xcode-Build benutzt seine Bundle-ID.
    // Damit landen Dev-Build, Release-Build und CLI-Build sonst in getrennten
    // Plist-Domains und »vergessen« die Auswahl beim Wechsel zwischen ihnen.
    private static let suiteName = "com.hb9hji.hamrechner.shared"
    private static let themeKey  = "appTheme"
    private static let defaults: UserDefaults =
        UserDefaults(suiteName: suiteName) ?? .standard

    init() {
        Self.migrateLegacyThemeIfNeeded()
        let raw = Self.defaults.string(forKey: Self.themeKey)
            ?? AppTheme.hamClassic.rawValue
        let t = AppTheme(rawValue: raw) ?? .hamClassic
        theme = t
        applyNSAppearance(t)
    }

    /// Einmalige Migration: wenn in der Shared-Suite noch nichts steht, aus
    /// den Build-spezifischen Legacy-Domains übernehmen. Reihenfolge bevorzugt
    /// den zuletzt-benutzten Build (UserDefaults.standard).
    private static func migrateLegacyThemeIfNeeded() {
        guard defaults.string(forKey: themeKey) == nil else { return }
        let legacyDomains = [
            UserDefaults.standard,
            UserDefaults(suiteName: "com.hb9hji.hamrechner.dev") ?? .standard,
            UserDefaults(suiteName: "com.hb9hji.hamrechner")     ?? .standard,
            UserDefaults(suiteName: "HAMRechner")                ?? .standard
        ]
        if let value = legacyDomains.compactMap({ $0.string(forKey: themeKey) }).first {
            defaults.set(value, forKey: themeKey)
        }
    }

    func setTheme(_ newTheme: AppTheme) {
        theme = newTheme
        Self.defaults.set(newTheme.rawValue, forKey: Self.themeKey)
        applyNSAppearance(newTheme)
    }

    private func applyNSAppearance(_ t: AppTheme) {
        NSApp.appearance = NSAppearance(named: t.colorScheme == .dark ? .darkAqua : .aqua)
    }
}
