# Welcome to What the score!

This is a tiny app for iOS - which runs on iPadOS and MacOS too - that lets you keep track of games scores.

The game is persisted in local storage with SwiftData.

## TestFlight beta

From this directory, run `bundle exec fastlane ios beta` with an App Store Connect account that can upload and manage builds. The lane uses the current app version, sets the next build number above both the local project and TestFlight, archives the `What the score` Release scheme, and waits for TestFlight processing after upload. The build number change remains in `ScoreMatching.xcodeproj` for you to commit.

The lane uses the project's automatic signing with developer team `382G4857JD`. Confirm the processed build is assigned to the intended internal TestFlight group in App Store Connect before telling testers it is available.
