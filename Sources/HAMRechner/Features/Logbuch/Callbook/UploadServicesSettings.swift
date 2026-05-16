import Foundation
import Combine

// Credentials + Optionen für alle Upload-Ziele jenseits der reinen Callbook-
// Lookups (die bleiben in [[CallbookSettings]]). Aktuell nur UI-Platzhalter —
// die echten API-Calls (LoTW/eQSL/Club Log/HRDLOG) werden in einer späteren
// Session implementiert (siehe ERWEITERUNGEN_PLAN bzw. project_logbuch.md
// Phase 6 Upload-APIs).
//
// Award-Programme (POTA/SOTA/WWFF/BOTA) haben hier **kein** Real-Time-
// Upload — der Upload passiert manuell pro Log via Button in der jeweiligen
// Programm-Log-Ansicht. Konfiguration liegt aber zentral hier.
@MainActor
final class UploadServicesSettings: ObservableObject {

    // MARK: - Master-Toggle (gilt nur für Logbuch-Upload-Services)

    @Published var realTimeUploadMasterEnabled: Bool

    // MARK: - Logbuch-Upload-Services (Real-Time fähig, Implementation folgt)

    // LoTW (ARRL)
    @Published var lotwLocation:       String
    @Published var lotwPassword:       String
    @Published var lotwWebUsername:    String
    @Published var lotwWebPassword:    String
    @Published var lotwAutoUpload:     Bool
    @Published var lotwMarkQslSent:    Bool

    // eQSL.cc
    @Published var eqslUsername:       String
    @Published var eqslPassword:       String
    @Published var eqslNickname:       String
    @Published var eqslAutoUpload:     Bool
    @Published var eqslMarkQslSent:    Bool

    // Club Log
    @Published var clublogEmail:       String
    @Published var clublogPassword:    String
    @Published var clublogAutoUpload:  Bool
    @Published var clublogMarkQslSent: Bool
    @Published var clublogShowInComments: Bool

    // HRDLOG.net
    @Published var hrdlogUploadCode:   String
    @Published var hrdlogAutoUpload:   Bool
    @Published var hrdlogMarkQslSent:  Bool

    // QRZ Logbook (live, Phase 6 Schritt 1). API-Key (32-Hex) erzeugt der
    // User in seinem QRZ-Account → Settings → API Keys. Auto-Upload feuert
    // nur bei Standard-Logs (DX); Outdoor-Programme (POTA/SOTA/WWFF/BOTA)
    // bleiben außen vor, weil dort eigene Upload-Pfade greifen.
    @Published var qrzLogbookApiKey:        String
    @Published var qrzAutoUploadOnLog:      Bool

    // MARK: - Zusätzliche Callbooks (read-only, Implementation folgt)

    // QRZCQ (alternative zu QRZ.com für non-US)
    @Published var qrzcqUsername:      String
    @Published var qrzcqPassword:      String

    // HamCall
    @Published var hamcallUsername:    String
    @Published var hamcallPassword:    String

    // MARK: - Award-Programme (KEIN Real-Time-Upload, Konfig zentral)

    // pota.app — aktuell nur Username persistiert (für späteren Auto-Upload).
    // Auto-Upload via Cognito-SRP-Auth wurde am 2026-05-16 versucht und
    // wieder zurückgerollt (NotAuthorizedException, Crypto-Math passte nicht
    // gegen POTAs Hosted-UI-Pool). User-Workflow: ADIF-Export → manuell auf
    // pota.app hochladen, siehe PotaUploadSheet.
    @Published var potaUsername:       String

    // sotadata.org.uk
    @Published var sotaUsername:       String
    @Published var sotaPassword:       String

    // wwff.cc (kein API — nur Konfig für späteren CSV-Workflow)
    @Published var wwffUsername:       String
    @Published var wwffPassword:       String

    // bunkersontheair.com (kein API verfügbar, nur Platzhalter)
    @Published var botaUsername:       String
    @Published var botaPassword:       String

    // MARK: - Auto-Suggest aus Callbook (welche Felder dürfen überschrieben werden)

    @Published var suggestName:        Bool
    @Published var suggestQTH:         Bool
    @Published var suggestLocator:     Bool
    @Published var suggestCountry:     Bool
    @Published var suggestDXCC:        Bool
    @Published var suggestCQZone:      Bool
    @Published var suggestITUZone:     Bool
    @Published var suggestIOTA:        Bool
    @Published var suggestState:       Bool
    @Published var suggestCounty:      Bool

    private var cancellables = Set<AnyCancellable>()

    init() {
        let s = UserDefaults.appShared
        let p = "uploadServices."

        // Master
        self.realTimeUploadMasterEnabled = (s.object(forKey: p + "realTimeMaster") as? Bool) ?? false

        // LoTW
        self.lotwLocation     = s.string(forKey: p + "lotw.location")    ?? ""
        self.lotwPassword     = s.string(forKey: p + "lotw.password")    ?? ""
        self.lotwWebUsername  = s.string(forKey: p + "lotw.webUsername") ?? ""
        self.lotwWebPassword  = s.string(forKey: p + "lotw.webPassword") ?? ""
        self.lotwAutoUpload   = (s.object(forKey: p + "lotw.auto") as? Bool) ?? false
        self.lotwMarkQslSent  = (s.object(forKey: p + "lotw.markQsl") as? Bool) ?? true

        // eQSL
        self.eqslUsername     = s.string(forKey: p + "eqsl.username") ?? ""
        self.eqslPassword     = s.string(forKey: p + "eqsl.password") ?? ""
        self.eqslNickname     = s.string(forKey: p + "eqsl.nickname") ?? ""
        self.eqslAutoUpload   = (s.object(forKey: p + "eqsl.auto") as? Bool) ?? false
        self.eqslMarkQslSent  = (s.object(forKey: p + "eqsl.markQsl") as? Bool) ?? true

        // Club Log
        self.clublogEmail            = s.string(forKey: p + "clublog.email")    ?? ""
        self.clublogPassword         = s.string(forKey: p + "clublog.password") ?? ""
        self.clublogAutoUpload       = (s.object(forKey: p + "clublog.auto") as? Bool) ?? false
        self.clublogMarkQslSent      = (s.object(forKey: p + "clublog.markQsl") as? Bool) ?? false
        self.clublogShowInComments   = (s.object(forKey: p + "clublog.showInComments") as? Bool) ?? false

        // HRDLOG
        self.hrdlogUploadCode  = s.string(forKey: p + "hrdlog.uploadCode") ?? ""
        self.hrdlogAutoUpload  = (s.object(forKey: p + "hrdlog.auto") as? Bool) ?? false
        self.hrdlogMarkQslSent = (s.object(forKey: p + "hrdlog.markQsl") as? Bool) ?? false

        // QRZ Logbook
        self.qrzLogbookApiKey      = s.string(forKey: p + "qrzLogbook.apiKey") ?? ""
        self.qrzAutoUploadOnLog    = (s.object(forKey: p + "qrzLogbook.auto") as? Bool) ?? false

        // QRZCQ
        self.qrzcqUsername  = s.string(forKey: p + "qrzcq.username") ?? ""
        self.qrzcqPassword  = s.string(forKey: p + "qrzcq.password") ?? ""

        // HamCall
        self.hamcallUsername = s.string(forKey: p + "hamcall.username") ?? ""
        self.hamcallPassword = s.string(forKey: p + "hamcall.password") ?? ""

        // POTA — Migrations-Cleanup: alte experimentelle Felder aus
        // gescheitertem SRP-Versuch (2026-05-16) wegräumen.
        s.removeObject(forKey: p + "pota.token")
        self.potaUsername  = s.string(forKey: p + "pota.username") ?? ""

        // SOTA
        self.sotaUsername  = s.string(forKey: p + "sota.username") ?? ""
        self.sotaPassword  = s.string(forKey: p + "sota.password") ?? ""

        // WWFF
        self.wwffUsername  = s.string(forKey: p + "wwff.username") ?? ""
        self.wwffPassword  = s.string(forKey: p + "wwff.password") ?? ""

        // BOTA
        self.botaUsername  = s.string(forKey: p + "bota.username") ?? ""
        self.botaPassword  = s.string(forKey: p + "bota.password") ?? ""

        // Auto-Suggest (Default: nur die offensichtlich nützlichen an)
        self.suggestName    = (s.object(forKey: p + "suggest.name")    as? Bool) ?? true
        self.suggestQTH     = (s.object(forKey: p + "suggest.qth")     as? Bool) ?? true
        self.suggestLocator = (s.object(forKey: p + "suggest.locator") as? Bool) ?? true
        self.suggestCountry = (s.object(forKey: p + "suggest.country") as? Bool) ?? true
        self.suggestDXCC    = (s.object(forKey: p + "suggest.dxcc")    as? Bool) ?? true
        self.suggestCQZone  = (s.object(forKey: p + "suggest.cqzone")  as? Bool) ?? false
        self.suggestITUZone = (s.object(forKey: p + "suggest.ituzone") as? Bool) ?? false
        self.suggestIOTA    = (s.object(forKey: p + "suggest.iota")    as? Bool) ?? false
        self.suggestState   = (s.object(forKey: p + "suggest.state")   as? Bool) ?? false
        self.suggestCounty  = (s.object(forKey: p + "suggest.county")  as? Bool) ?? false

        // Persistenz via Combine — feuert zuverlässig auch bei SecureField
        bind($realTimeUploadMasterEnabled, to: p + "realTimeMaster", in: s)

        bind($lotwLocation,    to: p + "lotw.location",    in: s)
        bind($lotwPassword,    to: p + "lotw.password",    in: s)
        bind($lotwWebUsername, to: p + "lotw.webUsername", in: s)
        bind($lotwWebPassword, to: p + "lotw.webPassword", in: s)
        bind($lotwAutoUpload,  to: p + "lotw.auto",        in: s)
        bind($lotwMarkQslSent, to: p + "lotw.markQsl",     in: s)

        bind($eqslUsername,    to: p + "eqsl.username",    in: s)
        bind($eqslPassword,    to: p + "eqsl.password",    in: s)
        bind($eqslNickname,    to: p + "eqsl.nickname",    in: s)
        bind($eqslAutoUpload,  to: p + "eqsl.auto",        in: s)
        bind($eqslMarkQslSent, to: p + "eqsl.markQsl",     in: s)

        bind($clublogEmail,          to: p + "clublog.email",          in: s)
        bind($clublogPassword,       to: p + "clublog.password",       in: s)
        bind($clublogAutoUpload,     to: p + "clublog.auto",           in: s)
        bind($clublogMarkQslSent,    to: p + "clublog.markQsl",        in: s)
        bind($clublogShowInComments, to: p + "clublog.showInComments", in: s)

        bind($hrdlogUploadCode,  to: p + "hrdlog.uploadCode", in: s)
        bind($hrdlogAutoUpload,  to: p + "hrdlog.auto",       in: s)
        bind($hrdlogMarkQslSent, to: p + "hrdlog.markQsl",    in: s)

        bind($qrzLogbookApiKey,   to: p + "qrzLogbook.apiKey", in: s)
        bind($qrzAutoUploadOnLog, to: p + "qrzLogbook.auto",   in: s)

        bind($qrzcqUsername,   to: p + "qrzcq.username",   in: s)
        bind($qrzcqPassword,   to: p + "qrzcq.password",   in: s)

        bind($hamcallUsername, to: p + "hamcall.username", in: s)
        bind($hamcallPassword, to: p + "hamcall.password", in: s)

        bind($potaUsername, to: p + "pota.username", in: s)

        bind($sotaUsername, to: p + "sota.username", in: s)
        bind($sotaPassword, to: p + "sota.password", in: s)

        bind($wwffUsername, to: p + "wwff.username", in: s)
        bind($wwffPassword, to: p + "wwff.password", in: s)

        bind($botaUsername, to: p + "bota.username", in: s)
        bind($botaPassword, to: p + "bota.password", in: s)

        bind($suggestName,    to: p + "suggest.name",    in: s)
        bind($suggestQTH,     to: p + "suggest.qth",     in: s)
        bind($suggestLocator, to: p + "suggest.locator", in: s)
        bind($suggestCountry, to: p + "suggest.country", in: s)
        bind($suggestDXCC,    to: p + "suggest.dxcc",    in: s)
        bind($suggestCQZone,  to: p + "suggest.cqzone",  in: s)
        bind($suggestITUZone, to: p + "suggest.ituzone", in: s)
        bind($suggestIOTA,    to: p + "suggest.iota",    in: s)
        bind($suggestState,   to: p + "suggest.state",   in: s)
        bind($suggestCounty,  to: p + "suggest.county",  in: s)
    }

    private func bind<T>(_ pub: Published<T>.Publisher,
                         to key: String,
                         in store: UserDefaults) where T: Equatable {
        pub.dropFirst().sink { newValue in
            store.set(newValue, forKey: key)
        }.store(in: &cancellables)
    }
}
