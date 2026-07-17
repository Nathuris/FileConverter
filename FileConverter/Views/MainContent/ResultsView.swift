import SwiftUI

/// 转换结果视图
struct ResultsView: View {
    let results: [ConversionResult]
    let successCount: Int
    let failureCount: Int
    let onConvertMore: () -> Void
    let onClearAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 结果头部
            VStack(spacing: 12) {
                Image(systemName: failureCount == 0 ? "checkmark.circle.fill" : "checkmark.circle.badge.xmark")
                    .font(.system(size: 48))
                    .foregroundStyle(failureCount == 0 ? .green : .orange)

                Text(failureCount == 0 ? "全部转换完成！" : "转换完成（有部分失败）")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("\(successCount) 个成功" + (failureCount > 0 ? "，\(failureCount) 个失败" : ""))
                    .font(.body)
                    .foregroundStyle(.secondary)

                // 总体大小对比
                let totalSource = results.reduce(0) { $0 + $1.sourceSize }
                let totalOutput = results.filter(\.success).reduce(0) { $0 + $1.outputSize }
                if totalSource > 0 && totalOutput > 0 {
                    Text("总大小：\(FileSizeFormatter.compare(original: totalSource, converted: totalOutput))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 24)

            Divider()
                .padding(.horizontal, 16)

            // 结果列表
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { result in
                        ResultRow(result: result)
                        Divider()
                            .padding(.leading, 52)
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()
                .padding(.horizontal, 16)

            // 底部按钮
            HStack(spacing: 12) {
                Button(action: onClearAll) {
                    Label("清空并重新开始", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: onConvertMore) {
                    Label("继续转换", systemImage: "arrow.triangle.2.circlepath")
                        .padding(.horizontal, 16)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 单条结果行
struct ResultRow: View {
    let result: ConversionResult

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.success ? .green : .red)
                .font(.title3)

            // 文件信息
            VStack(alignment: .leading, spacing: 2) {
                Text(result.sourceFile.fileName)
                    .font(.body)
                    .lineLimit(1)

                if result.success {
                    Text(result.sizeChangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("耗时 \(result.durationText)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(result.errorMessage ?? "未知错误")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Spacer()

            // 操作按钮
            if result.success {
                Button(action: {
                    NSWorkspace.shared.activateFileViewerSelecting([result.outputURL])
                }) {
                    Image(systemName: "folder")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("在 Finder 中显示")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
