import SwiftData
import SwiftUI

struct MoreView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { ProfileView() } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading) {
                                Text(profiles.first.map { $0.fullName.isEmpty ? "Your Profile" : $0.fullName } ?? "Your Profile")
                                    .font(.headline)
                                Text("Personal details · encrypted").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Money") {
                    link("Accounts", "building.columns.fill", .blue) { AccountsView() }
                    link("Bills & Recurring", "repeat.circle.fill", .orange) { RecurringView() }
                    link("Savings Goals", "star.circle.fill", .green) { GoalsView() }
                    link("Reports", "chart.bar.xaxis", .purple) { ReportsView() }
                    link("Categories", "tag.fill", .pink) { CategoriesView() }
                }

                Section("App") {
                    link("Settings", "gearshape.fill", .gray) { SettingsView() }
                    link("Security & Privacy", "lock.shield.fill", .indigo) { SecurityInfoView() }
                }
            }
            .navigationTitle("More")
        }
    }

    private func link<Destination: View>(_ title: String, _ icon: String, _ color: Color, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            Label {
                Text(title)
            } icon: {
                CategoryIcon(icon: icon, color: color, size: 30)
            }
        }
    }
}
