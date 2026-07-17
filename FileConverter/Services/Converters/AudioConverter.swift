import Foundation

/// 音频格式转换器 — 使用 afconvert（系统自带）+ 可选 ffmpeg
final class AudioConverter: FormatConverter, @unchecked Sendable {
    let displayName = "音频转换器"
    let category = FormatCategory.audio
    let requiredTools = ["afconvert"]
    let optionalTools = ["ffmpeg"]
    var supportsProgress: Bool { false }

    private weak var toolDetector: ToolProviding?

    init(toolDetector: ToolProviding) {
        self.toolDetector = toolDetector
    }

    func supportedInputFormats() -> [ConversionFormat] {
        var formats: [ConversionFormat] = [.wav, .aiff, .caf, .mp3, .aac, .flac, .alac, .m4a]
        if toolDetector?.isAvailable("ffmpeg") == true {
            formats.append(contentsOf: [.ogg, .opus, .wma])
        }
        return formats
    }

    func supportedOutputFormats() -> [ConversionFormat] {
        // MP3 / FLAC 在 macOS 新版本中 afconvert 已支持编码
        var formats: [ConversionFormat] = [.aac, .alac, .aiff, .wav, .caf, .m4a, .mp3, .flac]
        if toolDetector?.isAvailable("ffmpeg") == true {
            formats.append(contentsOf: [.ogg, .opus])
        }
        return formats
    }

    func availableConversions() -> [(source: ConversionFormat, target: ConversionFormat)] {
        let inputs = supportedInputFormats()
        let outputs = supportedOutputFormats()
        return inputs.flatMap { src in outputs.compactMap { dst in src != dst ? (src, dst) : nil } }
    }

    func canConvert(source: ConversionFormat, target: ConversionFormat) -> Bool {
        guard source.category == .audio && target.category == .audio else { return false }
        guard source != target else { return false }
        return supportedOutputFormats().contains(target)
    }

    func convert(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat,
        settings: ConversionSettings
    ) async throws -> URL {
        // 使用 afconvert 处理常见格式，ffmpeg 处理复杂格式
        let afconvertFormats: Set<ConversionFormat> = [.wav, .aiff, .caf, .mp3, .aac, .flac, .alac, .m4a]

        if afconvertFormats.contains(targetFormat) {
            return try await convertWithAfconvert(input: input, target: targetFormat, settings: settings)
        } else if toolDetector?.isAvailable("ffmpeg") == true {
            return try await convertWithFFmpeg(input: input, target: targetFormat, settings: settings)
        }

        throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "需要 ffmpeg 来转换到 \(targetFormat.displayName)")
    }

    private func convertWithAfconvert(input: URL, target: ConversionFormat, settings: ConversionSettings) async throws -> URL {
        let afconvertPath = toolDetector?.path(for: "afconvert") ?? "/usr/bin/afconvert"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(target.preferredExtension)

        let (dataFmt, fileFmt) = mapToAfconvertFormat(target)
        var args = ["-d", dataFmt, "-f", fileFmt]

        if target == .aac || target == .m4a {
            args.append(contentsOf: ["-b", "\(settings.audioBitrate * 1000)"])
        }
        if settings.audioSampleRate != 44100 {
            args.append(contentsOf: ["-r", "\(settings.audioSampleRate)"])
        }

        args.append(contentsOf: [input.path, "-o", outputURL.path])

        _ = try await ProcessRunner.run(executable: afconvertPath, arguments: args)
        return outputURL
    }

    private func convertWithFFmpeg(input: URL, target: ConversionFormat, settings: ConversionSettings) async throws -> URL {
        let ffmpegPath = toolDetector?.path(for: "ffmpeg") ?? "ffmpeg"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(target.preferredExtension)

        let codec = mapToFFmpegAudioCodec(target)
        let args = ["-i", input.path, "-c:a", codec, "-b:a", "\(settings.audioBitrate)k", "-y", outputURL.path]

        _ = try await ProcessRunner.run(executable: ffmpegPath, arguments: args)
        return outputURL
    }

    private func mapToAfconvertFormat(_ format: ConversionFormat) -> (dataFormat: String, fileFormat: String) {
        switch format {
        case .aac:  return ("aac", "m4af")
        case .alac: return ("alac", "m4af")
        case .aiff: return ("BEI16", "AIFF")
        case .wav:  return ("LEI16", "WAVE")
        case .caf:  return ("LEI16", "caff")
        case .m4a:  return ("aac", "m4af")
        case .flac: return ("flac", "flac")
        case .mp3:  return ("mp3", "mp3")
        default:    return ("aac", "m4af")
        }
    }

    private func mapToFFmpegAudioCodec(_ format: ConversionFormat) -> String {
        switch format {
        case .mp3:  return "libmp3lame"
        case .flac: return "flac"
        case .ogg:  return "libvorbis"
        case .opus: return "libopus"
        default:    return "aac"
        }
    }
}
