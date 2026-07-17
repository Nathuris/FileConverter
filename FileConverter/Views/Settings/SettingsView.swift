import SwiftUI

// MARK: - 设置标签页

private enum SettingsTab: String, CaseIterable {
    case general = "通用"
    case tools = "工具"
    case format = "格式"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .tools:   return "wrench.adjustable"
        case .format:  return "doc.richtext"
        }
    }
}

// MARK: - 设置窗口

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标签导航
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .font(.body)
                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedTab == tab
                                ? Color.primary.opacity(0.08)
                                : Color.clear
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if tab != SettingsTab.allCases.last {
                        Divider()
                            .frame(height: 20)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Divider()
                .padding(.top, 8)

            // 内容区
            Group {
                switch selectedTab {
                case .general: GeneralSettingsView()
                case .tools:   ToolSettingsView()
                case .format:  FormatSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 620, height: 480)
    }
}

// MARK: - 通用设置

struct GeneralSettingsView: View {
    @State private var settings = AppSettings.load()

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("最大并行转换数：")
                    Text("\(settings.maxConcurrentConversions)")
                        .frame(minWidth: 20, alignment: .leading)
                    Stepper("", value: $settings.maxConcurrentConversions, in: 1...16)
                        .labelsHidden()
                }
                Toggle("转换完成后显示通知", isOn: $settings.showNotificationOnCompletion)
                Toggle("完成后在 Finder 中显示文件", isOn: $settings.revealInFinderAfterConversion)
            }
            Section("默认转换设置") {
                Toggle("保留元数据（EXIF等）", isOn: $settings.defaultConversionSettings.preserveMetadata)
                Toggle("覆盖已存在的文件", isOn: $settings.defaultConversionSettings.overwriteExisting)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.maxConcurrentConversions) { _, _ in save() }
        .onChange(of: settings.showNotificationOnCompletion) { _, _ in save() }
        .onChange(of: settings.revealInFinderAfterConversion) { _, _ in save() }
    }

    private func save() { settings.save() }
}

// MARK: - 工具设置

struct ToolSettingsView: View {
    @State private var tools: [ToolInfo] = []
    @State private var installingTool: ToolInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("转换工具状态")
                    .font(.headline)
                Spacer()
                Button {
                    Task {
                        await ToolDetector.shared.reScanAll()
                        refreshTools()
                    }
                } label: {
                    Label("重新扫描", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(tools) { tool in
                        ToolRow(tool: tool, onInstall: { installingTool = tool })
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { refreshTools() }
        .sheet(item: $installingTool) { tool in
            InstallSheet(
                displayName: tool.displayName,
                installCommand: tool.installCommand ?? "",
                homepage: tool.homepage,
                onInstalled: {
                    Task {
                        _ = await ToolDetector.shared.rescanTool(tool.name)
                        refreshTools()
                    }
                }
            )
        }
    }

    private func refreshTools() {
        tools = ToolDetector.shared.allAvailableTools() + ToolDetector.shared.allMissingTools()
    }
}

struct ToolRow: View {
    let tool: ToolInfo
    let onInstall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tool.status == .available ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(tool.displayName)
                    .font(.body).fontWeight(.medium)
                if let ver = tool.version {
                    Text(ver).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
                Spacer()
                if tool.status != .available, tool.installCommand != nil {
                    Button(action: onInstall) {
                        Label("安装", systemImage: "arrow.down.circle").font(.caption)
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                } else if tool.status == .available {
                    Text("已安装").font(.caption).foregroundStyle(.green)
                }
            }
            Text(tool.unlocksDescription)
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 16)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 格式设置

enum ImageMaxDimension: Int, CaseIterable {
    case unlimited = 0
    case px3200 = 3200
    case px2560 = 2560
    case px1920 = 1920
    case px1280 = 1280
    case px800  = 800

    var label: String {
        switch self {
        case .unlimited: return "不限制"
        default: return "\(rawValue)px"
        }
    }
}

struct FormatSettingsView: View {
    @State private var settings = AppSettings.load()

    private var currentDimension: ImageMaxDimension {
        guard let d = settings.defaultConversionSettings.imageMaxDimension else { return .unlimited }
        return ImageMaxDimension(rawValue: d) ?? .unlimited
    }

    var body: some View {
        Form {
            Section("图片") {
                HStack {
                    Text("JPEG 质量：")
                    Slider(value: $settings.defaultConversionSettings.imageQuality, in: 0.1...1.0, step: 0.05)
                    Text("\(Int(settings.defaultConversionSettings.imageQuality * 100))%")
                        .frame(width: 40)
                }
                Picker("最大尺寸：", selection: .init(
                    get: { currentDimension },
                    set: { settings.defaultConversionSettings.imageMaxDimension = $0 == .unlimited ? nil : $0.rawValue }
                )) {
                    ForEach(ImageMaxDimension.allCases, id: \.self) { dim in
                        Text(dim.label).tag(dim)
                    }
                }
            }
            Section("音频") {
                HStack {
                    Text("比特率：")
                    Picker("", selection: $settings.defaultConversionSettings.audioBitrate) {
                        Text("128 kbps").tag(128)
                        Text("192 kbps").tag(192)
                        Text("256 kbps").tag(256)
                        Text("320 kbps").tag(320)
                    }
                }
            }
            Section("视频") {
                Picker("分辨率：", selection: $settings.defaultConversionSettings.videoResolution) {
                    ForEach(ConversionSettings.VideoResolution.allCases, id: \.self) { res in
                        Text(res.rawValue).tag(res)
                    }
                }
                HStack {
                    Text("比特率：")
                    Picker("", selection: $settings.defaultConversionSettings.videoBitrate) {
                        Text("2000 kbps").tag(2000)
                        Text("5000 kbps").tag(5000)
                        Text("8000 kbps").tag(8000)
                        Text("12000 kbps").tag(12000)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.defaultConversionSettings.imageQuality) { _, _ in save() }
        .onChange(of: settings.defaultConversionSettings.imageMaxDimension) { _, _ in save() }
    }

    private func save() { settings.save() }
}
