# Repository Guidelines

## Project Structure & Module Organization
- `ScoreMatching/`: main iOS SwiftUI app (features under `Features/`, sync in `Multipeer/`, exports in `PDF/`).
- `WTS-watch Watch App/`: watchOS companion app UI and interactions.
- `Widget/`: WidgetKit extension.
- `WhatScoreKit/`: local Swift package shared by iOS, watchOS, and widget (`Sources/WhatScoreKit/`, tests in `Tests/WhatScoreKitTests/`).
- `ScoreMatching.xcodeproj/`: project, shared schemes, and build settings.
- `fastlane/` and `screenshots/`: App Store screenshot automation and output.

## Build, Test, and Development Commands
- `open ScoreMatching.xcodeproj`: open project in Xcode.
- `xcodebuild -project ScoreMatching.xcodeproj -scheme "What the score" -destination 'platform=iOS Simulator,name=iPhone 16' build`: CI-friendly iOS build.
- `xcodebuild -project ScoreMatching.xcodeproj -scheme "WTS-watch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' test`: run watch unit/UI tests.
- `cd WhatScoreKit && swift test`: run shared package tests.
- `bundle exec fastlane ios screenshots`: generate localized App Store screenshots.

## Coding Style & Naming Conventions
- Language: Swift 6+ with SwiftUI and SwiftData.
- Use 4-space indentation and Xcode default formatting; keep files focused by feature.
- Types/protocols: `UpperCamelCase`; functions/properties: `lowerCamelCase`; enum cases: `lowerCamelCase`.
- Prefer feature-oriented names (`IntervalsList`, `WatchSyncCoordinator`) and keep shared models in `WhatScoreKit`.

## Testing Guidelines
- Frameworks: Swift Testing (`import Testing`, `@Test`) and XCTest (UI/screenshot tests).
- Put package tests in `WhatScoreKit/Tests/WhatScoreKitTests/`; app/watch tests in target-specific test bundles.
- Test names should describe behavior (example: `@Test func syncTransfersIntervals()`), not implementation.
- Run affected target tests before opening a PR; include simulator/device used in notes.

## Commit & Pull Request Guidelines
- Current history favors short messages (`Working`, `Improvements`, `Refactor`). For new work, use clear imperative summaries with scope, e.g. `watch: fix interval sync ordering`.
- Keep commits focused (one concern per commit).
- PRs should include: purpose, impacted targets (`iOS`, `watchOS`, `Widget`, `WhatScoreKit`), test evidence, and screenshots for UI changes.
- Link related issues/tasks and call out config or entitlement changes explicitly.

## Security & Configuration Tips
- Do not commit secrets; treat `GoogleService-Info.plist` and `Config.xcconfig` edits as sensitive and review carefully.
- Validate App Group/entitlement changes across all targets before merge.
