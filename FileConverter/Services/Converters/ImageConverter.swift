import Foundation

/// 图片格式转换器 — 使用 sips（系统自带）和可选的 ImageMagick
final class ImageConverter: FormatConverter, @unchecked Sendable {
    let displayName = "图片转换器"
    let category = FormatCategory.images
    let requiredTools = ["sips"]
    let optionalTools = ["magick", "ffmpeg"]
    var supportsProgress: Bool { false }

    private weak var toolDetector: ToolProviding?

    init(toolDetector: ToolProviding) {
        self.toolDetector = toolDetector
    }

    /// sips 写起来比较稳的格式
    private static let sipsWritable: Set<ConversionFormat> = [
        .jpeg, .png, .gif, .bmp, .tiff, .heic, .jp2, .tga, .ico, .icns, .pdfImage
    ]

    /// 更适合交给 ImageMagick 的输出
    private static let magickPreferred: Set<ConversionFormat> = [
        .webp, .svg, .avif, .jxl, .psd, .exr, .dds
    ]

    func supportedInputFormats() -> [ConversionFormat] {
        var formats: [ConversionFormat] = [
            .jpeg, .png, .gif, .bmp, .tiff, .heic, .webp, .ico,
            .psd, .avif, .jp2, .jxl, .tga, .exr, .dds, .icns, .pdfImage,
            .cr2, .nef, .arw, .dng, .orf, .raf, .rw2, .pef
        ]
        if toolDetector?.isAvailable("magick") == true {
            formats.append(.svg)
        }
        return formats
    }

    func supportedOutputFormats() -> [ConversionFormat] {
        var formats: [ConversionFormat] = [
            .jpeg, .png, .gif, .bmp, .tiff, .heic, .jp2, .tga,
            .ico, .icns, .pdfImage
        ]
        if toolDetector?.isAvailable("magick") == true {
            formats.append(contentsOf: [.webp, .svg, .avif, .jxl, .psd, .exr, .dds])
        }
        return formats
    }

    func availableConversions() -> [(source: ConversionFormat, target: ConversionFormat)] {
        let inputs = supportedInputFormats()
        let outputs = supportedOutputFormats()
        var pairs: [(ConversionFormat, ConversionFormat)] = []

        for input in inputs {
            for output in outputs where input != output {
                if input.isRAW {
                    pairs.append((input, output))
                } else if canConvert(source: input, target: output) {
                    pairs.append((input, output))
                }
            }
        }
        return pairs
    }

    func canConvert(source: ConversionFormat, target: ConversionFormat) -> Bool {
        guard source.category == .images && target.category == .images else { return false }
        guard target != source else { return false }
        guard !target.isRAW else { return false }
        return supportedOutputFormats().contains(target)
    }

    func convert(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat,
        settings: ConversionSettings
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(targetFormat.preferredExtension)

        let preferMagick = Self.magickPreferred.contains(targetFormat)
            || sourceFormat == .svg
            || sourceFormat == .webp
            || sourceFormat == .jxl

        if preferMagick, toolDetector?.isAvailable("magick") == true {
            return try await convertWithMagick(input: input, output: outputURL, target: targetFormat, settings: settings)
        }

        // 默认走 sips；失败且有 ImageMagick 时再回退
        if Self.sipsWritable.contains(targetFormat) {
            do {
                return try await convertWithSips(input: input, output: outputURL, target: targetFormat, settings: settings)
            } catch {
                if toolDetector?.isAvailable("magick") == true {
                    return try await convertWithMagick(input: input, output: outputURL, target: targetFormat, settings: settings)
                }
                throw error
            }
        }

        if toolDetector?.isAvailable("magick") == true {
            return try await convertWithMagick(input: input, output: outputURL, target: targetFormat, settings: settings)
        }

        throw ProcessRunnerError.executionFailed(
            exitCode: -1,
            stderr: "无法输出 \(targetFormat.displayName)：请安装 ImageMagick（brew install imagemagick）"
        )
    }

    private func convertWithSips(
        input: URL,
        output: URL,
        target: ConversionFormat,
        settings: ConversionSettings
    ) async throws -> URL {
        let sipsPath = toolDetector?.path(for: "sips") ?? "/usr/bin/sips"
        let sipsFormat = mapToSipsFormat(target)

        var args = ["-s", "format", sipsFormat]

        if target == .jpeg || target == .heic {
            let quality = Int(settings.imageQuality * 100)
            args.append(contentsOf: ["-s", "formatOptions", "\(quality)"])
        }

        if let maxDim = settings.imageMaxDimension {
            args.append(contentsOf: ["-Z", "\(maxDim)"])
        }

        args.append(contentsOf: [input.path, "--out", output.path])
        _ = try await ProcessRunner.run(executable: sipsPath, arguments: args)
        try verifyNonEmpty(output)
        return output
    }

    private func convertWithMagick(
        input: URL,
        output: URL,
        target: ConversionFormat,
        settings: ConversionSettings
    ) async throws -> URL {
        guard let magickPath = toolDetector?.path(for: "magick") else {
            throw ProcessRunnerError.executableNotFound(name: "magick")
        }

        var args = [input.path]

        if let maxDim = settings.imageMaxDimension {
            args.append(contentsOf: ["-resize", "\(maxDim)x\(maxDim)>"])
        }

        if target == .jpeg || target == .webp || target == .avif || target == .heic {
            let quality = Int(settings.imageQuality * 100)
            args.append(contentsOf: ["-quality", "\(quality)"])
        }

        args.append(output.path)
        _ = try await ProcessRunner.run(executable: magickPath, arguments: args)
        try verifyNonEmpty(output)
        return output
    }

    private func verifyNonEmpty(_ url: URL) throws {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0 else {
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "图片转换完成但输出文件为空")
        }
    }

    // MARK: - 图片预览

    func canPreview(source: ConversionFormat, target: ConversionFormat) -> Bool { true }

    func preview(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat
    ) async throws -> Data? {
        let sipsPath = toolDetector?.path(for: "sips") ?? "/usr/bin/sips"
        let previewURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("preview-\(UUID().uuidString).jpg")

        let args = ["-Z", "256", input.path, "--out", previewURL.path]
        _ = try await ProcessRunner.run(executable: sipsPath, arguments: args)

        return try Data(contentsOf: previewURL)
    }

    // MARK: - 格式映射

    private func mapToSipsFormat(_ format: ConversionFormat) -> String {
        switch format {
        case .jpeg:     return "jpeg"
        case .png:      return "png"
        case .gif:      return "gif"
        case .bmp:      return "bmp"
        case .tiff:     return "tiff"
        case .heic:     return "heic"
        case .jp2:      return "jp2"
        case .tga:      return "tga"
        case .exr:      return "exr"
        case .dds:      return "dds"
        case .ico:      return "ico"
        case .icns:     return "icns"
        case .avif:     return "avif"
        case .pdfImage: return "pdf"
        case .psd:      return "psd"
        default:        return "jpeg"
        }
    }
}
