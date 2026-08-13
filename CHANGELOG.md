# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-08-13

### Added

- Support Wavelog API v2

### Documentation

- Replace PLAN.md with DECISIONS.md
- Remove ROADMAP.md

### Other

- Bump github.com/sparkle-project/sparkle from 2.9.4 to 2.9.5 (#10)

## [1.1.3] - 2026-07-08

### Other

- Bump github.com/sparkle-project/sparkle from 2.9.3 to 2.9.4 (#9)
- Bump actions/cache from 5 to 6 (#8)
- Bump actions/checkout from 6 to 7 (#7)
- Bump github.com/sparkle-project/sparkle from 2.9.2 to 2.9.3 (#6)

## [1.1.2] - 2026-05-19

### CI/CD

- Track action-gh-release major version tag

### Documentation

- Recommend Wavelog 2.4+ in README requirements
- Update PLAN.md and ROADMAP.md for ADIF 3.1.7 and Wavelog 2.4
- Update PLAN.md for v1.1.0 changes

### Other

- Bump github.com/sparkle-project/sparkle from 2.9.1 to 2.9.2 (#5)
- Bump softprops/action-gh-release from 2 to 3 (#4)
- Bump ADIF version to 3.1.7

## [1.1.1] - 2026-03-30

### Changed

- Fix linter formatting in GeneralSettingsTab

### Other

- Bump github.com/sparkle-project/sparkle from 2.9.0 to 2.9.1 (#3)

## [1.1.0] - 2026-03-30

### Added

- Expose HTTP timeout setting in Wavelog settings
- Persist recent QSOs and counters across app restarts

### Changed

- Remove unused ConnectionStatus.color property

### Fixed

- Kill running instance before opening new build
- Use dynamic bundle version in User-Agent header
- Propagate encoding errors from buildQSOPayload and buildVersionPayload
- Prevent re-entrant saveConfig via isLoadingConfig guard
- Make QDataStreamReader a Sendable struct with local instances per message
- Replace NSAllowsArbitraryLoads with NSAllowsLocalNetworking

### Other

- Bump softprops/action-gh-release from 2.5.0 to 2.6.1 (#2)

## [1.0.1] - 2026-03-16

### CI/CD

- Bust stale SPM cache after project rename

### Fixed

- Rename logQSO to sendQSO to avoid CodeQL false positives

### Other

- Regenerate Xcode project after rename

## [1.0.0] - 2026-03-13

### Added

- Rename WaveLogMoat to WaveLogMate

### CI/CD

- Bump softprops/action-gh-release to v2.5.0 (Node 24)

## [0.6.0] - 2026-03-12

### Documentation

- Clarify local app smoke test in PR template

### Fixed

- Disable self-signed TLS by default
- Tighten XML detection for text UDP payloads
- Preserve a visible app entry point
- Regenerate Xcode project before app targets
- Honor UDP bind address and listener state
- Cancel pending text status updates on stop
- Honor persisted menu bar visibility on launch

## [0.5.0] - 2026-03-11

### Added

- Migrate to Swift 6.2 strict concurrency

### CI/CD

- Refine CodeQL workflow with cache v5 and checkout labels
- Add CodeQL advanced setup with Swift and Actions scanning
- Add SPM cache to CodeQL workflow
- Add custom CodeQL workflow for Swift 6.2 on macos-26
- Switch runners to macos-26 for Swift 6.2 support

### Changed

- Replace DispatchQueue.main.async with async/await in notification check
- Replace NSRegularExpression with Swift Regex literal in ADIFParser
- Apply swift format to entire codebase

### Documentation

- Add Swift 6.2 migration to design decisions log
- Update PLAN.md with current tooling and design decisions

### Fixed

- Replace deprecated activate(ignoringOtherApps:) with activate()

### Other

- Enable AlwaysUseLowerCamelCase rule with per-line ignores for keyword conflicts
- Use SPM build instead of Xcode in CI for faster builds
- Use make targets in CI workflows for format, lint, and test
- Remove obsolete swiftlint disable comment
- Replace SwiftLint with swift format, add make check target
- Switch formatter from swiftformat to swift format

### Testing

- Migrate all 62 tests from XCTest to Swift Testing

## [0.4.0] - 2026-03-10

### CI/CD

- Strip redundant version heading from GitHub release notes
- Restrict build workflow permissions to contents read
- Add Dependabot for Swift packages and GitHub Actions

### Documentation

- Add roadmap for goal-oriented WSJT-X companion features
- Update PLAN.md to reflect current project state
- Add security policy with private vulnerability reporting
- Add pull request template

### Other

- Track Package.resolved for dependency graph and reproducible builds
- Bump actions/checkout from 4 to 6 (#1)

## [0.3.3] - 2026-03-09

### Fixed

- Use CFBundleVersion build number for sparkle:version in appcast

## [0.3.2] - 2026-03-09

### Added

- Auto-increment CFBundleVersion build number on each release

## [0.3.1] - 2026-03-09

### Fixed

- Prevent main thread deadlock when toggling menu bar visibility

## [0.3.0] - 2026-03-09

### Added

- Add Report Issue menu item and crash log field to bug template

### Fixed

- Skip bump commits from changelog and filter non-conventional commits
- Move changelog generation from CI to make release
- Respect 'Show in menu bar' toggle via MenuBarExtra isInserted

## [0.2.0] - 2026-03-08

### Added

- Add code signing and notarization to release workflow

### Documentation

- Replace JTAlert with JT-Bridge (macOS equivalent)
- Clarify that WaveLogMoat receives UDP data sent by WSJT-X

### Fixed

- Remove keychain-access-groups entitlement that requires provisioning profile
- Skip build workflow on version tags to avoid duplicate CI runs

## [0.1.0] - 2026-03-07

### Added

- Show listening status instead of disconnected in text mode
- Add QSO error detail popover with raw response and HTML entity decoding
- Add hover highlighting to menu bar action buttons
- Polish settings UI with grouped forms, contextual hints, and improved error display
- Show Wavelog version in menu bar status
- Check connection status on startup and poll Wavelog periodically
- Add app icon
- Add Xcode project with app target and Sparkle integration
- Add settings window with all tabs
- Implement menu bar UI
- Add app entry point and state management
- Add notification and launch-at-login services
- Implement Wavelog API client
- Add UDP listeners for text and binary protocols
- Implement QDataStream binary protocol reader
- Add band map utility and logging
- Add XML contact parser and QSO normalizer
- Implement ADIF parser and generator
- Add Wavelog configuration and station profile models
- Add WSJT-X protocol models
- Add QSO data model and ADIF field definitions

### CI/CD

- Disable code signing on GitHub Actions runners
- Sign DMG with Sparkle and deploy appcast to GitHub Pages
- Integrate git-cliff into release pipeline and Makefile
- Add linting to release pipeline and auto-update homebrew tap
- Add swiftlint step to build pipeline
- Upgrade runners to macos-15 with Xcode 16.4
- Add build and release GitHub Actions workflows

### Changed

- Remove duplicated mode normalization and minor cleanups
- Avoid unnecessary listener restarts and API client recreation on config change
- Make text and binary UDP protocols mutually exclusive
- Remove single-QSO generate overload from ADIFGenerator
- Fix all swiftlint violations

### Documentation

- Remove index.php suffix from Wavelog URL examples
- Update README and PLAN to reflect exclusive protocol choice and live testing
- Format README tables and remove binary size comparison row
- Update PLAN.md with recent design decisions and progress
- Trim PLAN.md to open tasks and remove broken screenshot links
- Add git-cliff config and generate changelog
- Add motivation and feature comparison with related projects
- Add README, contributing guide, and changelog
- Add project plan and architecture

### Fixed

- Use step output to check secret availability in release workflow
- Remove expression wrapper from secrets checks in release workflow
- Harden release workflow for first-run and missing secrets
- Prevent sticky focus highlight on menu bar action buttons
- Make log messages visible by marking interpolated values as public
- Deduplicate QSOs when both UDP listeners are active
- Bring settings window to front when opened from menu bar
- Remove keyboard shortcuts from menu bar buttons to prevent auto-focus
- Remove force unwrap to satisfy SwiftLint
- Turn off notification toggle when OS has denied permission
- Re-check notification authorization when app regains focus
- Show guidance when macOS notifications are denied
- Apply dock visibility setting via NSApp activation policy
- Auto-prefix https:// for Wavelog URLs without a protocol scheme
- Deduplicate ADIF header generation, fix PROGRAMID length, update to ADIF 3.1.6
- Disable menu bar frequency display by default
- Add keychain-access-groups entitlement
- Cache API key in memory to avoid repeated Keychain prompts
- Dismiss menu bar panel when opening settings or checking updates
- Correct WSJT-X settings tab layout clipping
- Pass API key in URL path for station_info endpoint
- Generate properly sized app icon PNGs and exclude asset catalog from SPM

### Other

- Add make release target for one-command version bumping and tagging
- Normalize ellipsis usage in status text and templates
- Add 'make open' to launch latest debug build
- Add GitHub issue form templates for bugs and feature requests
- Add Sparkle EdDSA public key for update verification
- Gitignore xcuserdata inside project.xcworkspace
- Enable automatic code signing in Xcode project
- Initialize project structure

### Testing

- Add WavelogConfig migration and edge case coverage
- Add networking tests
- Add unit tests for parsers and models


