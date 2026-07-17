import Foundation

/// 视频格式转换器 — 需要 ffmpeg
final class VideoConverter: FormatConverter, @unchecked Sendable {
    let displayName = "视频转换器"
    let category = FormatCategory.video
    let requiredTools = ["ffmpeg"]
    let optionalTools: [String] = []
    var supportsProgress: Bool { true }

    private weak var toolDetector: ToolProviding?

    init(toolDetector: ToolProviding) {
        self.toolDetector = toolDetector
    }

    func supportedInputFormats() -> [ConversionFormat] {
        guard toolDetector?.isAvailable("ffmpeg") == true else { return [] }
        return [.mp4, .mov, .avi, .mkv, .webm, .flv, .wmv, .m4v, .gifVideo]
    }

    func supportedOutputFormats() -> [ConversionFormat] {
        guard toolDetector?.isAvailable("ffmpeg") == true else { return [] }
        return [.mp4, .mov, .mkv, .webm, .m4v, .gifVideo, .avi]
    }

    func availableConversions() -> [(source: ConversionFormat, target: ConversionFormat)] {
        let inputs = supportedInputFormats()
        let outputs = supportedOutputFormats()
        return inputs.flatMap { src in outputs.compactMap { dst in src != dst ? (src, dst) : nil } }
    }

    func canConvert(source: ConversionFormat, target: ConversionFormat) -> Bool {
        guard toolDetector?.isAvailable("ffmpeg") == true else { return false }
        guard source.category == .video && target.category == .video else { return false }
        guard source != target else { return false }
        return supportedOutputFormats().contains(target)
    }

    func convert(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat,
        settings: ConversionSettings
    ) async throws -> URL {
        guard toolDetector?.isAvailable("ffmpeg") == true else {
            throw ProcessRunnerError.executableNotFound(name: "ffmpeg")
        }

        let ffmpegPath = toolDetector?.path(for: "ffmpeg") ?? "ffmpeg"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(targetFormat.preferredExtension)

        var args = ["-i", input.path]

        // 视频编码
        if targetFormat == .gifVideo {
            args.append(contentsOf: ["-vf", "fps=10,scale=480:-1", "-loop", "0"])
        } else {
            args.append(contentsOf: ["-c:v", "libx264", "-b:v", "\(settings.videoBitrate)k"])
            args.append(contentsOf: ["-c:a", "aac", "-b:a", "192k"])

            // 分辨率
            if let scale = settings.videoResolution.ffmpegScale {
                args.append(contentsOf: ["-vf", "scale=\(scale):force_original_aspect_ratio=decrease"])
            }
        }

        // 保留元数据
        if settings.preserveMetadata {
            args.append(contentsOf: ["-map_metadata", "0"])
        }

        args.append(contentsOf: ["-y", outputURL.path])

        _ = try await ProcessRunner.run(executable: ffmpegPath, arguments: args)

        return outputURL
    }

    func convert(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat,
        settings: ConversionSettings,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        // 带进度的视频转换
        guard toolDetector?.isAvailable("ffmpeg") == true else {
            throw ProcessRunnerError.executableNotFound(name: "ffmpeg")
        }

        let ffmpegPath = toolDetector?.path(for: "ffmpeg") ?? "ffmpeg"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(targetFormat.preferredExtension)

        let args = ["-i", input.path, "-c:v", "libx264", "-b:v", "\(settings.videoBitrate)k",
                    "-c:a", "aac", "-b:a", "192k", "-progress", "pipe:1", "-nostats", "-y", outputURL.path]

        _ = try await ProcessRunner.runWithProgress(
            executable: ffmpegPath,
            arguments: args,
            progressParser: { line in
                // ffmpeg 进度格式: "out_time_us=12345678"
                if line.hasPrefix("out_time_us=") {
                    let us = Int64(line.dropFirst("out_time_us=".count)) ?? 0
                    // 这里需要总时长来算百分比，简化处理
                    return min(Double(us) / 1_000_000.0 / 60.0, 1.0) // 假设最大 1 分钟
                }
                return nil
            }
        )

        return outputURL
    }
}
