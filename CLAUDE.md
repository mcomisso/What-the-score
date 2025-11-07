# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"What the Score" is an iOS and watchOS score-tracking application built with SwiftUI and SwiftData (iOS 17+, watchOS 11+). The app allows users to track game scores with gesture-based interactions, supports peer-to-peer score sharing via MultipeerConnectivity, includes a WidgetKit extension for home screen widgets, and features a native Apple Watch companion app with real-time sync.

**Bundle ID:** `com.mcomisso.ScoreMatching`
**Deployment Target:** iOS 17.0+, watchOS 11.0+

## Build & Development Commands

### Building & Running
- Open `ScoreMatching.xcodeproj` in Xcode
- Build and run using Xcode (Cmd+R)
- The project uses standard Xcode build system (no custom build scripts)
- **Schemes available:**
  - `ScoreMatching` - Main iOS app
  - `WTS-watch Watch App` - Apple Watch companion app
  - `WidgetExtension` - Home screen widget
  - `ScoreMatching Screenshots` - Screenshot generation for App Store

### Screenshots
```bash
bundle exec fastlane screenshots
```
Generates localized App Store screenshots using the ScoreMatching scheme.

### Dependencies
All dependencies are managed via Swift Package Manager (integrated in Xcode):
- **WhatScoreKit** (Local Package) - Shared models, utilities, and data layer for iOS, Widget, and watchOS
- **TelemetryDeck/SwiftClient** - Privacy-focused analytics
- **Firebase iOS SDK** - Analytics and Crashlytics
- **EmergeTools/Pow** - SwiftUI animation effects

No need to run package installation commands; Xcode handles this automatically.

## Architecture

### Data Layer (SwiftData Models & WhatScoreKit)

**WhatScoreKit Local Package:**
The project uses a local Swift Package (`WhatScoreKit/`) to share code between iOS, Widget, and watchOS targets. This package contains:
- SwiftData models (`WhatScoreKit/Sources/WhatScoreKit/SwiftDataModel.swift`)
- Color utilities (`Color+Decodable.swift`, `Color+random.swift`)
- Serialization utilities (`CodableTeamData.swift`)

**Core Models:**
All models are in `WhatScoreKit/Sources/WhatScoreKit/SwiftDataModel.swift`:
- **`Team`** - Represents a team with scores array, name, and color. Includes undo functionality.
- **`Score`** - Individual score entry with timestamp and value (supports negative points)
- **`Interval`** - Snapshots team scores at specific points in time (quarters, halves, periods)
  - Contains `IntervalTeamSnapshot` array storing team name, color, and total score
  - Can calculate score gained per interval using `scoreGained(previousInterval:)`
  - Created using `Interval.create(name:from:)` helper
- **`Game`** - Groups teams and intervals together (optional, for future use)

**Key persistence patterns:**
- SwiftData with `@Model` macro for automatic persistence
- `@Query` property wrapper for reactive data fetching
- App Groups (`group.mcomisso.whatTheScore`) for sharing data with Widget and watchOS extensions
- In-memory containers used in previews via `ModelContainerPreview`
- `@Relationship` attributes with proper delete rules for data integrity

### App Structure

**iOS App:**
```
ScoreMatchingApp.swift (@main)
└── ContentView (main UI)
    ├── TapButton (core interaction)
    ├── SettingsView (team config, preferences)
    └── IntervalsList (period/quarter tracking)
```

**watchOS App:**
```
WTS_watchApp.swift (@main)
└── ContentView (watch UI)
    ├── TeamButtonView (watch score buttons)
    ├── SettingsView (watch settings)
    └── IntervalsListView (watch intervals)
```

**Entry point:**
- iOS: `ScoreMatchingApp.swift` uses modern SwiftUI lifecycle with `@UIApplicationDelegateAdaptor` for Firebase/analytics initialization in `AppDelegate.swift`.
- watchOS: `WTS_watchApp.swift` with simplified UI optimized for Apple Watch

### State Management

- `@AppStorage` for user preferences (keep screen awake, negative points enabled, intervals enabled)
- `@Environment(\.modelContext)` for SwiftData CRUD operations
- `@Query` for reactive data with automatic UI updates
- `@Bindable` for two-way binding with SwiftData models

### Feature Modules

**Settings** (`Features/Settings/`)
- Team management (add/remove/edit teams)
- Color customization (hex-based)
- App preferences (negative points, keep awake, intervals)
- App reset functionality
- App Store review prompts

**Intervals** (`Features/Intervals/`)
- Period/quarter/half tracking for sports like basketball, netball
- `IntervalsList` view displays all intervals with score breakdowns
- Shows cumulative scores and points gained per interval
- Can be toggled on/off in Settings
- Quick creation via context menu on timer button in main view
- Intervals snapshot team scores at specific moments for historical tracking

**Multipeer** (`Multipeer/`)
- Peer-to-peer score sharing using MultipeerConnectivity
- Supports observer/receiver mode
- Uses `CodableTeamData` for JSON serialization

**PDF** (`PDF/`)
- PDF export of scoreboards with full game summary
- `ScoreboardPDFPage` renders custom PDF with:
  - Final scores for all teams
  - Interval breakdown (if intervals enabled)
  - Points gained per interval
  - Color-coded team indicators
- `PDFCreator` utility with `generateScoreboardPDF()` and `savePDFToTemporaryFile()`
- Available in Settings → Export → "Export Scoreboard as PDF"
- Uses native iOS share sheet for saving/sharing PDFs

**Widget** (`Widget/`)
- WidgetKit extension for home screen
- Shares SwiftData container via App Groups
- Supports small and medium widget sizes

**Apple Watch** (`WTS-watch Watch App/`)
- Native watchOS companion app for score tracking on Apple Watch
- Full feature parity with iOS: score tracking, intervals, team management
- Watch-specific UI optimized for small screen (Digital Crown navigation, large tap targets)
- Independent operation with local SwiftData storage
- Real-time sync with iPhone via WatchConnectivity framework
- Shares WhatScoreKit package for models and utilities
- `WatchSyncCoordinator` manages bidirectional sync between iOS and watchOS
- Supports watchOS 11.0+

**WatchConnectivity** (`ScoreMatching/WatchConnectivity/`)
- `WatchConnectivityManager` - Handles WatchConnectivity session and message passing
- `WatchSyncCoordinator` - Coordinates data sync between iOS and watchOS apps
- Automatic syncing of teams, scores, and intervals
- Bidirectional updates ensure data consistency across devices
- Uses App Groups for shared SwiftData container access

### Core Interaction Pattern

**TapButton Component:**
- **Tap gesture** - Increments score
- **Drag gesture** - Decrements or removes last score (configurable)
- Haptic feedback on iOS
- Uses Pow library for visual change effects
- Adaptive sizing based on screen orientation (`verticalSizeClass`)

### Color System

Colors are central to the UI design:
- Each team has a hex-encoded color stored as string
- `WhatScoreKit/Sources/WhatScoreKit/Color+Decodable.swift` handles hex ↔ Color conversion
- `WhatScoreKit/Sources/WhatScoreKit/Color+random.swift` generates random colors with controlled saturation/brightness
- Supports iOS, watchOS, and macOS color systems
- Shared across all app targets via WhatScoreKit package

## Recent Improvements

**Recent Changes:**
- ✅ Added complete Apple Watch companion app with real-time sync (commit bde8193)
- ✅ Refactored to WhatScoreKit local package for code sharing across iOS, Widget, and watchOS
- ✅ Implemented WatchConnectivity for bidirectional sync between iPhone and Apple Watch
- ✅ Implemented complete intervals feature for tracking quarters/periods
- ✅ Completed PDF export functionality with full scoreboard and intervals
- ✅ Added support for negative points (configurable in Settings)
- ✅ Fixed critical SwiftData model container issues
- ✅ Removed force unwraps to prevent crashes
- ✅ Replaced debug print statements with proper OSLog
- ✅ Fixed Widget implementation
- ✅ Added proper @Relationship attributes to models
- ✅ Cleaned up dead code and unused views

## Analytics & Services

- **TelemetryDeck** - Privacy-focused analytics via `Analytics.log()` wrapper
- **Firebase** - Analytics and Crashlytics initialized in `AppDelegate`
- Analytics events logged for key user actions (team creation, score changes, etc.)

## Testing

Test targets exist for the Apple Watch app:
- `WTS-watch Watch AppTests` - Unit tests for watchOS app
- `WTS-watch Watch AppUITests` - UI tests for watchOS app

General testing approach:
- Extensive use of `#Preview` macros on all views (iOS and watchOS)
- `ModelContainerPreview` helper for SwiftData preview isolation
- Manual testing via Xcode
- Screenshot generation for App Store via Fastlane
- WhatScoreKit package includes `WhatScoreKitTests` target

## Key Technical Patterns

1. **Cross-platform architecture** - WhatScoreKit local package enables code sharing between iOS, watchOS, and Widget targets
2. **Gesture-based scoring** - Tap to add, drag to remove/subtract with haptic feedback
3. **Color-driven UI** - Full-screen team buttons with custom colors
4. **Time-aware scoring** - Timestamps on all score entries for interval analysis
5. **Adaptive layouts** - Portrait/landscape/iPad/watchOS support via `verticalSizeClass` and platform-specific layouts
6. **Real-time sync** - WatchConnectivity enables bidirectional data sync between iPhone and Apple Watch
7. **Conditional compilation** - `#if os(iOS)` for platform-specific features
8. **Smart review prompts** - Every 3rd launch via `@AppStorage` counter

## Configuration Files

- `Config.xcconfig` - Version and build number configuration
- `GoogleService-Info.plist` - Firebase configuration (required for build)
- Entitlements files - App Groups (`group.mcomisso.whatTheScore`) for Widget and watchOS data sharing
- Info.plist - Contains TelemetryDeck analytics ID
- `WhatScoreKit/Package.swift` - Local Swift Package manifest for shared code
