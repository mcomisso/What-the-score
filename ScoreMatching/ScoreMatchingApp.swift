import SwiftUI
import StoreKit

@main
struct ScoreMatchingApp: App {
    private let connectivity = Connectivity()

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @AppStorage("totalLaunches") var totalLaunches: Int = 1
    @Environment(\.requestReview) var requestReview
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(connectivity)
                .task {
                    await requestReviewIfNeeded()
                }
                .onChange(of: scenePhase) { phase in
                    onSceneActive(phase)
                }
        }
    }

    private func onSceneActive(_ phase: ScenePhase) {
        if phase == .active {
            totalLaunches += 1
        }
    }

    @MainActor
    private func requestReviewIfNeeded() async {
        if totalLaunches % 3 == 0 {
            requestReview()
        }
    }
}
