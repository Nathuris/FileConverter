import SwiftUI

/// 侧边栏导航
struct SidebarView: View {
    @Binding var selectedCategory: FormatCategory
    let fileCountByCategory: [FormatCategory: Int]
    let availableCategories: Set<FormatCategory>

    var body: some View {
        List(selection: $selectedCategory) {
            Section {
                ForEach(FormatCategory.allCases, id: \.self) { category in
                    CategoryRow(
                        category: category,
                        count: count(for: category),
                        isAvailable: availableCategories.contains(category)
                    )
                    .tag(category)
                }
            } header: {
                Text("文件类别")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            Section {
                Button(action: {
                    // 通过通知触发清空
                    NotificationCenter.default.post(name: .clearAllFiles, object: nil)
                }) {
                    Label("清空所有文件", systemImage: "trash")
                }
                .buttonStyle(.plain)

                Button(action: {
                    // 通过通知触发添加
                    NotificationCenter.default.post(name: .addFiles, object: nil)
                }) {
                    Label("添加文件…", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.plain)
            } header: {
                Text("快捷操作")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .frame(minWidth: 180)
        .animation(.none, value: selectedCategory)
    }

    private func count(for category: FormatCategory) -> Int {
        if category == .all {
            return fileCountByCategory.values.reduce(0, +)
        }
        return fileCountByCategory[category] ?? 0
    }
}
