import SwiftUI

/// FileConverter App 入口
@main
struct FileConverterApp: App {
    @State private var viewModel: ConversionViewModel

    init() {
        ToolDetector.shared.scanAllSync()
        // 必须先建好 ViewModel、挂上转换器，再交给 @State。
        // 若在 @State 已经包好之后再 setup，SwiftUI 可能丢弃这次修改，
        // 结果是转换器字典一直是空的：按钮灰掉、格式菜单点了没内容。
        let vm = ConversionViewModel()
        vm.setupConverters()
        _viewModel = State(initialValue: vm)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .onAppear {
                    // 双保险：窗口出现时若转换器丢失则重新挂上
                    viewModel.ensureConvertersReady()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("添加文件…") {
                    NotificationCenter.default.post(name: .addFiles, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandMenu("转换") {
                Button("开始转换") {
                    NotificationCenter.default.post(name: .startConversion, object: nil)
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
        }

        // ⌘+, 打开独立设置窗口
        Settings {
            SettingsView()
        }
    }
}

extension Notification.Name {
    static let startConversion = Notification.Name("startConversion")
    static let removeSelectedFiles = Notification.Name("removeSelectedFiles")
    static let clearAllFiles = Notification.Name("clearAllFiles")
    static let addFiles = Notification.Name("addFiles")
    static let openSettings = Notification.Name("openSettings")
}
