import Foundation

// Cognito-Login gegen den pota.app User Pool. Wir nutzen den
// USER_PASSWORD_AUTH-Flow ohne AWS SDK — Cognito akzeptiert plain
// HTTPS-POST mit JSON-Body und gibt direkt das ID-Token zurück, das
// pota.app als `authorization`-Header erwartet.
//
// Pool/Client-IDs aus dem geleakten JWT abgeleitet (HAR-Analyse 2026-05-16):
//   "iss":   "https://cognito-idp.us-east-2.amazonaws.com/us-east-2_nA5jZ0klh"
//   "aud":   "7hluqct0n2nckib7i7sd5753oa"
//
// Wenn POTA seinen User Pool je migriert, müssen die zwei Konstanten unten
// nachgeführt werden.
//
// Caveat: Sollte Cognito USER_PASSWORD_AUTH für diesen Pool nicht erlauben,
// gibt der erste Login-Versuch `InvalidParameterException: USER_PASSWORD_AUTH
// is not enabled for the client` zurück. Dann müssen wir auf USER_SRP_AUTH
// umstellen (~200 LOC SRP-Math). Trial-and-Error beim ersten echten Login.
@MainActor
final class CognitoAuthService: ObservableObject {

    static let region   = "us-east-2"
    static let clientID = "7hluqct0n2nckib7i7sd5753oa"
    static let endpoint = URL(string: "https://cognito-idp.us-east-2.amazonaws.com/")!

    struct Tokens {
        let idToken:      String   // verwendet als pota.app `authorization` Header
        let accessToken:  String
        let refreshToken: String?
        let expiresAt:    Date     // ID-Token-Ablauf (typ. 60 Min nach Login)
    }

    enum AuthError: LocalizedError {
        case invalidResponse
        case authFailure(code: String, message: String)
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:          return "Unerwartete Antwort von Cognito"
            case .authFailure(_, let msg):  return msg
            case .networkError(let msg):    return msg
            }
        }
    }

    // In-Memory-Cache, damit wir bei mehreren Uploads in Folge nicht jedes
    // Mal neu einloggen. Persistierung wäre möglich, aber: Token-Lifetime
    // ist nur 60 Min und Keychain-Refresh-Roundtrip ist's nicht wert.
    private var cachedTokens: Tokens?

    /// Liefert ein gültiges ID-Token. Frischer Login wenn:
    ///   • noch kein Token gecached
    ///   • Token läuft in <60s ab (Sicherheits-Puffer)
    /// Sonst der Cache-Wert.
    func validIdToken(username: String, password: String) async throws -> String {
        if let t = cachedTokens, t.expiresAt.timeIntervalSinceNow > 60 {
            return t.idToken
        }
        let fresh = try await signIn(username: username, password: password)
        cachedTokens = fresh
        return fresh.idToken
    }

    /// Cache räumen — z. B. wenn Passwort geändert wurde oder die App den
    /// Cognito-Endpoint aus anderen Gründen neu kontaktieren soll.
    func clearCache() {
        cachedTokens = nil
    }

    /// USER_PASSWORD_AUTH gegen Cognito. Wirft AuthError bei Login-
    /// Problemen, Network-Fehlern oder unerwarteten Antwort-Strukturen.
    func signIn(username: String, password: String) async throws -> Tokens {
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        req.setValue("AWSCognitoIdentityProviderService.InitiateAuth",
                     forHTTPHeaderField: "X-Amz-Target")

        let body: [String: Any] = [
            "AuthFlow": "USER_PASSWORD_AUTH",
            "ClientId": Self.clientID,
            "AuthParameters": [
                "USERNAME": username,
                "PASSWORD": password
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }
        guard let http = resp as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        // Cognito-Fehler kommen als JSON mit __type/message. HTTP-Status ist
        // dann oft 400, manchmal 401.
        if http.statusCode != 200 {
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let type = (dict["__type"] as? String) ?? "UnknownError"
                let msg  = (dict["message"] as? String) ?? "HTTP \(http.statusCode)"
                throw AuthError.authFailure(code: type, message: msg)
            }
            throw AuthError.authFailure(code: "HTTP\(http.statusCode)",
                                        message: "HTTP \(http.statusCode)")
        }

        // Erfolgreiche Antwort: { AuthenticationResult: { IdToken, AccessToken,
        // RefreshToken, ExpiresIn, TokenType } }
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let auth = root["AuthenticationResult"] as? [String: Any],
            let idToken     = auth["IdToken"]     as? String,
            let accessToken = auth["AccessToken"] as? String,
            let expiresIn   = auth["ExpiresIn"]   as? Int
        else {
            throw AuthError.invalidResponse
        }
        let refreshToken = auth["RefreshToken"] as? String
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        return Tokens(idToken: idToken,
                      accessToken: accessToken,
                      refreshToken: refreshToken,
                      expiresAt: expiresAt)
    }
}
