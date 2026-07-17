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

        let pythonPath = toolDetector?.path(for: "python3") ?? "/usr/bin/python3"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(targetFormat.preferredExtension)

        // 使用 fonttools 的 ttx 命令：先导出 XML，调整格式，再导入
        // 简化版：直接用 pyftsubset 或 ttx
        let script = """
        import sys
        from fontTools.ttLib import TTFont
        font = TTFont('\(input.path)')
        font.flavor = \(targetFormat == .woff2 ? "'woff2'" : targetFormat == .woff ? "'woff'" : "None")
        font.save('\(outputURL.path)')
        """

        let tempScript = FileManager.default.temporaryDirectory.appendingPathComponent("fontconv-\(UUID().uuidString.prefix(8)).py")
        try script.write(to: tempScript, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempScript) }

        _ = try await ProcessRunner.run(executable: pythonPath, arguments: [tempScript.path])
        return outputURL
    }
}
