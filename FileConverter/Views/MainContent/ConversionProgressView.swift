import SwiftUI

/// 转换进度视图
struct ConversionProgressView: View {
    let progress: Double
    let files: [ConversionFile]
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 进度图标
            Image(systemName: "gearshape.2")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .symbolEffect(.rotate, options: .nonRepeating)

            // 进度文字
            VStack(spacing: 8) {
                Text("正在转换…")
                    .font(.title2)
                    .fontWeight(.medium)

                let completed = Int(progress * Double(files.count))
                Text("已完成 \(completed) / \(files.count) 个文件")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // 进度条
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 300)
                .tint(.blue)

            // 百分比
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // 当前处理的文件列表
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(files) { file in
                        HStack(spacing: 8) {
                            switch file.status {
                            case .converting:
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 16, height: 16)
                            case .completed:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            case .failed:
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            case .pending:
                                Circle()
                                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
                                    .frame(width: 12, height: 12)
                            }

                            Text(file.fileName)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: 400, maxHeight: 200)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))

            // 取消按钮
            Button(action: onCancel) {
                Text("取消转换")
                    .padding(.horizontal, 20)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
