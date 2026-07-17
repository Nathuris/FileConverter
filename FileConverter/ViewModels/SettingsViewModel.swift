import Foundation
import Observation

/// 设置页面 ViewModel
@MainActor
@Observable
final class SettingsViewModel {
    var settings: AppSettings = .load()
    var tools: [ToolInfo] = []

    func load() {
        settings = AppSettings.load()
        refreshTools()
    }

    func save() {
        settings.save()
    }

    func refreshTools() {
        tools = ToolDetector.shared.allAvailableTools() + ToolDetector.shared.allMissingTools()
    }

    func rescanTools() async {
        await ToolDetector.shared.reScanAll()
        refreshTools()
    }
}
