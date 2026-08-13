# WaveLogMate

[![Build](https://github.com/dl5mn/WaveLogMate/actions/workflows/build.yml/badge.svg)](https://github.com/dl5mn/WaveLogMate/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.2-orange)](https://swift.org)

> Native macOS menu bar application for automatic QSO logging from WSJT-X to [Wavelog](https://www.wavelog.org).

There are already several tools that bridge WSJT-X and Wavelog — [WaveLogGate](https://github.com/wavelog/WaveLogGate), [WaveLogStoat](https://github.com/int2001/WaveLogStoat), and [WaveLogGoat](https://github.com/johnsonm/WaveLogGoat). They all work, but none of them are native macOS apps. I wanted something that feels at home on my Mac: a lightweight menu bar app built with SwiftUI that uses the macOS Keychain for secrets, sends native notifications, supports Sparkle auto-updates, and doesn't bundle an entire Electron runtime or require a terminal to run. That's WaveLogMate.

WaveLogMate receives QSO data from WSJT-X and automatically forwards it to your Wavelog instance in real-time. WSJT-X sends UDP packets to WaveLogMate — you just need to point WSJT-X at the right address and port. You choose between the text-based ADIF/XML protocol (Secondary UDP Server) or the binary QDataStream protocol, which adds real-time frequency and status display.

## Features

- **Automatic QSO Logging** - QSOs from WSJT-X are logged to Wavelog in real-time
- **Wavelog API v1 and v2** - Picks the matching API from your key, no setting needed
- **Flexible Protocol Choice** - Text ADIF/XML (port 2333) or binary QDataStream (port 2237)
- **Menu Bar App** - Lives in your menu bar with live status display
- **Real-time Status** - Shows current frequency, mode, and DX call from WSJT-X
- **Connection Monitoring** - Heartbeat-based WSJT-X connection tracking
- **macOS Notifications** - Get notified when QSOs are logged (or fail)
- **Secure** - API key stored in macOS Keychain
- **Self-Signed Cert Support** - Works with self-hosted Wavelog instances
- **Auto-Updates** - Built-in update checking via Sparkle
- **Launch at Login** - Optional automatic startup
- **Native macOS** - Built with SwiftUI, feels right at home on macOS

## Requirements

- macOS 14 (Sonoma) or later
- [WSJT-X](https://wsjt-x.sourceforge.io/) or [WSJT-X Improved](https://wsjt-x-improved.sourceforge.io/)
- A [Wavelog](https://www.wavelog.org) instance with API access. Version 2.4 or later for
  API v1, version 3.1.0 or later for API v2.

## Installation

### Download

Download the latest release from the [Releases page](https://github.com/dl5mn/WaveLogMate/releases).

### Homebrew

```bash
brew tap dl5mn/wavelogmate
brew install --cask wavelogmate
```

## Setup

### 1. Configure WSJT-X

WSJT-X sends UDP data to a configured address and port. Despite the label "UDP Server" in WSJT-X settings, WSJT-X is the sender — WaveLogMate receives the data on the address and port you configure here.

**Text protocol (default):** In WSJT-X, go to **Settings -> Reporting** and configure the **Secondary UDP Server** to point at WaveLogMate:

- **Address**: `127.0.0.1`
- **Port**: `2333`

> **Important**: Use the _Secondary_ UDP Server, NOT the primary one. This keeps the primary port free for JT-Bridge, GridTracker, or other tools.

**Binary protocol:** WaveLogMate receives on the primary UDP port (2237) by default — no special WSJT-X configuration needed. Note that only one application can receive on this port at a time.

### 2. Configure WaveLogMate

1. Open WaveLogMate from the menu bar (antenna icon)
2. Click **Settings**
3. **Wavelog tab**:
   - Enter your Wavelog URL (e.g., `https://log.example.com`)
   - Enter your API key (Wavelog -> User Menu -> API Keys). WaveLogMate reads the key
     prefix and picks the matching API: a `wl2_` token uses API v2, any other key uses
     API v1. A v2 token needs the scopes `qso:write` and `station:read`. A v1 key must
     be Read+Write.
   - Select your Station Profile from the dropdown
   - Click **Test Connection** to verify
4. **WSJT-X tab**:
   - Choose between **Text** (default) and **Binary** protocol
   - Text is simple and works alongside other tools
   - Binary adds real-time frequency, mode, and DX call display but uses the primary UDP port exclusively

### 3. Start Logging

Once configured, WaveLogMate automatically receives QSOs from WSJT-X. When you log a QSO in WSJT-X, it appears in the menu bar dropdown and is forwarded to Wavelog.

## Configuration Options

| Setting                 | Default   | Description                                                |
| ----------------------- | --------- | ---------------------------------------------------------- |
| Wavelog URL             | -         | Your Wavelog instance URL                                  |
| API Key                 | -         | `wl2_` token (API v2) or Read+Write key (API v1)           |
| Station Profile         | -         | Selected from your Wavelog station locations               |
| Protocol                | Text      | Text (ADIF/XML) or Binary (QDataStream) — one at a time   |
| Text UDP Port           | 2333      | WSJT-X Secondary UDP Server port                           |
| Binary UDP Port         | 2237      | WSJT-X Primary UDP Server port                             |
| Bind Address            | 127.0.0.1 | Address to receive WSJT-X data on                          |
| Allow Self-Signed Certs | Off       | For self-hosted Wavelog with self-signed TLS               |
| Show in Menu Bar        | On        | Display icon in menu bar                                   |
| Show in Dock            | Off       | Display icon in dock                                       |
| Launch at Login         | Off       | Start automatically at login                               |
| Show Notifications      | On        | macOS notifications for QSO events                         |

## Binary Protocol

Switching to the binary protocol (port 2237) provides everything the text protocol does, plus:

- Real-time frequency and mode display in the menu bar
- WSJT-X connection heartbeat monitoring
- DX call and grid display

> **Note**: Only one application can receive on the primary UDP port at a time. Do not use the binary protocol if JT-Bridge, GridTracker, or other tools need this port.

## Building from Source

### Prerequisites

- macOS 14+
- Xcode 26.2+ or Swift 6.2+

### Build

```bash
git clone https://github.com/dl5mn/WaveLogMate.git
cd WaveLogMate
make build
```

### Test

```bash
make test
```

### Clean

```bash
make clean
```

### Releasing

To create a new release, run:

```bash
make release VERSION=0.2.0
```

This bumps the version in `Info.plist` and `project.yml`, commits, tags `v0.2.0`, and pushes. The GitHub Actions release workflow then builds the DMG, creates the GitHub Release with auto-generated release notes, updates the changelog, deploys the Sparkle appcast, and bumps the Homebrew cask.

## Architecture

WaveLogMate is built with:

- **SwiftUI** - Native macOS UI with MenuBarExtra
- **Network.framework** - UDP receiver for WSJT-X data
- **URLSession** - Wavelog REST API client
- **Sparkle** - Auto-updates
- **Keychain** - Secure API key storage
- **UserNotifications** - macOS notifications

See [DECISIONS.md](DECISIONS.md) for the design decisions behind the code.

## How It Compares

|                       | WaveLogMate            | [WaveLogGate](https://github.com/wavelog/WaveLogGate) | [WaveLogStoat](https://github.com/int2001/WaveLogStoat) | [WaveLogGoat](https://github.com/johnsonm/WaveLogGoat) |
| --------------------- | ---------------------- | ----------------------------------------------------- | ------------------------------------------------------- | ------------------------------------------------------ |
| **Platform**          | macOS (native)         | Windows, macOS, Linux (Electron)                      | Windows, macOS, Linux (Go CLI)                          | Windows, macOS, Linux (Go)                             |
| **QSO Logging**       | Yes                    | Yes                                                   | Yes                                                     | No                                                     |
| **CAT Control**       | No                     | Yes (FLRig/Hamlib)                                    | No                                                      | Yes                                                    |
| **UI**                | Menu bar app (SwiftUI) | Desktop window (Electron)                             | Terminal                                                | Terminal                                               |
| **Auto-updates**      | Sparkle                | Electron auto-updater                                 | Manual                                                  | Manual                                                 |
| **Secrets storage**   | macOS Keychain         | Config file                                           | Config file                                             | Config file                                            |
| **Notifications**     | Native macOS           | Electron notifications                                | None                                                    | None                                                   |
| **Self-signed certs** | Yes                    | Yes                                                   | Yes                                                     | Yes                                                    |

WaveLogMate focuses on doing one thing well: getting QSOs from WSJT-X into Wavelog with zero friction. If you need CAT control, use WaveLogGate or WaveLogGoat. If you want a native Mac experience for QSO logging, this is it.

See also: [Wavelog](https://github.com/wavelog/wavelog) — the logging platform itself.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

Made with love for the amateur radio community by DL5MN.
73!
