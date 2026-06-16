import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var fitnessStore = FitnessStore()
    @StateObject private var routeTracker = RouteTracker()
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            DashboardView(store: fitnessStore, routeTracker: routeTracker)
                .opacity(isShowingSplash ? 0 : 1)

            if isShowingSplash {
                SplashView()
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
                    .zIndex(1)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            fitnessStore.refreshToday()
        }
        .task {
            fitnessStore.start()
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeInOut(duration: 0.45)) {
                isShowingSplash = false
            }
        }
    }
}

