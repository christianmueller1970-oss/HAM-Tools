import Foundation

enum CATError: Error, LocalizedError {
    case rigctldNotFound(searchedPaths: [String])
    case rigctldLaunchFailed(underlying: Error)
    case rigctldExitedUnexpectedly(code: Int32, stderr: String)
    case connectionFailed(underlying: Error)
    case connectionClosed
    case timeout
    case protocolError(message: String)
    case noProfileSelected
    case noPortSelected

    var errorDescription: String? {
        switch self {
        case .rigctldNotFound(let paths):
            return "rigctld nicht gefunden. Geprüfte Pfade: \(paths.joined(separator: ", "))"
        case .rigctldLaunchFailed(let err):
            return "rigctld konnte nicht gestartet werden: \(err.localizedDescription)"
        case .rigctldExitedUnexpectedly(let code, let stderr):
            return "rigctld beendet (Exit \(code)): \(stderr.prefix(200))"
        case .connectionFailed(let err):
            return "TCP-Verbindung zu rigctld fehlgeschlagen: \(err.localizedDescription)"
        case .connectionClosed:
            return "Verbindung zu rigctld unterbrochen."
        case .timeout:
            return "Timeout beim Warten auf Antwort von rigctld."
        case .protocolError(let msg):
            return "Protokoll-Fehler: \(msg)"
        case .noProfileSelected:
            return "Kein TRX-Profil ausgewählt."
        case .noPortSelected:
            return "Kein serieller Port ausgewählt."
        }
    }
}
