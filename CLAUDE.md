# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"What the Score" is an iOS score-tracking application built with SwiftUI and SwiftData (iOS 17+). The app allows users to track game scores with gesture-based interactions, supports peer-to-peer score sharing via MultipeerConnectivity, and includes a WidgetKit extension for home screen widgets.

**Bundle ID:** `com.mcomisso.ScoreMatching`
**Deployment Target:** iOS 17.0+

## Build & Development Commands

### Building & Running
- Open `ScoreMatching.xcodeproj` in Xcode
- Build and run using Xcode (Cmd+R)
- The project uses standard Xcode build system (no custom build scripts)

### Screenshots
```bash
bundle exec fastlane screenshots
```
Generates localized App Store screenshots using the ScoreMatching scheme.

### Dependencies
All dependencies are managed via Swift Package Manager (integrated in Xcode):
- **TelemetryDeck/SwiftClient** - Privacy-focused analytics
- **Firebase iOS SDK** - Analytics and Crashlytics
- **EmergeTools/Pow** - SwiftUI animation effects

No need to run package installation commands; Xcode handles this automatically.

## Architecture

### Data Layer (SwiftData Models)

All models are in `Models/SwiftDataModel.swift`:
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
- App Groups (`group.mcomisso.whatTheScore`) for sharing data with Widget extension
- In-memory containers used in previews via `ModelContainerPreview`
- `@Relationship` attributes with proper delete rules for data integrity

### App Structure

```
ScoreMatchingApp.swift (@main)
└── ContentView (main UI)
    ├── TapButton (core interaction)
    ├── SettingsView (team config, preferences)
    └── IntervalsList (period/quarter tracking)
```

**Entry point:** `ScoreMatchingApp.swift` uses modern SwiftUI lifecycle with `@UIApplicationDelegateAdaptor` for Firebase/analytics initialization in `AppDelegate.swift`.

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
- `Color+Decodable.swift` handles hex ↔ Color conversion
- `Color+random.swift` generates random colors with controlled saturation/brightness
- Supports both iOS and macOS color systems

## Recent Improvements

**Recent Changes:**
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

No formal test targets exist. Testing approach:
- Extensive use of `#Preview` macros on all views
- `ModelContainerPreview` helper for SwiftData preview isolation
- Manual testing via Xcode
- Screenshot generation for App Store via Fastlane

## Key Technical Patterns

1. **Gesture-based scoring** - Tap to add, drag to remove/subtract with haptic feedback
2. **Color-driven UI** - Full-screen team buttons with custom colors
3. **Time-aware scoring** - Timestamps on all score entries for interval analysis
4. **Adaptive layouts** - Portrait/landscape/iPad support via `verticalSizeClass`
5. **Conditional compilation** - `#if os(iOS)` for platform-specific features
6. **Smart review prompts** - Every 3rd launch via `@AppStorage` counter

## Configuration Files

- `Config.xcconfig` - Version and build number configuration
- `GoogleService-Info.plist` - Firebase configuration (required for build)
- Entitlements files - App Groups for Widget data sharing
- Info.plist - Contains TelemetryDeck analytics ID
