import Foundation

/// 文档格式转换器 — 使用 textutil（系统自带）+ 可选 pandoc/LibreOffice
final class DocumentConverter: FormatConverter, @unchecked Sendable {
    let displayName = "文档转换器"
    let category = FormatCategory.documents
    let requiredTools = ["textutil"]
    let optionalTools = ["pandoc", "libreoffice"]
    var supportsProgress: Bool { false }

    private weak var toolDetector: ToolProviding?

    init(toolDetector: ToolProviding) {
        self.toolDetector = toolDetector
    }

    func supportedInputFormats() -> [ConversionFormat] {
        var formats: [ConversionFormat] = [.txt, .rtf, .rtfd, .html, .docx, .odt, .pdfDoc]
        if toolDetector?.isAvailable("pandoc") == true {
            formats.append(contentsOf: [.markdown, .epub])
        }
        return formats
    }

    func supportedOutputFormats() -> [ConversionFormat] {
        // PDF 始终可用（通过 cupsfilter 或 textutil 间接生成）
        var formats: [ConversionFormat] = [.txt, .rtf, .rtfd, .html, .docx, .odt, .pdfDoc]
        if toolDetector?.isAvailable("pandoc") == true {
            formats.append(contentsOf: [.markdown, .epub])
        }
        return formats
    }

    func availableConversions() -> [(source: ConversionFormat, target: ConversionFormat)] {
        let inputs = supportedInputFormats()
        let outputs = supportedOutputFormats()
        var pairs: [(ConversionFormat, ConversionFormat)] = []
        for input in inputs {
            for output in outputs where input != output {
                pairs.append((input, output))
            }
        }
        return pairs
    }

    func canConvert(source: ConversionFormat, target: ConversionFormat) -> Bool {
        guard source.category == .documents && target.category == .documents else { return false }
        guard source != target else { return false }
        let outputs = supportedOutputFormats()
        return outputs.contains(target)
    }

    func convert(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat,
        settings: ConversionSettings
    ) async throws -> URL {
        let textutilPath = toolDetector?.path(for: "textutil") ?? "/usr/bin/textutil"

        // PDF 输出：优先用 cupsfilter（系统自带），其次 pandoc
        if targetFormat == .pdfDoc {
            return try await convertToPDF(input: input, source: sourceFormat)
        }

        // PDF 输入 → 其他格式：先转成 txt 再用 textutil
        if sourceFormat == .pdfDoc {
            // PDF 做输入且目标是 textutil 格式 → 需要 pandoc
            if toolDetector?.isAvailable("pandoc") == true {
                return try await convertWithPandoc(input: input, source: sourceFormat, target: targetFormat)
            }
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "PDF 转换需要 pandoc，安装命令：brew install pandoc")
        }

        // textutil 能处理的格式
        let textutilFormats: Set<ConversionFormat> = [.txt, .rtf, .rtfd, .html, .docx, .odt]

        if textutilFormats.contains(sourceFormat) && textutilFormats.contains(targetFormat) {
            return try await convertWithTextutil(input: input, target: targetFormat, textutilPath: textutilPath)
        }

        // pandoc 兜底
        if toolDetector?.isAvailable("pandoc") == true {
            return try await convertWithPandoc(input: input, source: sourceFormat, target: targetFormat)
        }

        throw ProcessRunnerError.executionFailed(
            exitCode: -1,
            stderr: "无法转换 \(sourceFormat.displayName) → \(targetFormat.displayName)，需要安装 pandoc"
        )
    }

    /// 用 cupsfilter 生成 PDF（系统自带，无需额外安装）
    private func convertToPDF(input: URL, source: ConversionFormat) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        let mimeType: String = {
            switch source {
            case .html: return "text/html"
            case .rtf, .rtfd: return "text/rtf"
            default: return "text/plain"
            }
        }()

        // cupsfilter 输出 binary PDF 到 stdout → 用 sh -c 重定向到文件
        let cupsPath = "/usr/sbin/cupsfilter"
        if FileManager.default.isExecutableFile(atPath: cupsPath) {
            let cmd = "'\(cupsPath)' -m application/pdf '\(input.path)' > '\(outputURL.path)'"
            _ = try await ProcessRunner.run(executable: "/bin/sh", arguments: ["-c", cmd])

            // 验证输出
            guard FileManager.default.fileExists(atPath: outputURL.path) else {
                throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "PDF 生成失败：输出文件不存在")
            }
            let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
            let fileSize = (attrs?[.size] as? Int64) ?? 0
            guard fileSize > 0 else {
                throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "PDF 生成失败：输出为空")
            }
            return outputURL
        }

        throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "无法生成 PDF：cupsfilter 不可用")
    }

    private func convertWithTextutil(input: URL, target: ConversionFormat, textutilPath: String) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(target.preferredExtension)

        let textutilFormat = mapToTextutilFormat(target)
        var args = ["-convert", textutilFormat, "-output", outputURL.path, input.path]

        _ = try await ProcessRunner.run(executable: textutilPath, arguments: args)

        return outputURL
    }

    private func convertWithPandoc(input: URL, source: ConversionFormat, target: ConversionFormat) async throws -> URL {
        let pandocPath = toolDetector?.path(for: "pandoc") ?? "pandoc"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(target.preferredExtension)

        let pandocTarget = mapToPandocFormat(target)
        let args = [input.path, "-f", "auto", "-t", pandocTarget, "-o", outputURL.path]

        _ = try await ProcessRunner.run(executable: pandocPath, arguments: args)

        return outputURL
    }

    func canPreview(source: ConversionFormat, target: ConversionFormat) -> Bool {
        [.txt, .markdown, .html].contains(target)
    }

    func preview(input: URL, sourceFormat: ConversionFormat, targetFormat: ConversionFormat) async throws -> Data? {
        let outputURL = try await convert(input: input, sourceFormat: sourceFormat, targetFormat: targetFormat, settings: .default)
        return try Data(contentsOf: outputURL)
    }

    private func mapToTextutilFormat(_ format: ConversionFormat) -> String {
        switch format {
        case .txt:  return "txt"
        case .rtf:  return "rtf"
        case .rtfd: return "rtfd"
        case .html: return "html"
        case .doc:  return "doc"
        case .docx: return "docx"
        case .odt:  return "odt"
        default:    return "txt"
        }
    }

    private func mapToPandocFormat(_ format: ConversionFormat) -> String {
        switch format {
        case .markdown: return "markdown"
        case .html:     return "html"
        case .pdfDoc:   return "pdf"
        case .docx:     return "docx"
        case .epub:     return "epub"
        case .txt:      return "plain"
        default:        return "markdown"
        }
    }
}
