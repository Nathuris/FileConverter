import SwiftUI

/// 文件列表中的单行
struct FileRowView: View {
    let file: ConversionFile
    let availableTargets: [ConversionFormat]
    let onTargetChange: (ConversionFormat) -> Void
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // 缩略图
            ThumbnailView(image: file.thumbnail, fileURL: file.sourceURL)
                .frame(width: 40, height: 40)

            // 文件信息
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    // 源格式标签
                    FormatBadge(format: file.detectedFormat.displayName)

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    // 目标格式选择器
                    FormatPicker(
                        sourceFormat: file.detectedFormat,
                        selectedTarget: file.targetFormat,
                        availableTargets: availableTargets,
                        onSelect: onTargetChange
                    )
                }
            }

            Spacer()

            // 文件大小
            Text(FileSizeFormatter.format(file.fileSize))
                .font(.caption)
                .foregroundStyle(.secondary)

            // 状态
            statusView
                .frame(width: 24)

            // 删除按钮
            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch file.status {
        case .pending:
            EmptyView()
        case .converting:
            ProgressView()
                .scaleEffect(0.6)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

/// 格式标签
struct FormatBadge: View {
    let format: String

    var body: some View {
        Text(format)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
    }
}
