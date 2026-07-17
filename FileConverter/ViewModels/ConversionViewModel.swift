import Foundation
import AppKit
import Observation
import UniformTypeIdentifiers

/// App 的整体状态
enum AppState {
    case empty       // 初始空态，显示拖放区
    case hasFiles    // 有文件等待转换
    case converting  // 正在转换中
    case complete    // 转换完成，显示结果
}

/// 核心 ViewModel — 管理整个转换流程的状态和逻辑
@MainActor
@Observable
final class ConversionViewModel {

    // MARK: - 发布的状态

    var files: [ConversionFile] = []
    var selectedCategory: FormatCategory = .all
    var appState: AppState = .empty
    var overallProgress: Double = 0.0
    var results: [ConversionResult] = []
    var outputDirectory: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
    var selectedFileIDs: Set<UUID> = []

    /// 每个文件当前转换进度（文件 ID → 0.0~1.0）
    var fileProgressMap: [UUID: Double] = [:]

    // MARK: - 依赖

    private let toolDetector: ToolDetector
    private let formatDetector: FormatDetector
    private let pipeline: ConversionPipeline

    private var converters: [FormatCategory: any FormatConverter] = [:]

    // MARK: - 计算属性

    var filteredFiles: [ConversionFile] {
        guard selectedCategory != .all else { return files }
        return files.filter { $0.detectedFormat.category == selectedCategory }
    }

    var canConvert: Bool {
        guard appState == .hasFiles else { return false }
        return !files.isEmpty && files.allSatisfy { file in
            guard let converter = converters[file.detectedFormat.category] else { return false }
            return converter.canConvert(source: file.detectedFormat, target: file.targetFormat)
        }
    }

    var fileCountByCategory: [FormatCategory: Int] {
        Dictionary(grouping: files, by: { $0.detectedFormat.category })
            .mapValues { $0.count }
    }

    var successCount: Int {
        results.filter(\.success).count
    }

    var failureCount: Int {
        results.filter { !$0.success }.count
    }

    // MARK: - 初始化

    init(toolDetector: ToolDetector = .shared) {
        self.toolDetector = toolDetector
        self.formatDetector = FormatDetector()
        self.pipeline = ConversionPipeline()
    }

    /// 设置转换器（在 App 启动后调用）
    func setupConverters() {
        // 图片转换器总是可以用（sips 是系统自带的）
        converters[.images] = ImageConverter(toolDetector: toolDetector)
        converters[.documents] = DocumentConverter(toolDetector: toolDetector)
        converters[.audio] = AudioConverter(toolDetector: toolDetector)
        converters[.video] = VideoConverter(toolDetector: toolDetector)
        converters[.archives] = ArchiveConverter(toolDetector: toolDetector)
        converters[.textData] = TextDataConverter(toolDetector: toolDetector)
        converters[.ebooks] = EbookConverter(toolDetector: toolDetector)
        converters[.fonts] = FontConverter(toolDetector: toolDetector)
        converters[.cad3D] = CADConverter(toolDetector: toolDetector)
    }

    // MARK: - 文件管理

    /// 添加文件到转换队列
    func addFiles(_ urls: [URL]) {
        for url in urls {
            guard let format = formatDetector.detectFormat(of: url) else {
                print("无法识别文件格式：\(url.lastPathComponent)")
                continue
            }

            // 获取文件大小
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0

            // 智能推荐目标格式
            let suggestedTarget = suggestTargetFormat(for: format)

            var file = ConversionFile(
                sourceURL: url,
                detectedFormat: format,
                targetFormat: suggestedTarget,
                fileSize: fileSize
            )

            // 生成缩略图（在后台）
            Task {
                file.thumbnail = await generateThumbnail(for: url)
            }

            files.append(file)
        }

        if !files.isEmpty {
            appState = .hasFiles
        }
    }

    /// 移除单个文件
    func removeFile(_ file: ConversionFile) {
        files.removeAll { $0.id == file.id }
        if files.isEmpty {
            appState = .empty
        }
    }

    /// 移除选中文件
    func removeSelectedFiles() {
        files.removeAll { selectedFileIDs.contains($0.id) }
        selectedFileIDs.removeAll()
        if files.isEmpty {
            appState = .empty
        }
    }

    /// 清空所有文件
    func clearAll() {
        files.removeAll()
        results.removeAll()
        selectedFileIDs.removeAll()
        fileProgressMap.removeAll()
        overallProgress = 0.0
        appState = .empty
    }

    /// 设置目标格式
    func setTargetFormat(_ format: ConversionFormat, for file: ConversionFile) {
        guard let index = files.firstIndex(where: { $0.id == file.id }) else { return }
        var updated = files[index]
        updated.targetFormat = format
        files[index] = updated  // 替换整个元素确保 @Observable 追踪到变化
    }

    /// 批量设置所有文件的统一目标格式
    func setBatchTargetFormat(_ format: ConversionFormat) {
        for i in files.indices {
            if files[i].detectedFormat.category == format.category {
                var updated = files[i]
                updated.targetFormat = format
                files[i] = updated
            }
        }
    }

    // MARK: - 转换流程

    /// 开始转换
    func startConversion() {
        guard canConvert else { return }

        appState = .converting
        overallProgress = 0.0
        results.removeAll()
        fileProgressMap.removeAll()

        let settings = AppSettings.load().defaultConversionSettings
        let maxConcurrency = AppSettings.load().maxConcurrentConversions

        Task {
            let pipelineResults = await pipeline.convert(
                files: files,
                converters: converters,
                settings: settings,
                outputDirectory: outputDirectory,
                maxConcurrency: maxConcurrency,
                onFileComplete: { [weak self] result in
                    Task { @MainActor in
                        self?.results.append(result)
                    }
                },
                onOverallProgress: { [weak self] progress in
                    Task { @MainActor in
                        self?.overallProgress = progress
                    }
                }
            )

            await MainActor.run {
                self.results = pipelineResults
                self.appState = .complete
                self.overallProgress = 1.0

                // 如果有文件转换失败，标记状态
                for i in self.files.indices {
                    if let result = self.results.first(where: { $0.sourceFile.id == self.files[i].id }) {
                        if !result.success {
                            self.files[i].status = .failed(result.errorMessage ?? "未知错误")
                        } else {
                            self.files[i].status = .completed
                        }
                    }
                }

                // 转换完成通知
                if AppSettings.load().showNotificationOnCompletion {
                    self.showCompletionNotification()
                }

                // 在 Finder 中显示
                if AppSettings.load().revealInFinderAfterConversion,
                   let firstResult = self.results.first(where: { $0.success }) {
                    NSWorkspace.shared.activateFileViewerSelecting([firstResult.outputURL])
                }
            }
        }
    }

    /// 取消转换
    func cancelConversion() {
        Task {
            await pipeline.cancelAll()
            await MainActor.run {
                appState = .hasFiles
                overallProgress = 0.0
            }
        }
    }

    /// 转换完成后，返回文件列表重新转换
    func convertMore() {
        results.removeAll()
        fileProgressMap.removeAll()
        overallProgress = 0.0

        // 重置文件状态
        for i in files.indices {
            files[i].status = .pending
        }

        appState = .hasFiles
    }

    // MARK: - 工具查询

    /// 检查某个工具是否可用
    func isToolAvailable(_ name: String) -> Bool {
        toolDetector.isAvailable(name)
    }

    /// 获取某个类别的转换器
    func converter(for category: FormatCategory) -> (any FormatConverter)? {
        converters[category]
    }

    /// 获取某个类别所有可用的输出格式
    func availableTargetFormats(for category: FormatCategory) -> [ConversionFormat] {
        converters[category]?.supportedOutputFormats() ?? []
    }

    /// 获取某个类别所有可用的输入格式
    func availableSourceFormats(for category: FormatCategory) -> [ConversionFormat] {
        converters[category]?.supportedInputFormats() ?? []
    }

    // MARK: - 智能推荐

    /// 根据源格式推荐最佳目标格式
    private func suggestTargetFormat(for sourceFormat: ConversionFormat) -> ConversionFormat {
        switch sourceFormat {
        // 图片
        case .heic, .avif, .jxl, .jp2, .tiff, .psd, .tga, .exr, .dds:
            return .png
        case .png, .webp, .bmp, .ico, .icns, .svg:
            return .jpeg
        case .gif:
            return .png
        // RAW
        case .cr2, .nef, .arw, .dng, .orf, .raf, .rw2, .pef:
            return .jpeg
        // 文档
        case .docx, .doc, .rtf, .rtfd, .odt, .pages, .html, .markdown:
            return .pdfDoc
        case .txt:
            return .pdfDoc
        case .pdfDoc:
            return .docx
        // 音频
        case .wav, .aiff, .flac, .caf:
            return .aac
        case .mp3, .ogg, .opus, .wma:
            return .m4a
        case .aac, .m4a:
            return .mp3
        case .alac:
            return .aac
        // 视频
        case .mov, .avi, .mkv, .webm, .flv, .wmv, .m4v:
            return .mp4
        case .mp4:
            return .mov
        case .gifVideo:
            return .mp4
        // 归档
        case .tar, .gz, .bz2, .xz, .sevenZ, .rar, .cpio:
            return .zip
        case .zip:
            return .tar
        case .dmg:
            return .zip
        // 文本数据
        case .csv, .tsv, .xml, .plist, .yaml:
            return .json
        case .json:
            return .csv
        // 电子书
        case .epub, .mobi, .azw3, .fb2:
            return .pdfDoc
        // 字体
        case .otf, .woff, .woff2:
            return .ttf
        case .ttf:
            return .otf
        // 3D
        case .obj, .fbx:
            return .usdz
        case .usdz:
            return .obj
        case .stl:
            return .obj
        // 兜底
        default:
            return .pdfDoc
        }
    }

    // MARK: - 缩略图

    private func generateThumbnail(for url: URL) async -> NSImage? {
        // 对于图片，直接加载并缩放
        if let image = NSImage(contentsOf: url) {
            let size = image.size
            let maxDim: CGFloat = 96
            if size.width > maxDim || size.height > maxDim {
                let ratio = min(maxDim / size.width, maxDim / size.height)
                let newSize = NSSize(width: size.width * ratio, height: size.height * ratio)
                let resized = NSImage(size: newSize)
                resized.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1.0)
                resized.unlockFocus()
                return resized
            }
            return image
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    // MARK: - 通知

    private func showCompletionNotification() {
        // 使用系统声音提示（简单方式）
        NSSound.beep()
    }

    // MARK: - 设置

    func updateOutputDirectory(_ url: URL) {
        outputDirectory = url
    }
}
