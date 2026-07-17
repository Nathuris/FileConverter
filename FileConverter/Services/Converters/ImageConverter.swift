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

    func supportedInputFormats() -> [ConversionFormat] {
        var formats: [ConversionFormat] = [
            .jpeg, .png, .gif, .bmp, .tiff, .heic, .webp, .ico, .svg,
            .psd, .avif, .jp2, .jxl, .tga, .exr, .dds, .icns, .pdfImage,
            .cr2, .nef, .arw, .dng, .orf, .raf, .rw2, .pef
        ]
        // ImageMagick 可以读更多格式
        if toolDetector?.isAvailable("magick") == true {
            formats.append(contentsOf: [.svg])  // 更好的 SVG 支持
        }
        return formats
    }

    func supportedOutputFormats() -> [ConversionFormat] {
        var formats: [ConversionFormat] = [
            .jpeg, .png, .gif, .bmp, .tiff, .heic, .jp2, .tga, .exr,
            .dds, .ico, .icns, .avif, .pdfImage
        ]
        // ImageMagick 可以写更多格式
        if toolDetector?.isAvailable("magick") == true {
            formats.append(contentsOf: [.webp, .svg])
        }
        return formats
    }

    func availableConversions() -> [(source: ConversionFormat, target: ConversionFormat)] {
        let inputs = supportedInputFormats()
        let outputs = supportedOutputFormats()
        var pairs: [(ConversionFormat, ConversionFormat)] = []

        for input in inputs {
            for output in outputs {
                if input != output && !input.isRAW && canConvert(source: input, target: output) {
                    pairs.append((input, output))
                }
            }
            // RAW 格式只能转换输出（sips 读但不写 RAW）
            if input.isRAW {
                for output in outputs {
                    pairs.append((input, output))
                }
            }
        }
        return pairs
    }

    func canConvert(source: ConversionFormat, target: ConversionFormat) -> Bool {
        guard source.category == .images && target.category == .images else { return false }
        guard target != source else { return false }
        // RAW 只能做源格式
        guard !target.isRAW else { return false }

        let outputs = supportedOutputFormats()
        return outputs.contains(target)
    }

    func convert(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat,
        settings: ConversionSettings
    ) async throws -> URL {
        let sipsPath = toolDetector?.path(for: "sips") ?? "/usr/bin/sips"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(targetFormat.preferredExtension)

        // sips 格式映射
        let sipsFormat = mapToSipsFormat(targetFormat)

        var args = ["-s", "format", sipsFormat]

        // 图片质量（jpeg 支持）
        if targetFormat == .jpeg || targetFormat == .heic {
            let quality = Int(settings.imageQuality * 100)
            args.append(contentsOf: ["-s", "formatOptions", "\(quality)"])
        }

        // 尺寸限制
        if let maxDim = settings.imageMaxDimension {
            args.append(contentsOf: ["-Z", "\(maxDim)"])
        }

        args.append(contentsOf: [input.path, "--out", outputURL.path])

        _ = try await ProcessRunner.run(executable: sipsPath, arguments: args)

        return outputURL
    }

    // MARK: - 图片预览

    func canPreview(source: ConversionFormat, target: ConversionFormat) -> Bool { true }

    func preview(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat
    ) async throws -> Data? {
        // 用 sips 生成小缩略图
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
