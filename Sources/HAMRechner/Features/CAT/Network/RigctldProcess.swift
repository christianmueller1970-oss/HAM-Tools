import Foundation

// Verwaltet den rigctld-Subprocess: Lookup im App-Bundle (Production) oder
// Dev-Pfad (vendor/hamlib/rigctld), defensiv chmod +x (Google-Drive frisst das),
// Start mit korrekten Argumenten (inkl. Serial-Parametern via -C), Capture
// von stderr, Stop.
final class RigctldProcess {
    private var process: Process?
    private var stderrPipe: Pipe?

    private(set) var lastStderr: String = ""

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    func start(profile: TRXProfile,
               config: CATConfig,
               tcpPort: Int = 4532) throws {
        let binaryURL = try Self.locateBinary()
        try Self.ensureExecutable(at: binaryURL)

        let p = Process()
        p.executableURL = binaryURL

        var args = ["-m", String(profile.hamlibRigNumber)]

        if profile.needsSerialPort,
           let port = config.serialPort, !port.isEmpty {
            args += ["-r", port,
                     "-s", String(config.baudRate)]

            // Serial-Parameter via -C (rigctld set_conf)
            var confParts = [
                "data_bits=\(config.dataBits)",
                "stop_bits=\(config.stopBits)",
                "serial_parity=\(config.parity.rawValue)",
                "serial_handshake=\(config.handshake.rawValue)"
            ]
            // ICOM CI-V Adresse mitgeben wenn das Profil eine kennt. Hamlib
            // akzeptiert das Format "0x94" oder "94" — wir übernehmen, was
            // im Config-Feld steht (User kann editieren).
            if profile.brand == "Icom",
               let civ = config.civAddress?.trimmingCharacters(in: .whitespaces),
               !civ.isEmpty {
                confParts.append("civaddr=\(civ)")
            }
            args += ["-C", confParts.joined(separator: ",")]
        }

        args += ["-t", String(tcpPort)]
        p.arguments = args

        let errPipe = Pipe()
        p.standardError = errPipe
        p.standardOutput = Pipe()    // verwerfen
        stderrPipe = errPipe

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { return }
            if let s = String(data: data, encoding: .utf8) {
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

        let bundleURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/rigctld")
        searched.append(bundleURL.path)
        if FileManager.default.isExecutableFile(atPath: bundleURL.path) {
            return bundleURL
        }
        if FileManager.default.fileExists(atPath: bundleURL.path) {
            return bundleURL
        }

        if let envPath = ProcessInfo.processInfo.environment["HAMLOG_RIGCTLD_PATH"] {
            searched.append(envPath)
            if FileManager.default.fileExists(atPath: envPath) {
                return URL(fileURLWithPath: envPath)
            }
        }

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
        let attrs: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
        try FileManager.default.setAttributes(attrs, ofItemAtPath: path)
    }
}
