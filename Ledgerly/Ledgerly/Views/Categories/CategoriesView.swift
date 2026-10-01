import SwiftData
import SwiftUI

/// Manage categories: add your own, rename, recolor, nest, delete.
struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]
    @State private var kind: CategoryKind = .expense
    @State private var editing: LedgerCategory?
    @State private var showingAdd = false
    @State private var pendingDelete: LedgerCategory?

    private var roots: [LedgerCategory] {
        categories.filter { $0.parent == nil && $0.kind == kind }
    }

    var body: some View {
        List {
            Picker("Kind", selection: $kind) {
                ForEach(CategoryKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            ForEach(roots) { root in
                Section {
                    row(root, indent: false)
                    ForEach(root.sortedChildren) { child in
                        row(child, indent: true)
                    }
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill") }
            }
        }
        .sheet(isPresented: $showingAdd) { CategoryFormView(kind: kind) }
        .sheet(item: $editing) { CategoryFormView(category: $0, kind: $0.kind) }
        .confirmationDialog(
            "Delete \(pendingDelete?.name ?? "category")?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let pendingDelete {
                    modelContext.delete(pendingDelete)
                    try? modelContext.save()
                }
                pendingDelete = nil
            }
        } message: {
            Text(pendingDelete?.isTopLevel == true && !(pendingDelete?.children ?? []).isEmpty
                 ? "Its subcategories and budgets will also be deleted. Transactions are kept as uncategorized."
                 : "Transactions in this category are kept as uncategorized.")
        }
    }

    private func row(_ category: LedgerCategory, indent: Bool) -> some View {
        Button { editing = category } label: {
            HStack(spacing: 12) {
                CategoryIcon(icon: category.icon, color: category.color, size: indent ? 28 : 34)
                    .padding(.leading, indent ? 16 : 0)
                Text(category.name)
                    .font(indent ? .body : .body.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                let count = category.transactions?.count ?? 0
                if count > 0 {
                    Text("\(count)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions {
            Button(role: .destructive) { pendingDelete = category } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

struct CategoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]

    private let category: LedgerCategory?
    private let kind: CategoryKind
    @State private var name: String
    @State private var icon: String
    @State private var colorHex: String
    @State private var parent: LedgerCategory?

    init(category: LedgerCategory? = nil, kind: CategoryKind) {
        self.category = category
        self.kind = kind
        _name = State(initialValue: category?.name ?? "")
        _icon = State(initialValue: category?.icon ?? "tag.fill")
        _colorHex = State(initialValue: category?.colorHex ?? "#0A84FF")
        _parent = State(initialValue: category?.parent)
    }

    /// Only top-level categories can be parents, and a group with children can't be nested.
    private var possibleParents: [LedgerCategory] {
        categories.filter { $0.parent == nil && $0.kind == kind && $0.id != category?.id }
    }

    private var canHaveParent: Bool { (category?.children ?? []).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        CategoryIcon(icon: icon, color: Color(hex: colorHex), size: 40)
                        TextField("Category name", text: $name).font(.headline)
                    }
                    if canHaveParent {
                        Picker("Group", selection: $parent) {
                            Text("None (top level)").tag(nil as LedgerCategory?)
                            ForEach(possibleParents) { Text($0.name).tag($0 as LedgerCategory?) }
                        }
                    }
                }
                Section("Icon") { IconPicker(selection: $icon, color: Color(hex: colorHex)) }
                Section("Color") { ColorSwatchPicker(selection: $colorHex) }
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: parent) { _, newParent in
                if let newParent, category == nil { colorHex = newParent.colorHex }
            }
        }
    }

    private func save() {
        let target: LedgerCategory
        if let category {
            target = category
        } else {
            let siblings = categories.filter { $0.parent?.id == parent?.id && $0.kind == kind }
            target = LedgerCategory(name: "", icon: icon, colorHex: colorHex, kind: kind, sortOrder: (siblings.map(\.sortOrder).max() ?? -1) + 1)
            modelContext.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.icon = icon
        target.colorHex = colorHex
        if canHaveParent { target.parent = parent }
        try? modelContext.save()
        dismiss()
    }
}
