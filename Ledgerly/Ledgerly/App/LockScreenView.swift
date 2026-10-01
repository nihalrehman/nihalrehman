import SwiftUI

struct LockScreenView: View {
    @Environment(AppLockManager.self) private var lockManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text("Ledgerly is Locked")
                    .font(.title2.bold())
                Text("Your financial data is encrypted on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button {
                Task { await lockManager.unlock() }
            } label: {
                Label("Unlock with \(AppLockManager.biometryName)", systemImage: AppLockManager.biometryIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(lockManager.isAuthenticating)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
