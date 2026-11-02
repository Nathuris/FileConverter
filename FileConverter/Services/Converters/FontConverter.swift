import Foundation

/// 字体格式转换器 — python3 + fonttools
final class FontConverter: FormatConverter, @unchecked Sendable {
    let displayName = "字体转换器"
    let category = FormatCategory.fonts
    let requiredTools = ["python3"]
    let optionalTools = ["fonttools"]
    var supportsProgress: Bool { false }

    private weak var toolDetector: ToolProviding?

    init(toolDetector: ToolProviding) {
        self.toolDetector = toolDetector
    }

    func supportedInputFormats() -> [ConversionFormat] {
        guard toolDetector?.isAvailable("fonttools") == true else { return [] }
        return [.ttf, .otf, .woff, .woff2]
    }

    func supportedOutputFormats() -> [ConversionFormat] {
        guard toolDetector?.isAvailable("fonttools") == true else { return [] }
        return [.ttf, .otf, .woff, .woff2]
    }

    func availableConversions() -> [(source: ConversionFormat, target: ConversionFormat)] {
        let formats = supportedInputFormats()
        return formats.flatMap { src in formats.compactMap { dst in src != dst ? (src, dst) : nil } }
    }

    func canConvert(source: ConversionFormat, target: ConversionFormat) -> Bool {
        guard toolDetector?.isAvailable("fonttools") == true else { return false }
        guard source.category == .fonts && target.category == .fonts else { return false }
        return source != target && supportedOutputFormats().contains(target)
    }

    func convert(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat,
        settings: ConversionSettings
    ) async throws -> URL {
        guard toolDetector?.isAvailable("fonttools") == true else {
            throw ProcessRunnerError.executableNotFound(name: "fonttools")
        }

        // fonttools 探测成功时，path(for:) 存的是可用的 python3
        let pythonPath = toolDetector?.path(for: "fonttools")
            ?? toolDetector?.path(for: "python3")
            ?? "/usr/bin/python3"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(targetFormat.preferredExtension)

        let flavor: String
        switch targetFormat {
        case .woff2: flavor = "'woff2'"
        case .woff:  flavor = "'woff'"
        default:     flavor = "None"
        }

        // 用环境变量传路径，避免路径里的引号弄坏脚本
        let script = """
        import os
        from fontTools.ttLib import TTFont
        font = TTFont(os.environ['FC_INPUT'])
        font.flavor = \(flavor)
        font.save(os.environ['FC_OUTPUT'])
        """

        let tempScript = FileManager.default.temporaryDirectory
            .appendingPathComponent("fontconv-\(UUID().uuidString.prefix(8)).py")
        try script.write(to: tempScript, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempScript) }

        var env = ProcessInfo.processInfo.environment
        env["FC_INPUT"] = input.path
        env["FC_OUTPUT"] = outputURL.path

        _ = try await ProcessRunner.run(
            executable: pythonPath,
            arguments: [tempScript.path],
            environment: env
        )

        let size = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0 else {
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "字体转换完成但输出文件为空")
        }
        return outputURL
    }
}
