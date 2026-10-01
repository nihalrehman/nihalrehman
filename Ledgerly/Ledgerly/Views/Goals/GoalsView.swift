import SwiftData
import SwiftUI

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @State private var showingAdd = false
    @State private var editing: SavingsGoal?
    @State private var contributingTo: SavingsGoal?

    var body: some View {
        List {
            if !goals.isEmpty {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Saved").font(.caption).foregroundStyle(.secondary)
                            MoneyText(goals.sum(\.savedAmount)).font(.title2.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Target").font(.caption).foregroundStyle(.secondary)
                            MoneyText(goals.sum(\.targetAmount)).font(.headline)
                        }
                    }
                }
            }

            ForEach(goals) { goal in
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            CategoryIcon(icon: goal.icon, color: goal.color)
                            VStack(alignment: .leading) {
                                Text(goal.name).font(.headline)
                                if let date = goal.targetDate {
                                    Text("By \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if goal.isComplete {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.title2)
                            }
                        }
                        ProgressBar(value: goal.progress, tint: goal.color, height: 10)
                        HStack {
                            MoneyText(goal.savedAmount).font(.subheadline.weight(.semibold))
                            Text("of").foregroundStyle(.secondary)
                            MoneyText(goal.targetAmount).foregroundStyle(.secondary)
                            Spacer()
                            Text(goal.progress.formatted(.percent.precision(.fractionLength(0)))).font(.subheadline.bold())
                        }
                        .font(.subheadline)
                        if let monthly = goal.requiredMonthlyContribution {
                            HStack(spacing: 4) {
                                Text("Save")
                                MoneyText(monthly)
                                Text("per month to reach it on time")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        HStack {
                            Button { contributingTo = goal } label: { Label("Add Money", systemImage: "plus") }
                                .buttonStyle(.bordered)
                            Spacer()
                            Button("Edit") { editing = goal }.buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .overlay {
            if goals.isEmpty {
                ContentUnavailableView {
                    Label("No Savings Goals", systemImage: "star.circle")
                } description: {
                    Text("Emergency fund, house deposit, new car, holiday — set a target and track your progress.")
                } actions: {
                    Button("Add a Goal") { showingAdd = true }.buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Savings Goals")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill") }
            }
        }
        .sheet(isPresented: $showingAdd) { GoalFormView() }
        .sheet(item: $editing) { GoalFormView(goal: $0) }
        .sheet(item: $contributingTo) { ContributionView(goal: $0) }
    }
}

struct ContributionView: View {
    let goal: SavingsGoal
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var amount: Decimal?
    @State private var withdraw = false

    var body: some View {
        NavigationStack {
            Form {
                Picker("Action", selection: $withdraw) {
                    Text("Add").tag(false)
                    Text("Withdraw").tag(true)
                }
                .pickerStyle(.segmented)
                AmountField(title: "Amount", amount: $amount, large: true)
            }
            .navigationTitle(goal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount, amount > 0 else { return }
                        goal.savedAmount = max(goal.savedAmount + (withdraw ? -amount : amount), 0)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled((amount ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct GoalFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let goal: SavingsGoal?
    @State private var name: String
    @State private var icon: String
    @State private var colorHex: String
    @State private var target: Decimal?
    @State private var saved: Decimal?
    @State private var hasDate: Bool
    @State private var targetDate: Date
    @State private var notes: String

    init(goal: SavingsGoal? = nil) {
        self.goal = goal
        _name = State(initialValue: goal?.name ?? "")
        _icon = State(initialValue: goal?.icon ?? "star.fill")
        _colorHex = State(initialValue: goal?.colorHex ?? "#30D158")
        _target = State(initialValue: goal?.targetAmount)
        _saved = State(initialValue: goal?.savedAmount)
        _hasDate = State(initialValue: goal?.targetDate != nil)
        _targetDate = State(initialValue: goal?.targetDate ?? Date().adding(months: 12))
        _notes = State(initialValue: goal?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Goal name (e.g. Emergency Fund)", text: $name)
                    LabeledContent("Target") { AmountField(title: "0", amount: $target).multilineTextAlignment(.trailing) }
                    LabeledContent("Already saved") { AmountField(title: "0", amount: $saved).multilineTextAlignment(.trailing) }
                    Toggle("Target date", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Date", selection: $targetDate, in: Date()..., displayedComponents: .date)
                    }
                }
                Section("Icon") { IconPicker(selection: $icon, color: Color(hex: colorHex)) }
                Section("Color") { ColorSwatchPicker(selection: $colorHex) }
                Section("Notes") { TextField("Optional", text: $notes, axis: .vertical) }
                if let goal {
                    Section {
                        Button("Delete Goal", role: .destructive) {
                            modelContext.delete(goal)
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(goal == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (target ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        let item: SavingsGoal
        if let goal {
            item = goal
        } else {
            item = SavingsGoal(name: "", icon: icon, colorHex: colorHex, targetAmount: 0)
            modelContext.insert(item)
        }
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.icon = icon
        item.colorHex = colorHex
        item.targetAmount = target ?? 0
        item.savedAmount = saved ?? 0
        item.targetDate = hasDate ? targetDate : nil
        item.notes = notes
        try? modelContext.save()
        dismiss()
    }
}
