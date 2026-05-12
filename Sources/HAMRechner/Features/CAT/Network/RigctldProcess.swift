import Foundation

// Verwaltet den rigctld-Subprocess: Lookup im App-Bundle (Production) oder
// Dev-Pfad (vendor/hamlib/rigctld), defensiv chmod +x (Google-Drive frisst das),
// Start mit korrekten Argumenten, Capture von stderr, Stop.
final class RigctldProcess {
    private var process: Process?
    private var stderrPipe: Pipe?

    private(set) var lastStderr: String = ""

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    func start(profile: TRXProfile, serialPort: String, baudRate: Int,
               tcpPort: Int = 4532) throws {
        let binaryURL = try Self.locateBinary()
        try Self.ensureExecutable(at: binaryURL)

        let p = Process()
        p.executableURL = binaryURL
        p.arguments = [
            "-m", String(profile.hamlibRigNumber),
            "-r", serialPort,
            "-s", String(baudRate),
            "-t", String(tcpPort),
        ]

        let errPipe = Pipe()
        p.standardError = errPipe
        p.standardOutput = Pipe()    // verwerfen
        stderrPipe = errPipe

        // stderr-Reader im Hintergrund (für Diagnose).
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { return }
            if let s = String(data: data, encoding: .utf8) {
                // Begrenzen, damit kein OOM bei chatty rigctld.
                self?.lastStderr.append(s)
                if let self, self.lastStderr.count > 8000 {
                    self.lastStderr = String(self.lastStderr.suffix(4000))
                }
            }
        }

        do {
            try p.run()
            process = p
        } catch {
            throw CATError.rigctldLaunchFailed(underlying: error)
        }
    }

    func stop() {
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process?.waitUntilExit()
        process = nil
        stderrPipe = nil
    }

    // MARK: - Binary-Lookup

    static func locateBinary() throws -> URL {
        var searched: [String] = []

        // 1) Im App-Bundle (Production-Layout)
        let bundleURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/rigctld")
        searched.append(bundleURL.path)
        if FileManager.default.isExecutableFile(atPath: bundleURL.path) {
            return bundleURL
        }
        // Existiert vielleicht aber nicht ausführbar (Drive-Mode-Bit) → erlauben
        if FileManager.default.fileExists(atPath: bundleURL.path) {
            return bundleURL
        }

        // 2) Override via Environment (Dev-Bequemlichkeit)
        if let envPath = ProcessInfo.processInfo.environment["HAMLOG_RIGCTLD_PATH"] {
            searched.append(envPath)
            if FileManager.default.fileExists(atPath: envPath) {
                return URL(fileURLWithPath: envPath)
            }
        }

        // 3) Dev-Pfad: vendor/hamlib/rigctld relativ zum aktuellen Workdir
        let cwd = FileManager.default.currentDirectoryPath
        let devPath = cwd + "/vendor/hamlib/rigctld"
        searched.append(devPath)
        if FileManager.default.fileExists(atPath: devPath) {
            return URL(fileURLWithPath: devPath)
        }

        throw CATError.rigctldNotFound(searchedPaths: searched)
    }

    static func ensureExecutable(at url: URL) throws {
        let path = url.path
        if FileManager.default.isExecutableFile(atPath: path) { return }
        // chmod +x — defensiv, da Google Drive das Bit frisst.
        let attrs: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
        try FileManager.default.setAttributes(attrs, ofItemAtPath: path)
    }
}
