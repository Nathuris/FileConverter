import Foundation

/// 电子书格式转换器 — pandoc + 可选 Calibre
final class EbookConverter: FormatConverter, @unchecked Sendable {
    let displayName = "电子书转换器"
    let category = FormatCategory.ebooks
    let requiredTools = ["pandoc"]
    let optionalTools = ["ebook-convert"]
    var supportsProgress: Bool { false }

    private weak var toolDetector: ToolProviding?

    init(toolDetector: ToolProviding) {
        self.toolDetector = toolDetector
    }

    func supportedInputFormats() -> [ConversionFormat] {
        guard toolDetector?.isAvailable("pandoc") == true else { return [] }
        var formats: [ConversionFormat] = [.epub, .txt, .html, .markdown, .docx]
        if toolDetector?.isAvailable("ebook-convert") == true {
            formats.append(contentsOf: [.mobi, .azw3, .fb2])
        }
        return formats
    }

    func supportedOutputFormats() -> [ConversionFormat] {
        guard toolDetector?.isAvailable("pandoc") == true else { return [] }
        var formats: [ConversionFormat] = [.epub, .pdfDoc, .txt, .html, .markdown, .docx]
        if toolDetector?.isAvailable("ebook-convert") == true {
            formats.append(contentsOf: [.mobi, .azw3, .fb2])
        }
        return formats
    }

    func availableConversions() -> [(source: ConversionFormat, target: ConversionFormat)] {
        let inputs = supportedInputFormats()
        let outputs = supportedOutputFormats()
        return inputs.flatMap { src in outputs.compactMap { dst in src != dst ? (src, dst) : nil } }
    }

    func canConvert(source: ConversionFormat, target: ConversionFormat) -> Bool {
        guard source.category == .ebooks || source == .txt || source == .html || source == .markdown || source == .docx else { return false }
        guard target != source else { return false }
        return supportedOutputFormats().contains(target)
    }

    func convert(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat,
        settings: ConversionSettings
    ) async throws -> URL {
        let useCalibre = toolDetector?.isAvailable("ebook-convert") == true &&
            [ConversionFormat.mobi, .azw3, .fb2].contains(sourceFormat) || [ConversionFormat.mobi, .azw3, .fb2].contains(targetFormat)

        if useCalibre {
            return try await convertWithCalibre(input: input, target: targetFormat)
        } else {
            return try await convertWithPandoc(input: input, target: targetFormat)
        }
    }

    private func convertWithPandoc(input: URL, target: ConversionFormat) async throws -> URL {
        let pandocPath = toolDetector?.path(for: "pandoc") ?? "pandoc"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(target.preferredExtension)

        let pandocTarget = mapToPandocFormat(target)
        _ = try await ProcessRunner.run(
            executable: pandocPath,
            arguments: [input.path, "-f", "auto", "-t", pandocTarget, "-o", outputURL.path]
        )
        return outputURL
    }

    private func convertWithCalibre(input: URL, target: ConversionFormat) async throws -> URL {
        let calibrePath = toolDetector?.path(for: "ebook-convert") ?? "ebook-convert"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(target.preferredExtension)

        _ = try await ProcessRunner.run(
            executable: calibrePath,
            arguments: [input.path, outputURL.path]
        )
        return outputURL
    }

    private func mapToPandocFormat(_ format: ConversionFormat) -> String {
        switch format {
        case .epub: return "epub"
        case .pdfDoc: return "pdf"
        case .txt: return "plain"
        case .html: return "html"
        case .markdown: return "markdown"
        case .docx: return "docx"
        default: return "epub"
        }
    }
}
