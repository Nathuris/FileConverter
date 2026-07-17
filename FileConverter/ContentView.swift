import SwiftUI

struct ContentView: View {
    @State var viewModel: ConversionViewModel
    @State private var dropVM = DropZoneViewModel()
    @State private var selectedCategory: FormatCategory = .all

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedCategory: $selectedCategory,
                fileCountByCategory: viewModel.fileCountByCategory,
                availableCategories: availableCategorySet()
            )
            .navigationSplitViewColumnWidth(200)
        } detail: {
            VStack(spacing: 0) {
                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if viewModel.appState == .hasFiles || viewModel.appState == .empty {
                    BottomBarView(
                        fileCount: viewModel.files.count,
                        canConvert: viewModel.canConvert,
                        outputDirectory: viewModel.outputDirectory,
                        onSelectOutputDirectory: selectOutputDirectory,
                        onConvert: {
                            selectedCategory = .all
                            viewModel.startConversion()
                        },
                        onSettings: openSettingsWindow
                    )
                }
            }
            .navigationTitle("FileConverter")
        }
        .onChange(of: selectedCategory) { _, newValue in
            viewModel.selectedCategory = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearAllFiles)) { _ in viewModel.clearAll() }
        .onReceive(NotificationCenter.default.publisher(for: .addFiles)) { _ in openFilePicker() }
        .onReceive(NotificationCenter.default.publisher(for: .removeSelectedFiles)) { _ in viewModel.removeSelectedFiles() }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.appState {
        case .empty:
            DropZoneView(onFilesDropped: { urls in
                viewModel.addFiles(dropVM.validateURLs(urls))
            })
        case .hasFiles:
            VStack(spacing: 0) {
                if !viewModel.isToolAvailable("ffmpeg") {
                    ToolInstallTip(
                        toolName: "ffmpeg", displayName: "FFmpeg",
                        description: "安装 FFmpeg 解锁视频转换",
                        installCommand: "brew install ffmpeg", homepage: "https://ffmpeg.org/"
                    )
                }
                FileListView(
                    files: viewModel.filteredFiles,
                    selectedFileIDs: $viewModel.selectedFileIDs,
                    selectedCategory: viewModel.selectedCategory,
                    availableTargets: { file in
                        viewModel.converter(for: file.detectedFormat.category)?
                            .supportedOutputFormats().filter { $0 != file.detectedFormat } ?? []
                    },
                    onTargetChange: { file, format in viewModel.setTargetFormat(format, for: file) },
                    onRemove: { file in viewModel.removeFile(file) },
                    onFilesDropped: { urls in viewModel.addFiles(dropVM.validateURLs(urls)) }
                )
            }
        case .converting:
            ConversionProgressView(progress: viewModel.overallProgress, files: viewModel.files,
                                    onCancel: { viewModel.cancelConversion() })
        case .complete:
            ResultsView(results: viewModel.results, successCount: viewModel.successCount,
                         failureCount: viewModel.failureCount,
                         onConvertMore: { viewModel.convertMore() },
                         onClearAll: { viewModel.clearAll() })
        }
    }

    private func openSettingsWindow() { SettingsWindowController.shared.show() }

    private func availableCategorySet() -> Set<FormatCategory> {
        var set = Set<FormatCategory>()
        for cat in FormatCategory.allCases {
            if ToolDetector.shared.isCategoryAvailable(cat) || cat == .all { set.insert(cat) }
        }
        return set
    }

    private func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = true; panel.message = "选择输出目录"
        if panel.runModal() == .OK, let url = panel.url { viewModel.updateOutputDirectory(url) }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK { viewModel.addFiles(panel.urls) }
    }
}

final class SettingsWindowController: @unchecked Sendable {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    private init() {}

    func show() {
        if let win = window, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingView(rootView: SettingsView())
        hosting.frame.size = hosting.fittingSize
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        win.title = "FileConverter 设置"
        win.contentView = hosting
        win.center()
        win.isReleasedWhenClosed = false
        window = win
        win.makeKeyAndOrderFront(nil)
    }
}
