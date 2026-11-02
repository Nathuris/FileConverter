import SwiftUI
import UniformTypeIdentifiers

/// 文件列表视图
struct FileListView: View {
    let files: [ConversionFile]
    let selectedFileIDs: Binding<Set<UUID>>
    let selectedCategory: FormatCategory
    let availableTargets: (ConversionFile) -> [ConversionFormat]
    let onTargetChange: (ConversionFile, ConversionFormat) -> Void
    let onRemove: (ConversionFile) -> Void
    let onFilesDropped: ([URL]) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部信息
            HStack {
                Text("\(files.count) 个文件")
                    .font(.headline)

                if selectedCategory != .all {
                    Text("·")
                    Text(selectedCategory.rawValue)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !selectedFileIDs.wrappedValue.isEmpty {
                    Button("移除所选 (\(selectedFileIDs.wrappedValue.count))") {
                        NotificationCenter.default.post(name: .removeSelectedFiles, object: nil)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // 拖放添加区（始终可见的细条）
            dropAddBar

            // 文件列表
            // 注意：onDrop 只挂在上方细条，不要挂整页——整页接收拖放会抢走
            // 行内「目标格式」菜单的点击。
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(files) { file in
                        FileRowView(
                            file: file,
                            availableTargets: availableTargets(file),
                            onTargetChange: { format in
                                onTargetChange(file, format)
                            },
                            onRemove: {
                                onRemove(file)
                            }
                        )
                        .id(file.id)

                        Divider()
                            .padding(.leading, 64)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 顶部的快速拖放区
    private var dropAddBar: some View {
        HStack(spacing: 6) {
            Image(systemName: isDropTargeted ? "arrow.down.doc.fill" : "plus.circle")
                .font(.callout)
                .foregroundColor(isDropTargeted ? .blue : .secondary)
            Text(isDropTargeted ? "松开以添加文件" : "拖放文件到此处添加，或点「添加文件…」")
                .font(.caption)
                .foregroundColor(isDropTargeted ? .blue : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    isDropTargeted ? Color.blue : Color.secondary.opacity(0.15),
                    style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [4, 3])
                )
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isDropTargeted ? Color.blue.opacity(0.06) : Color.clear)
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            NotificationCenter.default.post(name: .addFiles, object: nil)
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        // 与空白页拖放区同一套读法：macOS 拖文件给的是「文件路径的二进制」，
        // 用 loadObject(URL) 经常读不到。
        Task {
            var urls: [URL] = []
            for provider in providers {
                if let identifier = provider.registeredTypeIdentifiers.first,
                   let data = try? await provider.loadItem(forTypeIdentifier: identifier) as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
            }
            await MainActor.run {
                if !urls.isEmpty {
                    onFilesDropped(urls)
                }
            }
        }
    }
}
