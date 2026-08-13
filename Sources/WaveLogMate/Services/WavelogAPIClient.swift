import Foundation

public final class WavelogAPIClient: @unchecked Sendable {
  public struct APIError: Error, LocalizedError, Sendable {
    public let message: String
    public let statusCode: Int?
    public let rawBody: String?

    public init(message: String, statusCode: Int? = nil, rawBody: String? = nil) {
      self.message = message
      self.statusCode = statusCode
      self.rawBody = rawBody
    }

    public var errorDescription: String? {
      if let statusCode {
        return "\(message) (HTTP \(statusCode))"
      }
      return message
    }
  }

  /// Which Wavelog API a credential targets. API v2 tokens carry a `wl2_`
  /// prefix and the server rejects everything else on `/api/v2`, so the prefix
  /// alone decides the code path — no setting needed.
  public enum APIVersion: Sendable, Equatable {
    case v1
    case v2
  }

  /// How the server identifies itself. v1 reports its release; v2 has no
  /// version endpoint, so the token owner's callsign stands in.
  public enum ServerInfo: Sendable, Equatable {
    case version(String)
    case tokenOwner(String)
  }

  private static let v2TokenPrefix = "wl2_"

  public static func apiVersion(for apiKey: String) -> APIVersion {
    apiKey.hasPrefix(v2TokenPrefix) ? .v2 : .v1
  }

  private struct V1QSOResponse: Decodable, Sendable {
    let status: String
    let messages: [String]?
  }

  private struct V1VersionResponse: Decodable, Sendable {
    let status: String
    let version: String
  }

  private struct V1QSOPayload: Encodable, Sendable {
    let key: String
    let stationProfileID: String
    let type: String
    let string: String

    enum CodingKeys: String, CodingKey {
      case key
      case stationProfileID = "station_profile_id"
      case type
      case string
    }
  }

  private struct V1KeyPayload: Encodable, Sendable {
    let key: String
  }

  /// Every v2 response wraps its payload in `data` alongside a `meta` block.
  private struct V2Envelope<T: Decodable>: Decodable {
    let data: T
  }

  private struct V2ADIFImportPayload: Encodable, Sendable {
    let stationProfileID: Int
    let adif: String
    let dryrun: Bool
    let importType = "adif"

    enum CodingKeys: String, CodingKey {
      case stationProfileID = "station_profile_id"
      case adif
      case dryrun
      case importType = "import_type"
    }
  }

  private struct V2ImportResult: Decodable, Sendable {
    let parsed: Int
    let imported: Int?
    let skipped: Int?
    let messages: [String]?
  }

  private struct V2Token: Decodable, Sendable {
    let owner: String?
  }

  private struct V2Station: Decodable, Sendable {
    let id: Int
    let name: String?
    let callsign: String?
    let gridsquare: String?
    let active: Bool?
  }

  private static let userAgent: String = {
    let version =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    return "WaveLogMate/\(version)"
  }()

  private let urlSession: URLSession
  private let jsonEncoder: JSONEncoder
  private let jsonDecoder: JSONDecoder

  public init(allowSelfSignedCerts: Bool = false, timeout: TimeInterval = 5.0) {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = timeout
    config.timeoutIntervalForResource = timeout
    config.waitsForConnectivity = false

    let delegate = SelfSignedCertificateDelegate(allowSelfSignedCerts: allowSelfSignedCerts)
    self.urlSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    self.jsonEncoder = JSONEncoder()
    self.jsonDecoder = JSONDecoder()
  }

  public func sendQSO(
    adifString: String,
    apiKey: String,
    stationProfileID: String,
    baseURL: String
  ) async throws {
    switch Self.apiVersion(for: apiKey) {
    case .v2:
      let payload = try Self.buildV2ADIFPayload(
        adifString: adifString,
        stationProfileID: stationProfileID,
        dryrun: false
      )
      let request = try buildRequest(
        baseURL: baseURL,
        path: "api/v2/qso",
        method: "POST",
        body: payload,
        bearerToken: apiKey
      )
      let result: V2ImportResult = try await performV2(request, label: "api/v2/qso")

      // A skipped row is a duplicate, which means the QSO is already in the
      // log — the same outcome v1 reports as "created". Only a batch that
      // stored nothing at all is a failure.
      guard (result.imported ?? 0) > 0 || (result.skipped ?? 0) > 0 else {
        throw APIError(message: Self.joinMessages(result.messages) ?? "Wavelog imported no QSO")
      }

    case .v1:
      let payload = try Self.buildQSOPayload(
        adifString: adifString,
        apiKey: apiKey,
        stationProfileID: stationProfileID
      )
      let request = try buildRequest(
        baseURL: baseURL,
        path: "api/qso",
        method: "POST",
        body: payload
      )
      let response: V1QSOResponse = try await perform(
        request, label: "api/qso", decodeAs: V1QSOResponse.self)

      guard response.status.lowercased() == "created" || response.status.lowercased() == "ok" else {
        throw APIError(message: Self.joinMessages(response.messages) ?? "Wavelog rejected QSO")
      }
    }
  }

  public func testConnection(
    apiKey: String,
    stationProfileID: String,
    baseURL: String
  ) async throws -> Bool {
    let testADIF =
      "<CALL:4>TEST <MODE:3>FT8 <FREQ:9>14.074000 <QSO_DATE:8>20240101 <TIME_ON:6>000000 <RST_SENT:3>-10 <RST_RCVD:3>-10 <EOR>"

    switch Self.apiVersion(for: apiKey) {
    case .v2:
      let payload = try Self.buildV2ADIFPayload(
        adifString: testADIF,
        stationProfileID: stationProfileID,
        dryrun: true
      )
      let request = try buildRequest(
        baseURL: baseURL,
        path: "api/v2/qso",
        method: "POST",
        body: payload,
        bearerToken: apiKey
      )
      let result: V2ImportResult = try await performV2(request, label: "api/v2/qso")
      return result.parsed > 0

    case .v1:
      let payload = try Self.buildQSOPayload(
        adifString: testADIF,
        apiKey: apiKey,
        stationProfileID: stationProfileID
      )
      let request = try buildRequest(
        baseURL: baseURL,
        path: "api/qso/true",
        method: "POST",
        body: payload
      )
      let response: V1QSOResponse = try await perform(
        request, label: "api/qso/true", decodeAs: V1QSOResponse.self)
      return response.status.lowercased() == "created" || response.status.lowercased() == "ok"
    }
  }

  public func fetchStationProfiles(
    apiKey: String,
    baseURL: String
  ) async throws -> [StationProfile] {
    switch Self.apiVersion(for: apiKey) {
    case .v2:
      // The list is paginated (50 per page by default); ask for the documented
      // maximum so a single request always returns every station location.
      let request = try buildRequest(
        baseURL: baseURL,
        path: "api/v2/station",
        method: "GET",
        bearerToken: apiKey,
        query: [URLQueryItem(name: "per_page", value: "5000")]
      )
      let stations: [V2Station] = try await performV2(request, label: "api/v2/station")
      return stations.map { station in
        StationProfile(
          stationId: String(station.id),
          stationProfileName: station.name ?? "",
          stationGridsquare: station.gridsquare ?? "",
          stationCallsign: station.callsign ?? "",
          stationActive: (station.active ?? false) ? "1" : "0"
        )
      }

    case .v1:
      let request = try buildRequest(
        baseURL: baseURL,
        path: "api/station_info/\(apiKey)",
        method: "POST",
        body: Data()
      )
      return try await perform(
        request, label: "api/station_info", decodeAs: [StationProfile].self)
    }
  }

  /// Validates the credential and returns what the server identifies itself
  /// with. Doubles as the periodic reachability check.
  public func fetchServerInfo(
    apiKey: String,
    baseURL: String
  ) async throws -> ServerInfo {
    switch Self.apiVersion(for: apiKey) {
    case .v2:
      let request = try buildRequest(
        baseURL: baseURL,
        path: "api/v2/token",
        method: "GET",
        bearerToken: apiKey
      )
      let token: V2Token = try await performV2(request, label: "api/v2/token")
      return .tokenOwner(token.owner ?? "")

    case .v1:
      let request = try buildRequest(
        baseURL: baseURL,
        path: "api/version",
        method: "POST",
        body: try Self.buildVersionPayload(apiKey: apiKey)
      )
      let response: V1VersionResponse = try await perform(
        request, label: "api/version", decodeAs: V1VersionResponse.self)
      return .version(response.version)
    }
  }

  public static func buildQSOPayload(
    adifString: String,
    apiKey: String,
    stationProfileID: String
  ) throws -> Data {
    let payload = V1QSOPayload(
      key: apiKey,
      stationProfileID: stationProfileID,
      type: "adif",
      string: adifString
    )
    return try JSONEncoder().encode(payload)
  }

  public static func buildVersionPayload(apiKey: String) throws -> Data {
    return try JSONEncoder().encode(V1KeyPayload(key: apiKey))
  }

  public static func buildV2ADIFPayload(
    adifString: String,
    stationProfileID: String,
    dryrun: Bool
  ) throws -> Data {
    guard let stationID = Int(stationProfileID.trimmingCharacters(in: .whitespaces)) else {
      throw APIError(message: "Select a station profile first")
    }
    let payload = V2ADIFImportPayload(
      stationProfileID: stationID,
      adif: adifString,
      dryrun: dryrun
    )
    return try JSONEncoder().encode(payload)
  }

  private func buildRequest(
    baseURL: String,
    path: String,
    method: String,
    body: Data? = nil,
    bearerToken: String? = nil,
    query: [URLQueryItem] = []
  ) throws -> URLRequest {
    guard let endpoint = endpointURL(baseURL: baseURL, path: path, query: query) else {
      throw APIError(message: "Invalid Wavelog base URL: \(baseURL)")
    }

    var request = URLRequest(url: endpoint)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
    if let bearerToken {
      request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
    }
    if let body {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = body
    }
    return request
  }

  private func endpointURL(baseURL: String, path: String, query: [URLQueryItem]) -> URL? {
    let normalized = Self.normalizeURL(baseURL)
    guard var url = URL(string: normalized) else {
      return nil
    }

    for component in path.split(separator: "/") {
      url.appendPathComponent(String(component))
    }

    guard !query.isEmpty else { return url }
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return nil
    }
    components.queryItems = query
    return components.url
  }

  public static func normalizeURL(_ urlString: String) -> String {
    let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return trimmed }

    let lowered = trimmed.lowercased()
    if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") {
      return trimmed
    }
    return "https://\(trimmed)"
  }

  private func performV2<T: Decodable>(_ request: URLRequest, label: String) async throws -> T {
    let envelope: V2Envelope<T> = try await perform(
      request, label: label, decodeAs: V2Envelope<T>.self)
    return envelope.data
  }

  private func perform<T: Decodable>(
    _ request: URLRequest,
    label: String,
    decodeAs type: T.Type
  ) async throws -> T {
    Log.api.debug("Sending API request to /\(label, privacy: .public)")

    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await urlSession.data(for: request)
    } catch {
      Log.api.error(
        "Network request failed for /\(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
      )
      let hint =
        Self.isLikelyTLSError(error)
        ? " — if your server doesn't support HTTPS, try using http:// in the URL" : ""
      throw APIError(message: "Network request failed: \(error.localizedDescription)\(hint)")
    }

    guard let http = response as? HTTPURLResponse else {
      Log.api.error("Received non-HTTP response for /\(label, privacy: .public)")
      throw APIError(message: "Invalid HTTP response")
    }

    Log.api.debug(
      "API response status \(http.statusCode, privacy: .public) from /\(label, privacy: .public)"
    )

    guard (200...299).contains(http.statusCode) else {
      let rawBody = String(data: data, encoding: .utf8)
      let message = Self.extractErrorMessage(from: data)
      Log.api.error(
        "API request failed with status \(http.statusCode, privacy: .public): \(message, privacy: .public)"
      )
      throw APIError(message: message, statusCode: http.statusCode, rawBody: rawBody)
    }

    do {
      return try jsonDecoder.decode(T.self, from: data)
    } catch {
      Log.api.error(
        "Failed to decode API response from /\(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
      )
      throw APIError(message: "Failed to decode response: \(error.localizedDescription)")
    }
  }

  private static func isLikelyTLSError(_ error: Error) -> Bool {
    let nsError = error as NSError
    let tlsCodes: Set<Int> = [
      NSURLErrorSecureConnectionFailed,
      NSURLErrorServerCertificateUntrusted,
      NSURLErrorServerCertificateHasBadDate,
      NSURLErrorServerCertificateHasUnknownRoot,
      NSURLErrorServerCertificateNotYetValid,
      NSURLErrorCannotFindHost,
      NSURLErrorCannotConnectToHost,
    ]
    return nsError.domain == NSURLErrorDomain && tlsCodes.contains(nsError.code)
  }

  private static func joinMessages(_ messages: [String]?) -> String? {
    let cleaned =
      (messages ?? [])
      .map { stripHTML($0) }
      .filter { !$0.isEmpty }
    return cleaned.isEmpty ? nil : cleaned.joined(separator: "\n")
  }

  public static func extractErrorMessage(from data: Data) -> String {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return String(data: data, encoding: .utf8) ?? "Unknown error"
    }

    // v2: { "error": { "code": ..., "message": ..., "details": ... } }
    if let error = json["error"] as? [String: Any],
      let message = error["message"] as? String,
      !message.isEmpty
    {
      return stripHTML(message)
    }

    if let reason = json["reason"] as? String, !reason.isEmpty {
      return stripHTML(reason)
    }

    if let messages = json["messages"] as? [String], let joined = joinMessages(messages) {
      return joined
    }

    return String(data: data, encoding: .utf8) ?? "Unknown error"
  }

  private static func stripHTML(_ string: String) -> String {
    var result =
      string
      .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
      .replacingOccurrences(of: "&amp;", with: "&")
      .replacingOccurrences(of: "&lt;", with: "<")
      .replacingOccurrences(of: "&gt;", with: ">")
      .replacingOccurrences(of: "&quot;", with: "\"")
      .replacingOccurrences(of: "&apos;", with: "'")
      .replacingOccurrences(of: "&#39;", with: "'")
      .replacingOccurrences(of: "&#039;", with: "'")

    // Decode numeric HTML entities (&#NNN;)
    while let range = result.range(of: "&#\\d+;", options: .regularExpression) {
      let entity = result[range]
      let digits = entity.dropFirst(2).dropLast()
      if let code = UInt32(digits), let scalar = Unicode.Scalar(code) {
        result.replaceSubrange(range, with: String(scalar))
      } else {
        break
      }
    }

    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

private final class SelfSignedCertificateDelegate: NSObject, URLSessionDelegate, @unchecked Sendable
{
  private let allowSelfSignedCerts: Bool

  init(allowSelfSignedCerts: Bool) {
    self.allowSelfSignedCerts = allowSelfSignedCerts
  }

  func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    guard allowSelfSignedCerts,
      challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
      let serverTrust = challenge.protectionSpace.serverTrust
    else {
      completionHandler(.performDefaultHandling, nil)
      return
    }

    completionHandler(.useCredential, URLCredential(trust: serverTrust))
  }
}
