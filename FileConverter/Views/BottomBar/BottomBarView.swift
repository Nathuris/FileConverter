import SwiftUI

/// 底部操作栏
struct BottomBarView: View {
    let fileCount: Int
    let canConvert: Bool
    let outputDirectory: URL
    let onSelectOutputDirectory: () -> Void
    let onConvert: () -> Void
    let onSettings: () -> Void

    @State private var showDirectoryPicker = false

    var body: some View {
        HStack(spacing: 16) {
            // 文件计数
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                Text("\(fileCount) 个文件")
                    .font(.callout)
            }
            .foregroundStyle(.secondary)

            Spacer()

            // 输出目录
            Button(action: onSelectOutputDirectory) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                    Text(outputDirectory.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: 100)
                }
                .font(.callout)
            }
            .buttonStyle(.borderless)
            .help("选择输出目录")

            // 设置按钮
            Button(action: onSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("设置")

            // 转换按钮
            Button(action: onConvert) {
                Label("转换", systemImage: "arrow.triangle.2.circlepath")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canConvert)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}
