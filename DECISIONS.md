# WaveLogMate Design Decisions

Why the code looks the way it does. Append a row for each new decision. Never rewrite
history. A superseded entry stays, and the newer entry says what replaced it.

| #   | Decision                         | Rationale                                                                          | Date       |
| --- | -------------------------------- | ---------------------------------------------------------------------------------- | ---------- |
| 1   | macOS 14+ minimum                | `@Observable` macro, modern SwiftUI. Covers ~85%+ active Macs.                     | 2026-03-06 |
| 2   | Binary UDP disabled by default   | Port 2237 conflicts with JT-Bridge/GridTracker. Opt-in with documentation.           | 2026-03-06 |
| 3   | MIT license                      | Matches WaveLogGate (official companion). Permissive for ham radio community.      | 2026-03-06 |
| 4   | Keychain for API key             | Security best practice. WaveLogGate and WaveLogStoat use plaintext. WaveLogMate improves on this. | 2026-03-06 |
| 5   | No CAT control                   | Scope limitation. WaveLogGate already does CAT. We focus on QSO logging.           | 2026-03-06 |
| 6   | Sparkle for updates              | Industry standard for non-App Store macOS. EdDSA signing, GitHub Releases hosting. | 2026-03-06 |
| 7   | Custom Homebrew tap first        | Instant publishing. Submit to homebrew-cask when app has traction.                 | 2026-03-06 |
| 8   | Station profile dropdown via API | Better UX than manual ID entry. `/api/station_info` provides the data.             | 2026-03-06 |
| 9   | App name: WaveLogMoat            | Continues Gate/Goat/Stoat naming. Moat = bridge/guardian. Superseded by decision 28. | 2026-03-06 |
| 10  | CI signing via manual codesign   | `xcodebuild archive` unsigned, then manual `codesign` with Developer ID. Avoids provisioning profile requirement. Sparkle nested bundles signed inside-out. | 2026-03-06 |
| 11  | station_info key in URL path     | Wavelog expects API key at `/api/station_info/{key}`, not in JSON body.            | 2026-03-06 |
| 12  | In-memory API key cache          | Keychain prompts on every read from unsigned builds. Load once, write-through.     | 2026-03-06 |
| 13  | Grouped form settings UI         | `.formStyle(.grouped)` for native macOS card layout. Avoids clipping in 2-col.    | 2026-03-06 |
| 14  | Auto-prefix https:// on URLs     | Users often omit protocol. Prefix https://, hint about http:// on TLS errors.     | 2026-03-06 |
| 15  | Notification denied UX           | Sync toggle to OS state, show warning + "Open Notification Settings" button.       | 2026-03-06 |
| 16  | Dock visibility via policy       | `NSApp.setActivationPolicy(.regular/.accessory)` applied on init and config save.  | 2026-03-06 |
| 17  | Exclusive protocol choice        | Text and binary UDP are mutually exclusive (segmented picker). Eliminates dedup.   | 2026-03-06 |
| 18  | Bundle ID `de.dl5mn.WaveLogMate` | Changed from `com.dl5mn` to `de.dl5mn` to match German country domain convention. | 2026-03-07 |
| 19  | MenuBarExtra local @State sync   | Binding `isInserted` directly to @Observable + UserDefaults causes cfprefsd deadlock in release builds. Fix: local @State with one-directional onChange sync. | 2026-03-08 |
| 20  | CFBundleVersion auto-increment   | Build number increments on each `make release`. Sparkle uses build number for version comparison. This prevents a false "up to date" when version strings are not monotonically increasing. | 2026-03-08 |
| 21  | No keychain-access-groups        | This entitlement requires a provisioning profile for Developer ID distribution. Removed it. Keychain API works fine without it for non-sandboxed apps. | 2026-03-07 |
| 22  | `swift format` over SwiftLint    | Built into the Swift toolchain, so no `brew install` is needed locally or in CI. `.swift-format` config only sets `NeverForceUnwrap: true` (all other rules use defaults). Two lines use `// swift-format-ignore` for trailing-underscore names that avoid Swift keyword conflicts (`operator_`, `protocol_`). | 2026-03-11 |
| 23  | CI uses `make` targets           | Both workflows use `make format`, `make lint`, `make test` instead of raw commands. Single source of truth in the Makefile prevents command drift between local dev and CI. | 2026-03-11 |
| 24  | Swift Testing over XCTest        | All 62 tests migrated to Swift Testing (`@Test`, `#expect`, `@Suite struct`). Less boilerplate, better failure diagnostics, tests run in parallel by default. | 2026-03-11 |
| 25  | Swift Regex over NSRegularExpression | ADIFParser uses `#/(?i)<eor>/#` regex literal with `split(separator:)` instead of `NSRegularExpression` + `stringByReplacingMatches`. Type-safe, no `try!`, simpler code. | 2026-03-11 |
| 26  | Swift 6.2 strict concurrency | Migrated from Swift 5.9 to 6.2, enabling strict concurrency checking. `AppState` and `UDPService` annotated `@MainActor`. UDP listener callbacks wrapped in `Task { @MainActor in }` to hop from background DispatchQueues. All model types were already `Sendable`. Listener classes remain `@unchecked Sendable` (serial DispatchQueue isolation). Zero errors, zero warnings. | 2026-03-11 |
| 27  | Self-signed TLS is opt-in        | Preserve compatibility with self-hosted Wavelog instances, but default `allowSelfSignedCerts` to `false` so certificate trust bypass is an explicit user action instead of the default. | 2026-03-12 |
| 28  | Rename WaveLogMoat → WaveLogMate | "Mate" means your companion at the radio. Better name, same Gate/Goat/Stoat convention. Full rename: bundle ID, Keychain service, module names, Homebrew tap, CI workflows, docs. New bundle ID `de.dl5mn.WaveLogMate`. No migration needed (no existing users). | 2026-03-13 |
| 29  | NSAllowsLocalNetworking over NSAllowsArbitraryLoads | Narrows ATS exception to local network only (RFC 1918, loopback, .local). Remote servers require HTTPS. Self-signed certs handled by `SelfSignedCertificateDelegate`. | 2026-03-30 |
| 30  | QDataStreamReader as struct | Changed from `class @unchecked Sendable` to `struct Sendable` with `mutating` methods. Value semantics eliminate shared mutable state. `BinaryUDPListener` creates a local reader per message instead of reusing an instance variable. | 2026-03-30 |
| 31  | QSO log persistence via JSON file | Recent QSOs (capped at 10) and counters stored as JSON at `~/Library/Application Support/WaveLogMate/qso-log.json`. Chose JSON file over UserDefaults (better for structured data) and SwiftData (overkill for 10 records). Atomic writes, error logging. | 2026-03-30 |
| 32  | HTTP timeout configurable with 500ms floor | Exposed in Wavelog settings tab. Minimum enforced both in UI (`onChange`) and config decoder (`max(500, ...)`). Default remains 5000ms. | 2026-03-30 |
| 33  | ADIF 3.1.7 | Bumped ADIF version string. New modes: OFDM (RIBBIT_PIX, RIBBIT_SMS), MFSK/FT2, DYNAMIC/FREEDATA. No format changes. Modes pass through as free-form strings. | 2026-03-31 |
| 34  | Wavelog 2.4 compatibility | No breaking API changes. New `logbook_get_worked_grids` endpoint returns Maidenhead grids worked per logbook/band. | 2026-03-31 |
| 35  | Wavelog API v1 and v2 side by side | v2 needs a `wl2_` token and Wavelog 3.1.0. Upstream keeps v1 fully supported. `WavelogAPIClient` reads the token prefix instead of asking the user, so existing keys keep working and nobody has to migrate. QSOs use `POST /api/v2/qso` with `import_type=adif`. A skipped row means a duplicate and counts as logged, the same outcome v1 reports as `created`. v2 has no version endpoint. `GET /api/v2/token` took over the health check, and the menu bar shows the token owner instead of the release. Scopes needed: `qso:write`, `station:read`. | 2026-08-13 |
