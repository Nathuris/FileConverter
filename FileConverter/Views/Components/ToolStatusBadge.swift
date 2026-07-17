import SwiftUI

/// 工具状态指示灯
struct ToolStatusBadge: View {
    let isAvailable: Bool
    let toolName: String
    let version: String?
    let installCommand: String?

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isAvailable ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(toolName)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let ver = version {
                Text(ver)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .help(isAvailable ? "\(toolName) 可用" : "\(toolName) 未安装")
    }
}
