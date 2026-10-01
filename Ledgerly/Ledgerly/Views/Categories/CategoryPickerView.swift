import SwiftData
import SwiftUI

/// Picks a category or subcategory, grouped by top-level category.
struct CategoryPickerView: View {
    let kind: CategoryKind
    @Binding var selection: LedgerCategory?
    var allowsGroups = true

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]
    @State private var search = ""

    private var roots: [LedgerCategory] {
        categories.filter { $0.parent == nil && $0.kind == kind }
    }

    private func matches(_ category: LedgerCategory) -> Bool {
        search.isEmpty || category.name.localizedCaseInsensitiveContains(search)
    }

    var body: some View {
        List {
            ForEach(roots) { root in
                let children = root.sortedChildren.filter(matches)
                if matches(root) || !children.isEmpty {
                    Section {
                        if allowsGroups || root.sortedChildren.isEmpty {
                            row(root, indent: false)
                        } else {
                            Label(root.name, systemImage: root.icon)
                                .font(.headline)
                                .foregroundStyle(root.color)
                        }
                        ForEach(search.isEmpty ? root.sortedChildren : children) { child in
                            row(child, indent: true)
                        }
                    }
                }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle("Category")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ category: LedgerCategory, indent: Bool) -> some View {
        Button {
            selection = category
            dismiss()
        } label: {
            HStack(spacing: 12) {
                CategoryIcon(icon: category.icon, color: category.color, size: indent ? 28 : 34)
                    .padding(.leading, indent ? 16 : 0)
                Text(category.name)
                    .font(indent ? .body : .body.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if selection?.id == category.id {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
    }
}
