import SwiftUI

/// FileConverter App 入口
@main
struct FileConverterApp: App {
    @State private var viewModel = ConversionViewModel()

    init() {
        ToolDetector.shared.scanAllSync()
        viewModel.setupConverters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
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
