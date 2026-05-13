import SwiftUI

// Banner oben im Hauptfenster — zeigt Demo-/Renewal-/Wrong-Call-Status an.
// Klick führt zu den Einstellungen (Lizenz-Tab).
struct LicenseBanner: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var license:      LicenseService
    @Environment(\.openSettings) private var openSettings

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        if shouldShow {
            HStack(spacing: 8) {
                Image(systemName: bannerIcon)
                    .foregroundStyle(bannerColor)
                Text(headline)
                    .font(.caption.bold())
                    .foregroundStyle(theme.textPrimary)
                Text("·")
                    .foregroundStyle(theme.textDim)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("Lizenz eingeben") {
                    openSettings()
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(bannerColor.opacity(0.18))
            .overlay(alignment: .bottom) {
                Rectangle().fill(bannerColor.opacity(0.5)).frame(height: 1)
            }
        }
    }

    private var shouldShow: Bool {
        !license.status.allowsFullMode
    }

    private var bannerIcon: String {
        switch license.status {
        case .valid:                "checkmark.seal.fill"
        case .needsRenewal:         "exclamationmark.triangle.fill"
        case .wrongCall:            "exclamationmark.triangle.fill"
        case .missingOrInvalid:     "hourglass"
        }
    }

    private var bannerColor: Color {
        switch license.status {
        case .valid:                theme.accentGreen
        case .needsRenewal:         theme.accentOrange
        case .wrongCall:            theme.accentOrange
        case .missingOrInvalid:     theme.accentBlue
        }
    }

    private var headline: String {
        switch license.status {
        case .valid:                            return "Vollversion"
        case .needsRenewal:                     return "Update-Verlängerung nötig"
        case .wrongCall:                        return "Call passt nicht zur Lizenz"
        case .missingOrInvalid:                 return "Demo-Modus"
        }
    }

    private var detail: String {
        switch license.status {
        case .valid:
            return ""
        case .needsRenewal(_, let buildDate):
            return "Diese App-Version (Build \(buildDate)) braucht eine erneuerte Lizenz. \(remainingText())"
        case .wrongCall(_, let configured):
            return "Eingestellt: \(configured). \(remainingText())"
        case .missingOrInvalid:
            return remainingText() + " — Lizenz anfragen unter \(BuildInfo.licenseRequestEmail)"
        }
    }

    private func remainingText() -> String {
        let r = license.demoRemaining
        if r > 0 { return "Noch \(r) von \(LicenseService.demoLimit) Demo-QSOs verfügbar" }
        return "Demo-Limit erreicht — Read-Only"
    }
}
