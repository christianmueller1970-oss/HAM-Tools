import Foundation

struct DXSpot: Identifiable, Equatable {
    let id = UUID()
    var spotter:     String
    var frequency:   Double
    var dxCall:      String
    var comment:     String
    var spotTime:    String
    var source:      String

    var band:        String = ""
    var mode:        String = ""
    var country:     String = ""
    var continent:   String = ""
    var lat:         Double = 0
    var lon:         Double = 0
    var spotterLat:  Double = 0
    var spotterLon:  Double = 0
    var timestamp:   Date   = Date()

    // Which logical source type (for filter checkboxes)
    var sourceType: String {
        if source.contains("SOTAwatch") || source == "SOTAwatch3" { return "SOTAwatch3" }
        if source == "POTA"  { return "POTA" }
        if source == "WWFF"  { return "WWFF" }
        return "DX"
    }

    var ageMinutes: Double {
        Date().timeIntervalSince(timestamp) / 60
    }

    var displayTime: String {
        spotTime.isEmpty ? timestamp.formatted(.dateTime.hour().minute().timeZone()) : spotTime
    }

    var displayFreq: String {
        String(format: "%.1f", frequency)
    }

    var isValid: Bool {
        dxCall.count >= 3 && spotter.count >= 3 && frequency > 0
    }
}
