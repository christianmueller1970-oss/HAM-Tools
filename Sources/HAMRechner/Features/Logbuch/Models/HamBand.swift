import Foundation

// HF/VHF/UHF Amateurfunk-Bänder. Wird gebraucht für HamBand-Auto-Detection
// aus Frequenz + ADIF-konforme HamBand-Bezeichner.
enum HamBand: String, CaseIterable, Identifiable {
    case b2200m  = "2200m"
    case b630m   = "630m"
    case b160m   = "160m"
    case b80m    = "80m"
    case b60m    = "60m"
    case b40m    = "40m"
    case b30m    = "30m"
    case b20m    = "20m"
    case b17m    = "17m"
    case b15m    = "15m"
    case b12m    = "12m"
    case b10m    = "10m"
    case b6m     = "6m"
    case b4m     = "4m"
    case b2m     = "2m"
    case b70cm   = "70cm"
    case b23cm   = "23cm"
    case b13cm   = "13cm"

    var id: String { rawValue }

    var displayName: String { rawValue }

    // (MHz-Range), Werte aus ADIF HamBand-Tabelle bzw. IARU R1.
    var frequencyRangeMHz: ClosedRange<Double> {
        switch self {
        case .b2200m: return 0.1357...0.1378
        case .b630m:  return 0.472...0.479
        case .b160m:  return 1.810...2.000
        case .b80m:   return 3.500...3.800
        case .b60m:   return 5.351...5.366
        case .b40m:   return 7.000...7.200
        case .b30m:   return 10.100...10.150
        case .b20m:   return 14.000...14.350
        case .b17m:   return 18.068...18.168
        case .b15m:   return 21.000...21.450
        case .b12m:   return 24.890...24.990
        case .b10m:   return 28.000...29.700
        case .b6m:    return 50.000...52.000
        case .b4m:    return 70.000...70.500
        case .b2m:    return 144.000...146.000
        case .b70cm:  return 430.000...440.000
        case .b23cm:  return 1240.000...1300.000
        case .b13cm:  return 2300.000...2450.000
        }
    }

    static func from(frequencyMHz freq: Double) -> HamBand? {
        HamBand.allCases.first { $0.frequencyRangeMHz.contains(freq) }
    }
}
