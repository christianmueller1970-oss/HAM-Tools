import Foundation

// MARK: - DXCC prefix database
// Format: prefix -> (country, continent, lat, lon)

typealias DXCCEntry = (country: String, continent: String, lat: Double, lon: Double)

let DXCC_DATA: [String: DXCCEntry] = [
    // Europa
    "HB9":("Switzerland","EU",46.8,8.2),    "HB0":("Liechtenstein","EU",47.1,9.5),
    "OE": ("Austria","EU",47.8,13.0),
    "DL": ("Germany","EU",51.0,10.0),       "DJ":("Germany","EU",51.0,10.0),
    "DK": ("Germany","EU",51.0,10.0),       "DA":("Germany","EU",51.0,10.0),
    "F":  ("France","EU",46.0,2.0),
    "G":  ("England","EU",51.5,-0.1),       "M":("England","EU",51.5,-0.1),
    "2E": ("England","EU",51.5,-0.1),
    "I":  ("Italy","EU",42.0,12.5),         "IK":("Italy","EU",42.0,12.5),
    "IZ": ("Italy","EU",42.0,12.5),
    "ON": ("Belgium","EU",50.5,4.5),        "OO":("Belgium","EU",50.5,4.5),
    "PA": ("Netherlands","EU",52.3,5.3),    "PD":("Netherlands","EU",52.3,5.3),
    "PE": ("Netherlands","EU",52.3,5.3),    "PI":("Netherlands","EU",52.3,5.3),
    "SP": ("Poland","EU",52.0,20.0),
    "OK": ("Czech Republic","EU",50.0,15.5),"OL":("Czech Republic","EU",50.0,15.5),
    "OM": ("Slovakia","EU",48.7,19.5),
    "HA": ("Hungary","EU",47.0,19.0),       "HG":("Hungary","EU",47.0,19.0),
    "YO": ("Romania","EU",45.0,25.0),
    "LZ": ("Bulgaria","EU",42.5,25.5),
    "SV": ("Greece","EU",38.0,23.7),
    "YU": ("Serbia","EU",44.0,21.0),        "YT":("Serbia","EU",44.0,21.0),
    "S5": ("Slovenia","EU",46.0,14.5),
    "OZ": ("Denmark","EU",56.0,10.0),
    "SM": ("Sweden","EU",59.0,15.0),        "SA":("Sweden","EU",59.0,15.0),
    "OH": ("Finland","EU",60.0,25.0),       "OF":("Finland","EU",60.0,25.0),
    "LA": ("Norway","EU",60.0,8.0),         "LB":("Norway","EU",60.0,8.0),
    "TF": ("Iceland","EU",65.0,-18.0),
    "ES": ("Estonia","EU",58.5,25.0),
    "YL": ("Latvia","EU",57.0,25.0),
    "LY": ("Lithuania","EU",55.0,24.0),
    "EW": ("Belarus","EU",53.0,28.0),
    "UR": ("Ukraine","EU",50.0,30.0),       "UT":("Ukraine","EU",50.0,30.0),
    "UX": ("Ukraine","EU",50.0,30.0),
    "UA": ("European Russia","EU",55.8,37.6),     "RA":("European Russia","EU",55.8,37.6),
    "RK": ("European Russia","EU",55.8,37.6),     "RN":("European Russia","EU",55.8,37.6),
    "RU": ("European Russia","EU",55.8,37.6),     "RW":("European Russia","EU",55.8,37.6),
    "RZ": ("European Russia","EU",55.8,37.6),
    "EA": ("Spain","EU",40.0,-4.0),         "EB":("Spain","EU",40.0,-4.0),
    "EC": ("Spain","EU",40.0,-4.0),
    "CT": ("Portugal","EU",39.5,-8.0),      "CS":("Portugal","EU",39.5,-8.0),
    "LX": ("Luxembourg","EU",49.8,6.1),
    "EI": ("Ireland","EU",53.0,-8.0),       "EJ":("Ireland","EU",53.0,-8.0),
    "GD": ("Isle of Man","EU",54.2,-4.5),
    "GW": ("Wales","EU",52.0,-3.5),         "GM":("Scotland","EU",57.0,-4.0),
    "GI": ("N. Ireland","EU",54.6,-6.0),
    "OY": ("Faroe Islands","EU",62.0,-7.0),
    "TK": ("Corsica","EU",42.0,9.0),        "IS0":("Sardinia","EU",40.0,9.0),
    "IT9": ("Sicily","EU",37.5,14.0),
    "9A": ("Croatia","EU",45.5,16.0),       "E7":("Bosnia","EU",44.0,17.5),
    "ZA": ("Albania","EU",41.0,20.0),       "Z3":("N. Macedonia","EU",41.6,21.7),
    "T7": ("San Marino","EU",43.9,12.5),    "HV":("Vatican City","EU",41.9,12.5),
    "TA": ("Turkey","AS",39.0,35.0),        "TC":("Turkey","AS",39.0,35.0),
    "5B4":("Cyprus","AS",35.0,33.0),
    // Nordamerika
    "K":  ("USA","NA",38.0,-97.0),          "W":("USA","NA",38.0,-97.0),
    "N":  ("USA","NA",38.0,-97.0),          "AA":("USA","NA",38.0,-97.0),
    "AB": ("USA","NA",38.0,-97.0),          "AC":("USA","NA",38.0,-97.0),
    "AD": ("USA","NA",38.0,-97.0),          "AE":("USA","NA",38.0,-97.0),
    "AF": ("USA","NA",38.0,-97.0),          "AG":("USA","NA",38.0,-97.0),
    "AH": ("USA","NA",38.0,-97.0),          "AI":("USA","NA",38.0,-97.0),
    "AK": ("USA","NA",38.0,-97.0),
    "VE": ("Canada","NA",60.0,-96.0),       "VA":("Canada","NA",60.0,-96.0),
    "VO": ("Canada","NA",60.0,-96.0),       "VY":("Canada","NA",60.0,-96.0),
    "XE": ("Mexico","NA",23.0,-102.0),
    "TI": ("Costa Rica","NA",10.0,-84.0),   "HP":("Panama","NA",9.0,-79.5),
    "CO": ("Cuba","NA",22.0,-80.0),         "HH":("Haiti","NA",19.0,-72.5),
    "HI": ("Dom. Republic","NA",19.0,-70.5),"6Y":("Jamaica","NA",18.0,-77.0),
    "KP4":("Puerto Rico","NA",18.2,-66.5),  "VP9":("Bermuda","NA",32.3,-64.7),
    // Südamerika
    "PY": ("Brazil","SA",-10.0,-55.0),      "PP":("Brazil","SA",-10.0,-55.0),
    "LU": ("Argentina","SA",-34.0,-64.0),   "CE":("Chile","SA",-30.0,-71.0),
    "OA": ("Peru","SA",-10.0,-76.0),        "HC":("Ecuador","SA",-2.0,-78.0),
    "YV": ("Venezuela","SA",8.0,-66.0),     "HK":("Colombia","SA",4.0,-73.0),
    "PZ": ("Suriname","SA",4.0,-56.0),      "GY":("Guyana","SA",5.0,-59.0),
    "ZP": ("Paraguay","SA",-23.0,-58.0),    "CX":("Uruguay","SA",-33.0,-56.0),
    // Asien
    "JA": ("Japan","AS",36.0,138.0),        "JH":("Japan","AS",36.0,138.0),
    "JR": ("Japan","AS",36.0,138.0),        "JE":("Japan","AS",36.0,138.0),
    "BY": ("China","AS",35.0,105.0),        "BA":("China","AS",35.0,105.0),
    "BG": ("China","AS",35.0,105.0),        "BD":("China","AS",35.0,105.0),
    "HL": ("S. Korea","AS",37.0,127.0),     "DS":("S. Korea","AS",37.0,127.0),
    "BV": ("Taiwan","AS",23.5,121.0),
    "VU": ("India","AS",20.0,77.0),         "VK9":("Australia","OC",-25.0,133.0),
    "HS": ("Thailand","AS",15.0,101.0),     "XW":("Laos","AS",18.0,103.0),
    "XV": ("Vietnam","AS",16.0,108.0),      "YB":("Indonesia","OC",-5.0,120.0),
    "DU": ("Philippines","AS",13.0,122.0),
    "9V": ("Singapore","AS",1.3,103.8),
    "A6": ("UAE","AS",24.0,54.0),           "A9":("Bahrain","AS",26.0,50.5),
    "4X": ("Israel","AS",31.5,35.0),        "4Z":("Israel","AS",31.5,35.0),
    "EP": ("Iran","AS",32.0,53.0),          "UN":("Kazakhstan","AS",48.0,68.0),
    "UK": ("Uzbekistan","AS",41.0,64.0),    "EX":("Kyrgyzstan","AS",41.0,75.0),
    // Ozeanien
    "VK": ("Australia","OC",-25.0,133.0),
    "ZL": ("New Zealand","OC",-40.0,175.0),
    "KH6":("Hawaii","OC",20.0,-157.0),      "KH0":("Mariana Is.","OC",15.2,145.8),
    "KH2":("Guam","OC",13.5,144.8),         "YJ":("Vanuatu","OC",-17.0,168.0),
    "FO": ("French Polynesia","OC",-17.5,-149.5),
    // Afrika
    "ZS": ("South Africa","AF",-29.0,25.0), "ZR":("South Africa","AF",-29.0,25.0),
    "ZU": ("South Africa","AF",-29.0,25.0),
    "EA8":("Canary Is.","AF",28.0,-15.5),   "EA9":("Ceuta","AF",35.9,-5.3),
    "5N": ("Nigeria","AF",8.0,8.0),         "7X":("Algeria","AF",28.0,3.0),
    "CN": ("Morocco","AF",32.0,-6.0),       "ST": ("Sudan","AF",15.0,32.0),
    "ET": ("Ethiopia","AF",9.0,38.0),       "5Z": ("Kenya","AF",-1.0,37.0),
    "9J": ("Zambia","AF",-15.0,28.0),       "ZE": ("Zimbabwe","AF",-20.0,30.0),
    "TZ": ("Mali","AF",17.0,-4.0),          "5T": ("Mauritania","AF",20.0,-10.0),
    "TU": ("Ivory Coast","AF",7.5,-5.5),    "3V": ("Tunisia","AF",34.0,9.0),
    "SU": ("Egypt","AF",27.0,30.0),

    // ---- Most-Wanted DXCC (seltene Entitäten) ----
    // Hinweis: Wo Sub-Entitäten denselben Hauptpräfix teilen, gewinnt longest-match
    // (z.B. "VK0H" Heard vor "VK" Australien, "FT5W" Crozet vor allen anderen FT5*).
    "P5":   ("North Korea","AS",40.0,127.0),
    "3Y0":  ("Bouvet Is.","AF",-54.4,3.4),           // teilen mit Peter I (3Y0/P), Bouvet ist häufiger
    "BS7":  ("Scarborough Reef","AS",15.1,117.7),
    "BV9P": ("Pratas Is.","AS",20.7,116.7),
    "9M0":  ("Spratly Is.","AS",9.0,113.0),
    // Französische Antarktis & Subantarktis
    "FT5G": ("Glorioso Is.","AF",-11.6,47.3),
    "FT5J": ("Juan de Nova","AF",-17.0,42.7),
    "FT5T": ("Tromelin","AF",-15.9,54.5),
    "FT5W": ("Crozet Is.","AF",-46.4,51.8),
    "FT5X": ("Kerguelen","AF",-49.3,69.5),
    "FT5Z": ("Amsterdam & St.Paul","AF",-37.8,77.5),
    // Chile-Außenposten
    "CE0X": ("San Felix","SA",-26.3,-80.1),
    "CE0Y": ("Easter Is.","SA",-27.1,-109.4),
    "CE0Z": ("Juan Fernandez","SA",-33.6,-78.9),
    // Australien-Sub
    "VK0H": ("Heard Is.","AF",-53.1,73.5),
    "VK0M": ("Macquarie Is.","OC",-54.5,158.9),
    "VK9C": ("Cocos (Keeling)","OC",-12.2,96.8),
    "VK9L": ("Lord Howe","OC",-31.5,159.1),
    "VK9M": ("Mellish Reef","OC",-17.4,155.9),
    "VK9N": ("Norfolk Is.","OC",-29.0,167.9),
    "VK9X": ("Christmas Is.","OC",-10.5,105.6),
    // US-Pazifik (KH-Familie, KH6=Hawaii, KH0=Mariana, KH2=Guam bereits oben)
    "KH1":  ("Baker/Howland","OC",0.2,-176.5),
    "KH3":  ("Johnston Atoll","OC",16.7,-169.5),
    "KH4":  ("Midway","OC",28.2,-177.4),
    "KH5":  ("Palmyra/Jarvis","OC",5.9,-162.1),
    "KH7K": ("Kure Atoll","OC",28.4,-178.3),
    "KH8":  ("American Samoa","OC",-14.3,-170.7),
    "KH8S": ("Swains Is.","OC",-11.1,-171.1),
    "KH9":  ("Wake Is.","OC",19.3,166.6),
    // Brasilien-Außenposten
    "PY0F": ("Fernando Noronha","SA",-3.9,-32.4),
    "PY0S": ("St. Peter & Paul","SA",0.9,-29.4),
    "PY0T": ("Trindade","SA",-20.5,-29.3),
    // Pacific
    "VP6":  ("Pitcairn Is.","OC",-25.1,-130.1),
    "ZL7":  ("Chatham Is.","OC",-43.9,-176.5),
    "ZL8":  ("Kermadec Is.","OC",-29.3,-177.9),
    "ZL9":  ("NZ Subantarctic","OC",-50.7,166.1),
    // Süd-Atlantik
    "VP8":  ("Falkland Is.","SA",-51.7,-59.0),       // teilen mit South Georgia/Sandwich/Orkney (selten)
    "ZD7":  ("St. Helena","AF",-15.9,-5.7),
    "ZD8":  ("Ascension","AF",-7.9,-14.4),
    "ZD9":  ("Tristan da Cunha","AF",-37.1,-12.3),
    "ZS8":  ("Prince Edward","AF",-46.9,37.7),
    // Japan-Sub
    "JD1":  ("Ogasawara","AS",27.1,142.2),           // teilen mit Minami Torishima (selten)
    // Französisch-Polynesien Sub
    "TX5":  ("Austral Is.","OC",-23.4,-149.5),
    "TX7":  ("Marquesas Is.","OC",-8.9,-140.0),
    // Kanada-Außenposten
    "CY0":  ("Sable Is.","NA",43.9,-59.9),
    "CY9":  ("St. Paul Is.","NA",47.2,-60.2),
    // Pazifik-Inselstaaten (häufiger gespottet)
    "FK":   ("New Caledonia","OC",-21.5,165.5),
    "FW":   ("Wallis & Futuna","OC",-13.3,-176.2),
    "T2":   ("Tuvalu","OC",-8.0,179.0),
    "T8":   ("Palau","OC",7.5,134.6),
    "V7":   ("Marshall Is.","OC",7.1,171.4),
    "5W":   ("Samoa","OC",-13.8,-172.1),
    "ZK3":  ("Tokelau","OC",-9.0,-171.9),
    // Karibik klein
    "VP2E": ("Anguilla","NA",18.2,-63.0),
    "VP2M": ("Montserrat","NA",16.7,-62.2),
    "VP2V": ("Brit. Virgin Is.","NA",18.4,-64.6),
    "VP5":  ("Turks & Caicos","NA",21.7,-71.5),
    // Indischer Ozean
    "3B7":  ("Agalega/St.Brandon","AF",-10.4,56.6),
    "3B9":  ("Rodrigues Is.","AF",-19.7,63.4),
]

// MARK: - Prefix lookup (longest-match)

func lookupPrefix(_ callsign: String) -> DXCCEntry {
    let upper = callsign.uppercased()
    let maxLen = min(upper.count, 5)
    for len in stride(from: maxLen, through: 1, by: -1) {
        let prefix = String(upper.prefix(len))
        if let entry = DXCC_DATA[prefix] { return entry }
    }
    return ("Unknown", "??", 0.0, 0.0)
}

let CONTINENT_NAMES: [String: String] = [
    "EU": "Europa",  "NA": "Nordamerika", "SA": "Südamerika",
    "AS": "Asien",   "AF": "Afrika",      "OC": "Ozeanien",
    "??": "Unbekannt"
]
