import Foundation
import Testing
import WaveLogMate

@Suite struct WavelogAPIClientTests {
  @Test func buildQSOPayload() throws {
    let adif = "<CALL:5>DJ7NT <MODE:3>FT8 <EOR>"
    let payload = try WavelogAPIClient.buildQSOPayload(
      adifString: adif,
      apiKey: "API_KEY",
      stationProfileID: "42"
    )

    let json = try decodeJSON(payload)
    #expect(json["key"] as? String == "API_KEY")
    #expect(json["station_profile_id"] as? String == "42")
    #expect(json["type"] as? String == "adif")
    #expect(json["string"] as? String == adif)
  }

  @Test func buildVersionPayload() throws {
    let payload = try WavelogAPIClient.buildVersionPayload(apiKey: "VERSION_KEY")
    let json = try decodeJSON(payload)

    #expect(json.count == 1)
    #expect(json["key"] as? String == "VERSION_KEY")
  }

  @Test func apiVersionFollowsTokenPrefix() {
    #expect(WavelogAPIClient.apiVersion(for: "wl2_abc123") == .v2)
    #expect(WavelogAPIClient.apiVersion(for: "abc123") == .v1)
    #expect(WavelogAPIClient.apiVersion(for: "wl_abc123") == .v1)
    #expect(WavelogAPIClient.apiVersion(for: "") == .v1)
  }

  @Test func buildV2ADIFPayload() throws {
    let adif = "<CALL:5>DJ7NT <MODE:3>FT8 <EOR>"
    let payload = try WavelogAPIClient.buildV2ADIFPayload(
      adifString: adif,
      stationProfileID: "42",
      dryrun: false
    )

    let json = try decodeJSON(payload)
    #expect(json["station_profile_id"] as? Int == 42)
    #expect(json["import_type"] as? String == "adif")
    #expect(json["adif"] as? String == adif)
    #expect(json["dryrun"] as? Bool == false)
    #expect(json["key"] == nil)
  }

  @Test func buildV2ADIFPayloadSetsDryrun() throws {
    let payload = try WavelogAPIClient.buildV2ADIFPayload(
      adifString: "<CALL:5>DJ7NT <EOR>",
      stationProfileID: "1",
      dryrun: true
    )

    let json = try decodeJSON(payload)
    #expect(json["dryrun"] as? Bool == true)
  }

  @Test func buildV2ADIFPayloadRejectsNonNumericStation() {
    #expect(throws: WavelogAPIClient.APIError.self) {
      try WavelogAPIClient.buildV2ADIFPayload(
        adifString: "<CALL:5>DJ7NT <EOR>",
        stationProfileID: "",
        dryrun: false
      )
    }
  }

  @Test func extractErrorMessageReadsV2Envelope() {
    let body = Data(
      """
      {"error":{"code":"insufficient_scope","message":"Token is missing the required scope: qso:write","details":{}}}
      """.utf8)
    #expect(
      WavelogAPIClient.extractErrorMessage(from: body)
        == "Token is missing the required scope: qso:write")
  }

  @Test func extractErrorMessageReadsV1Reason() {
    let body = Data(#"{"status":"failed","reason":"missing or wrong api key"}"#.utf8)
    #expect(WavelogAPIClient.extractErrorMessage(from: body) == "missing or wrong api key")
  }

  @Test func normalizeURLPrefixesHTTPS() {
    #expect(WavelogAPIClient.normalizeURL("log.example.com") == "https://log.example.com")
    #expect(WavelogAPIClient.normalizeURL("  log.example.com  ") == "https://log.example.com")
  }

  @Test func normalizeURLPreservesExistingScheme() {
    #expect(
      WavelogAPIClient.normalizeURL("https://log.example.com") == "https://log.example.com")
    #expect(
      WavelogAPIClient.normalizeURL("http://log.example.com") == "http://log.example.com")
    #expect(
      WavelogAPIClient.normalizeURL("HTTP://log.example.com") == "HTTP://log.example.com")
  }

  @Test func normalizeURLHandlesEmpty() {
    #expect(WavelogAPIClient.normalizeURL("") == "")
    #expect(WavelogAPIClient.normalizeURL("   ") == "")
  }

  private func decodeJSON(_ data: Data) throws -> [String: Any] {
    let object = try JSONSerialization.jsonObject(with: data)
    guard let dictionary = object as? [String: Any] else {
      Issue.record("Expected JSON dictionary")
      return [:]
    }
    return dictionary
  }
}
