import Foundation
import SwiftUI
import SwiftData
import WhatScoreKit
import OSLog

private let newGameLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcomisso.ScoreMatching", category: "NewGame")

struct NewGameButton: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.watchSyncCoordinator) private var watchSyncCoordinator
    @Query(sort: \Team.creationDate) private var teams: [Team]
    @Query(sort: \Interval.date) private var intervals: [Interval]

    @AppStorage(SportStorageKeys.defaultSelection) private var defaultSportStorage = ""
    @AppStorage(SportStorageKeys.currentSelection) private var currentSportStorage = ""

    @State private var showingSportPicker = false

    let catalogStore: SportCatalogStore

    var body: some View {
        Button {
            showingSportPicker = true
        } label: {
            Label("New game", systemImage: "plus.circle")
        }
        .sheet(isPresented: $showingSportPicker) {
            SportSelectionView(
                initialSelection: SportSelection(storageValue: defaultSportStorage),
                catalogStore: catalogStore,
                mode: .newGame
            ) { selection in
                if startGame(with: selection) {
                    showingSportPicker = false
                }
            }
        }
    }

    private func startGame(with selection: SportSelection) -> Bool {
        teams.forEach { $0.score = [] }
        intervals.forEach { modelContext.delete($0) }
        do {
            try modelContext.save()
            currentSportStorage = selection.storageValue
            watchSyncCoordinator?.sendPreferences([
                SportStorageKeys.currentSelection: selection.storageValue
            ])
            watchSyncCoordinator?.sendData()
            Analytics.log(.appReinitialized, with: ["team_count": "\(teams.count)", "interval_count": "\(intervals.count)", "source": "new_game"])
            return true
        } catch {
            modelContext.rollback()
            newGameLogger.error("Failed to start a new game: \(error.localizedDescription)")
            return false
        }
    }
}

struct SportSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case newGame
        case defaultSport
    }

    private enum Step: Hashable {
        case customSport
        case review
        case scoring
    }

    let mode: Mode
    let onChoose: (SportSelection) -> Void
    let catalogStore: SportCatalogStore
    let initialSelection: SportSelection?

    @State private var path: [Step]
    @State private var selectedSportID: String?
    @State private var customName: String
    @State private var scoreValuesText: String

    init(initialSelection: SportSelection?, catalogStore: SportCatalogStore, mode: Mode, onChoose: @escaping (SportSelection) -> Void) {
        self.initialSelection = initialSelection
        self.catalogStore = catalogStore
        self.mode = mode
        self.onChoose = onChoose
        _path = State(initialValue: mode == .newGame && initialSelection != nil ? [.review] : [])
        _selectedSportID = State(initialValue: initialSelection?.sportID)
        _customName = State(initialValue: initialSelection?.customName ?? "")
        _scoreValuesText = State(initialValue: initialSelection?.customScoreValues.map(String.init).joined(separator: ", ") ?? "")
    }

    private var availableSports: [SportDefinition] {
        var sports = catalogStore.sports.filter { $0.id != SportPreset.custom.rawValue }
        if let initialSelection,
           !sports.contains(where: { $0.id == initialSelection.sportID }),
           initialSelection.sportID != SportPreset.custom.rawValue {
            sports.append(initialSelection.definition)
        }
        sports.append(catalogStore.sports.first(where: { $0.id == SportPreset.custom.rawValue }) ?? SportPreset.custom.definition)
        return sports
    }

    private var selectedDefinition: SportDefinition? {
        availableSports.first(where: { $0.id == selectedSportID })
    }

    private var customScoreValues: [Int]? {
        let trimmed = scoreValuesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false)
        let values = parts.compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard values.count == parts.count,
              values.count <= 8,
              values.allSatisfy({ (1...1_000).contains($0) }),
              Set(values).count == values.count else { return nil }
        return values
    }

    private var selection: SportSelection? {
        guard let selectedDefinition else { return nil }
        return SportSelection(
            definition: selectedDefinition,
            customName: customName,
            customScoreValues: customScoreValues ?? []
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            page {
                sportChoices
            }
            .navigationTitle(mode == .newGame ? "New game" : "Default sport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(for: Step.self) { step in
                destination(for: step)
            }
        }
    }

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: 640, alignment: .leading)
                .padding(20)
                .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    @ViewBuilder
    private func destination(for step: Step) -> some View {
        page {
            switch step {
            case .customSport: customSportDetails
            case .review: review
            case .scoring: scoringDetails
            }
        }
        .navigationTitle(stepTitle(for: step))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                switch step {
                case .customSport:
                    path.append(.review)
                case .scoring:
                    path.removeLast()
                case .review:
                    if let selection { onChoose(selection) }
                }
            } label: {
                Text(footerTitle(for: step))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(footerDisabled(for: step))
            .frame(maxWidth: 600)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        }
    }

    private func stepTitle(for step: Step) -> String {
        switch step {
        case .customSport: "Custom game"
        case .review: "Review"
        case .scoring: "Scoring"
        }
    }

    private func footerTitle(for step: Step) -> String {
        switch step {
        case .customSport: "Continue"
        case .review: mode == .newGame ? "Start new game" : "Save default"
        case .scoring: "Done"
        }
    }

    private func footerDisabled(for step: Step) -> Bool {
        switch step {
        case .customSport: customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .scoring: customScoreValues == nil
        case .review: selection == nil || customScoreValues == nil
        }
    }

    private var sportChoices: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What are you playing?")
                    .font(.title2.bold())
                Text("Choose a sport. We’ll set up its scoring and game parts for you.")
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                ForEach(availableSports) { sport in
                    Button {
                        if selectedSportID != sport.id { scoreValuesText = "" }
                        selectedSportID = sport.id
                        path.append(sport.id == SportPreset.custom.rawValue ? .customSport : .review)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: iconName(for: sport))
                                .font(.title2)
                                .frame(width: 36, height: 36)
                                .accessibilityHidden(true)
                            Spacer(minLength: 0)
                            Text(sport.name)
                                .font(.headline)
                                .lineLimit(2)
                            Text("\(sport.intervalPlural) · \(sport.scoreValues.map { "+\($0)" }.joined(separator: " "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(selectedSportID == sport.id ? Color.accentColor : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(sport.name), \(sport.intervalPlural), scoring \(sport.scoreValues.map(String.init).joined(separator: ", "))")
                }
            }
        }
    }

    private var customSportDetails: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: selectedDefinition.map { iconName(for: $0) } ?? SportDefinition.fallbackSymbolName)
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("Name your game")
                .font(.title2.bold())
            Text("We’ll call each part of the game a round. You can adjust scoring on the next screen.")
                .foregroundStyle(.secondary)
            TextField("Game name", text: $customName)
                .textInputAutocapitalization(.words)
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .submitLabel(.done)
        }
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let selection {
                Image(systemName: iconName(for: selection.definition))
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(selection.displayName)
                    .font(.largeTitle.bold())
                Button("Change sport", systemImage: "arrow.triangle.2.circlepath") {
                    path.removeAll()
                }
                .buttonStyle(.borderless)

                VStack(spacing: 0) {
                    summaryRow("Each tap adds", value: "+\(selection.scoreValues.first ?? 1)", symbol: "plus.circle.fill")
                    Divider().padding(.leading, 52)
                    summaryRow("Other score values", value: selection.scoreValues.dropFirst().map { "+\($0)" }.joined(separator: ", ").isEmpty ? "None" : selection.scoreValues.dropFirst().map { "+\($0)" }.joined(separator: ", "), symbol: "number.circle")
                    Divider().padding(.leading, 52)
                    summaryRow("Game parts", value: selection.intervalPlural, symbol: "square.stack.3d.up")
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))

                Button("Adjust scoring", systemImage: "slider.horizontal.3") {
                    path.append(.scoring)
                }

                if mode == .newGame {
                    Label("Starting clears scores and previous \(selection.intervalPlural.lowercased()). Team names and colors stay.", systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("This sport will be ready when you start a new game.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func summaryRow(_ title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .frame(width: 28)
                .foregroundStyle(.tint)
            Text(title)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(16)
    }

    private var scoringDetails: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Adjust scoring")
                .font(.title2.bold())
            Text("Enter up to eight point values, separated by commas. Leave blank to use \(selectedDefinition?.name ?? "the sport")’s suggested values.")
                .foregroundStyle(.secondary)
            TextField("For example: 1, 2, 3", text: $scoreValuesText)
                .keyboardType(.numbersAndPunctuation)
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            if customScoreValues == nil {
                Label("Use unique whole numbers from 1 to 1000.", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.red)
                    .font(.subheadline)
            } else if let selection {
                Text("Tap adds +\(selection.scoreValues.first ?? 1). Hold a team to choose another value.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func iconName(for sport: SportDefinition) -> String {
        UIImage(systemName: sport.symbolName) == nil ? SportDefinition.fallbackSymbolName : sport.symbolName
    }
}
