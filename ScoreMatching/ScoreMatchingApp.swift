import SwiftUI
import StoreKit
import WidgetKit
import SwiftData

@main
struct ScoreMatchingApp: App {
    private let connectivity = Connectivity()

    @AppStorage("encodedTeamData", store: UserDefaults(suiteName: "group.mcomisso.whatTheScore"))
    var encodedTeamsData: Data = Data()

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @AppStorage("totalLaunches") var totalLaunches: Int = 1
    @Environment(\.requestReview) var requestReview
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(connectivity)
                .onAppear {
                    requestReviewIfNeeded()
                }
                .onChange(of: scenePhase) { phase in
                    onSceneActive(phase)
                    onSceneBackground(phase)
                }
        }.modelContainer(for: [Team.self])
    }

    private func onSceneBackground(_ phase: ScenePhase) {
        guard phase == .background else {
            return
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func onSceneActive(_ phase: ScenePhase) {
        guard phase == .active else {
            return
        }
        totalLaunches += 1
    }

    private func requestReviewIfNeeded() {
        if totalLaunches % 3 == 0 {
            requestReview()
        }
    }
}
