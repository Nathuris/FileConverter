import SwiftUI

/// 侧边栏类别行
struct CategoryRow: View {
    let category: FormatCategory
    let count: Int
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.sfSymbol)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            Text(category.rawValue)
                .font(.body)

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }

            // 工具可用性指示灯
            if category != .all {
                Circle()
                    .fill(availabilityColor)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }

    private var availabilityColor: Color {
        if isAvailable { return .green }
        return .orange
    }
}
