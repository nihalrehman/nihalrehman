import SwiftData
import SwiftUI

/// Top-level view: owns app-lock gating and the privacy cover shown in the app switcher.
struct RootView: View {
    @Environment(AppLockManager.self) private var lockManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.didOnboard) private var didOnboard = false
    @State private var showPrivacyCover = false

    var body: some View {
        ZStack {
            if lockManager.isLocked {
                // Data views are not even built while locked.
                LockScreenView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }

            if showPrivacyCover && !lockManager.isLocked {
                PrivacyCoverView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: lockManager.isLocked)
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                showPrivacyCover = false
                lockManager.sceneDidBecomeActive()
                RecurrenceEngine.processDue(in: modelContext)
                Task { await NotificationScheduler.reschedule(in: modelContext) }
            case .inactive:
                // Hides balances in the app switcher snapshot.
                showPrivacyCover = true
            case .background:
                showPrivacyCover = true
                lockManager.sceneDidEnterBackground()
            @unknown default:
                break
            }
        }
        .task {
            SeedData.seedIfNeeded(modelContext)
        }
        .fullScreenCover(isPresented: Binding(get: { !didOnboard && !lockManager.isLocked }, set: { _ in })) {
            OnboardingView { didOnboard = true }
        }
    }
}

struct PrivacyCoverView: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThickMaterial).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Ledgerly")
                    .font(.title2.bold())
            }
        }
    }
}
