import SwiftUI
import UniformTypeIdentifiers

/// 拖放区域视图（空态时显示）
struct DropZoneView: View {
    let onFilesDropped: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isTargeted ? "arrow.down.doc" : "doc.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(isTargeted ? .blue : .secondary)
                .symbolEffect(.bounce, value: isTargeted)

            VStack(spacing: 8) {
                Text("将文件拖放到此处")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("或点击下方按钮选择文件")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text("支持图片、文档、音频、视频、归档、文本数据等 100+ 种格式")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: openFilePicker) {
                Label("选择文件…", systemImage: "folder")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted ? Color.blue : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: isTargeted ? 3 : 2, dash: [8, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isTargeted ? Color.blue.opacity(0.08) : Color.clear)
                )
                .padding(40)
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
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
                onFilesDropped(urls)
            }
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = []  // 接受所有类型

        if panel.runModal() == .OK {
            onFilesDropped(panel.urls)
        }
    }
}
