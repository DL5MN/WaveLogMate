import SwiftUI

public struct MenuBarView: View {
  @Bindable var appState: AppState
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openSettings) private var openSettings
  let checkForUpdates: () -> Void

  public init(appState: AppState, checkForUpdates: @escaping () -> Void) {
    self.appState = appState
    self.checkForUpdates = checkForUpdates
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        ConnectionStatusView(
          label: "WSJT-X",
          status: appState.wsjtxConnectionStatus,
          detail: appState.wsjtxVersion.isEmpty ? nil : "v\(appState.wsjtxVersion)"
        )

        ConnectionStatusView(
          label: "Wavelog",
          status: appState.wavelogConnectionStatus,
          detail: appState.wavelogDetail
        )
      }
      .padding()

      Divider()

      if appState.config.udpProtocol == .binary,
        appState.wsjtxConnectionStatus == .connected
      {
        HStack {
          Text("\(appState.wsjtxStatus.formattedFrequency) MHz")
            .monospacedDigit()
          Text(appState.wsjtxStatus.mode)
          if !appState.wsjtxStatus.dxCall.isEmpty {
            Text("(DX: \(appState.wsjtxStatus.dxCall) \(appState.wsjtxStatus.dxGrid))")
              .foregroundStyle(.secondary)
          }
          Spacer()
        }
        .padding()

        Divider()
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Recent QSOs")
          .font(.headline)

        QSOLogView(qsos: appState.recentQSOs, appState: appState)
      }
      .padding()

      Divider()

      HStack {
        Text(
          "Total: \(appState.totalQSOsLogged) logged, \(appState.totalQSOsFailed) failed"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        Spacer()
      }
      .padding()

      Divider()

      VStack(alignment: .leading, spacing: 0) {
        HoverButton {
          dismiss()
          openSettings()
          NSApplication.shared.activate()
        } label: {
          MenuRow(title: "Settings", systemImage: "gear", shortcut: "⌘,")
        }

        HoverButton {
          dismiss()
          checkForUpdates()
        } label: {
          MenuRow(
            title: "Check for Updates", systemImage: "arrow.triangle.2.circlepath")
        }

        HoverButton {
          dismiss()
          if let url = URL(string: "https://github.com/dl5mn/WaveLogMate/issues") {
            NSWorkspace.shared.open(url)
          }
        } label: {
          MenuRow(title: "Report Issue", systemImage: "exclamationmark.bubble")
        }

        HoverButton {
          NSApplication.shared.terminate(nil)
        } label: {
          MenuRow(title: "Quit WaveLogMate", systemImage: "power", shortcut: "⌘Q")
        }
      }
      .padding(.vertical, 4)
    }
    .frame(width: 350)
  }
}

private struct HoverButton<Label: View>: View {
  let action: () -> Void
  @ViewBuilder let label: () -> Label
  @State private var isHovered = false

  var body: some View {
    label()
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
      .contentShape(Rectangle())
      .onTapGesture(perform: action)
      .onHover { isHovered = $0 }
  }
}

private struct MenuRow: View {
  let title: String
  let systemImage: String
  var shortcut: String?

  var body: some View {
    HStack {
      Label(title, systemImage: systemImage).foregroundStyle(.primary)
      Spacer()
      if let shortcut {
        Text(shortcut)
          .foregroundStyle(.secondary)
          .font(.callout)
      }
    }
  }
}
