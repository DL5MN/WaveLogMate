import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
public final class AppState {
  public var wsjtxConnectionStatus: ConnectionStatus = .disconnected
  public var wavelogConnectionStatus: ConnectionStatus = .disconnected

  public var wsjtxStatus: WSJTXStatus = WSJTXStatus()
  public var wsjtxClientId: String = ""
  public var wsjtxVersion: String = ""
  public var wavelogServerInfo: WavelogAPIClient.ServerInfo?

  /// API v1 reports the Wavelog release, v2 has no version endpoint and
  /// reports the token owner instead.
  public var wavelogDetail: String? {
    switch wavelogServerInfo {
    case .version(let version): return version.isEmpty ? nil : "v\(version)"
    case .tokenOwner(let callsign): return callsign.isEmpty ? nil : callsign
    case nil: return nil
    }
  }

  public var recentQSOs: [QSO] = []
  public private(set) var totalQSOsLogged: Int = 0
  public private(set) var totalQSOsFailed: Int = 0

  public var stationProfiles: [StationProfile] = []

  public var config: WavelogConfig = WavelogConfig() {
    didSet {
      guard !isLoadingConfig else { return }
      saveConfig(previous: oldValue)
    }
  }

  public let udpService: UDPService
  public var apiClient: WavelogAPIClient

  public var lastError: String?
  public var showingError: Bool = false

  public var apiKey: String = "" {
    didSet {
      guard apiKey != oldValue else { return }
      do {
        try KeychainHelper.save(key: "wavelog_api_key", value: apiKey)
      } catch {
        Log.api.error(
          "Failed to save API key to Keychain: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  private var heartbeatTimer: Timer?
  private var wavelogCheckTimer: Timer?
  private var textFlashTask: Task<Void, Never>?
  private var isLoadingConfig = false

  public init() {
    self.udpService = UDPService()
    self.apiClient = WavelogAPIClient()
    self.apiKey = (try? KeychainHelper.load(key: "wavelog_api_key")) ?? ""
    loadConfig()
    loadQSOLog()
    setupCallbacks()
    startListening()
    applyDockVisibility()
    checkConnectionsOnStartup()
  }

  private func setupCallbacks() {
    udpService.onQSOReceived = { [weak self] qso in
      Task { @MainActor in
        await self?.handleQSOReceived(qso)
      }
    }

    udpService.onHeartbeat = { [weak self] clientId, version in
      Task { @MainActor in
        self?.wsjtxClientId = clientId
        self?.wsjtxVersion = version
        self?.wsjtxConnectionStatus = .connected
        self?.resetHeartbeatTimer()
      }
    }

    udpService.onStatusUpdate = { [weak self] status in
      Task { @MainActor in
        self?.wsjtxStatus = status
      }
    }

    udpService.onWSJTXClose = { [weak self] _ in
      Task { @MainActor in
        self?.wsjtxConnectionStatus = .disconnected
        self?.heartbeatTimer?.invalidate()
      }
    }

    udpService.onError = { [weak self] error in
      Task { @MainActor in
        self?.lastError = error.localizedDescription
        self?.showingError = true
      }
    }
  }

  private func resetHeartbeatTimer() {
    heartbeatTimer?.invalidate()
    heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
      Task { @MainActor in
        self?.wsjtxConnectionStatus = .disconnected
      }
    }
  }

  private func handleQSOReceived(_ qso: QSO) async {
    if config.udpProtocol == .text {
      wsjtxConnectionStatus = .connected
      textFlashTask?.cancel()
      textFlashTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .seconds(5))
        guard !Task.isCancelled else { return }
        self?.wsjtxConnectionStatus = .listening
      }
    }

    var newQSO = qso

    do {
      let adifString = ADIFGenerator.generate([newQSO])
      try await apiClient.sendQSO(
        adifString: adifString,
        apiKey: apiKey,
        stationProfileID: config.stationProfileID,
        baseURL: config.wavelogURL
      )

      newQSO.loggedSuccessfully = true
      newQSO.loggedAt = Date()
      totalQSOsLogged += 1

      if config.showNotifications {
        NotificationService.sendQSOLoggedNotification(
          call: newQSO.call, band: newQSO.band, mode: newQSO.mode)
      }
    } catch {
      newQSO.loggedSuccessfully = false
      newQSO.logError = error.localizedDescription
      if let apiError = error as? WavelogAPIClient.APIError {
        newQSO.logErrorRaw = apiError.rawBody
      }
      newQSO.loggedAt = Date()
      totalQSOsFailed += 1

      if config.showNotifications {
        NotificationService.sendQSOFailedNotification(
          call: newQSO.call, error: error.localizedDescription)
      }
    }

    recentQSOs.insert(newQSO, at: 0)
    if recentQSOs.count > 10 {
      recentQSOs.removeLast()
    }
    saveQSOLog()
  }

  private func checkConnectionsOnStartup() {
    Task {
      _ = await NotificationService.requestAuthorization()
    }

    if !apiKey.isEmpty && !config.wavelogURL.isEmpty {
      Task { @MainActor in
        await fetchStationProfiles()
        await checkWavelogServer()
      }
    }

    startWavelogCheckTimer()
  }

  private func checkWavelogServer() async {
    guard !apiKey.isEmpty, !config.wavelogURL.isEmpty else { return }
    do {
      wavelogServerInfo = try await apiClient.fetchServerInfo(
        apiKey: apiKey,
        baseURL: config.wavelogURL
      )
      if wavelogConnectionStatus != .connected {
        wavelogConnectionStatus = .connected
      }
    } catch {
      wavelogConnectionStatus = .error
    }
  }

  private func startWavelogCheckTimer() {
    wavelogCheckTimer?.invalidate()
    wavelogCheckTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) {
      [weak self] _ in
      Task { @MainActor in
        await self?.checkWavelogServer()
      }
    }
  }

  public func applyDockVisibility() {
    let policy: NSApplication.ActivationPolicy = config.showInDock ? .regular : .accessory
    NSApplication.shared.setActivationPolicy(policy)
  }

  public func startListening() {
    udpService.stopAll()
    heartbeatTimer?.invalidate()
    textFlashTask?.cancel()
    textFlashTask = nil

    switch config.udpProtocol {
    case .text:
      udpService.startTextListener(port: config.textUDPPort, address: config.listenAddress)
      wsjtxConnectionStatus = .listening
    case .binary:
      udpService.startBinaryListener(port: config.binaryUDPPort, address: config.listenAddress)
      wsjtxConnectionStatus = .disconnected
    }
  }

  public func stopListening() {
    udpService.stopAll()
    wsjtxConnectionStatus = .disconnected
    heartbeatTimer?.invalidate()
    textFlashTask?.cancel()
    textFlashTask = nil
  }

  public func testWavelogConnection() async -> Bool {
    wavelogConnectionStatus = .connecting
    do {
      let success = try await apiClient.testConnection(
        apiKey: apiKey,
        stationProfileID: config.stationProfileID,
        baseURL: config.wavelogURL
      )
      wavelogConnectionStatus = success ? .connected : .error
      return success
    } catch {
      wavelogConnectionStatus = .error
      lastError = error.localizedDescription
      showingError = true
      return false
    }
  }

  public func fetchStationProfiles() async {
    do {
      stationProfiles = try await apiClient.fetchStationProfiles(
        apiKey: apiKey,
        baseURL: config.wavelogURL
      )
      wavelogConnectionStatus = .connected
    } catch {
      wavelogConnectionStatus = .error
      lastError = error.localizedDescription
      showingError = true
    }
  }

  public func retryFailedQSO(_ qso: QSO) async {
    guard recentQSOs.contains(where: { $0.id == qso.id }) else { return }

    do {
      let adifString = ADIFGenerator.generate([qso])
      try await apiClient.sendQSO(
        adifString: adifString,
        apiKey: apiKey,
        stationProfileID: config.stationProfileID,
        baseURL: config.wavelogURL
      )

      guard let index = recentQSOs.firstIndex(where: { $0.id == qso.id }) else { return }
      recentQSOs[index].loggedSuccessfully = true
      recentQSOs[index].logError = nil
      recentQSOs[index].logErrorRaw = nil
      recentQSOs[index].loggedAt = Date()
      totalQSOsLogged += 1
      totalQSOsFailed = max(0, totalQSOsFailed - 1)

      if config.showNotifications {
        NotificationService.sendQSOLoggedNotification(
          call: qso.call, band: qso.band, mode: qso.mode)
      }
    } catch {
      guard let index = recentQSOs.firstIndex(where: { $0.id == qso.id }) else { return }
      recentQSOs[index].logError = error.localizedDescription
      if let apiError = error as? WavelogAPIClient.APIError {
        recentQSOs[index].logErrorRaw = apiError.rawBody
      }
      recentQSOs[index].loggedAt = Date()
    }
    saveQSOLog()
  }

  public func clearQSOLog() {
    recentQSOs = []
    totalQSOsLogged = 0
    totalQSOsFailed = 0
    QSOLogStore.clear()
  }

  private func loadQSOLog() {
    let log = QSOLogStore.load()
    recentQSOs = log.recentQSOs
    totalQSOsLogged = log.totalQSOsLogged
    totalQSOsFailed = log.totalQSOsFailed
  }

  private func saveQSOLog() {
    QSOLogStore.save(
      PersistedQSOLog(
        recentQSOs: recentQSOs,
        totalQSOsLogged: totalQSOsLogged,
        totalQSOsFailed: totalQSOsFailed
      )
    )
  }

  public func loadConfig() {
    isLoadingConfig = true
    defer { isLoadingConfig = false }

    if let data = UserDefaults.standard.data(forKey: "wavelog_config"),
      let decoded = try? JSONDecoder().decode(WavelogConfig.self, from: data)
    {
      config = decoded
    }

    apiClient = WavelogAPIClient(
      allowSelfSignedCerts: config.allowSelfSignedCerts,
      timeout: TimeInterval(config.httpTimeout) / 1000.0
    )
  }

  public func saveConfig(previous: WavelogConfig? = nil) {
    var sanitizedConfig = config
    sanitizedConfig.enforceVisibleEntryPoint()
    if sanitizedConfig != config {
      isLoadingConfig = true
      defer { isLoadingConfig = false }
      config = sanitizedConfig
    }

    if let encoded = try? JSONEncoder().encode(config) {
      UserDefaults.standard.set(encoded, forKey: "wavelog_config")
    }

    let needsNewAPIClient =
      previous.map {
        $0.allowSelfSignedCerts != config.allowSelfSignedCerts
          || $0.httpTimeout != config.httpTimeout
      } ?? true

    if needsNewAPIClient {
      apiClient = WavelogAPIClient(
        allowSelfSignedCerts: config.allowSelfSignedCerts,
        timeout: TimeInterval(config.httpTimeout) / 1000.0
      )
    }

    let needsListenerRestart =
      previous.map {
        $0.udpProtocol != config.udpProtocol
          || $0.textUDPPort != config.textUDPPort
          || $0.binaryUDPPort != config.binaryUDPPort
          || $0.listenAddress != config.listenAddress
      } ?? true

    if needsListenerRestart {
      startListening()
    }

    let needsDockUpdate = previous.map { $0.showInDock != config.showInDock } ?? true

    if needsDockUpdate {
      applyDockVisibility()
    }
  }

}
