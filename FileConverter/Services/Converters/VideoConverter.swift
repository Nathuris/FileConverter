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
        try await convert(
            input: input,
            sourceFormat: sourceFormat,
            targetFormat: targetFormat,
            settings: settings,
            progressHandler: { _ in }
        )
    }

    func convert(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat,
        settings: ConversionSettings,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        guard toolDetector?.isAvailable("ffmpeg") == true else {
            throw ProcessRunnerError.executableNotFound(name: "ffmpeg")
        }

        let ffmpegPath = toolDetector?.path(for: "ffmpeg") ?? "ffmpeg"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(targetFormat.preferredExtension)

        // 先探一下总时长，用来算真实进度；失败就只显示不确定进度
        let durationSeconds = await probeDuration(ffmpegPath: ffmpegPath, input: input)

        // -nostdin / -nostats / -loglevel error：避免进度刷屏把管道写满卡死
        // （音频转换器里已踩过这个坑）
        var args = [
            "-hide_banner", "-loglevel", "error", "-nostdin", "-nostats",
            "-i", input.path
        ]

        if targetFormat == .gifVideo {
            args.append(contentsOf: ["-vf", "fps=10,scale=480:-1:flags=lanczos", "-loop", "0"])
        } else {
            args.append(contentsOf: ["-c:v", "libx264", "-b:v", "\(settings.videoBitrate)k"])
            args.append(contentsOf: ["-c:a", "aac", "-b:a", "192k"])

            if let scale = settings.videoResolution.ffmpegScale {
                args.append(contentsOf: ["-vf", "scale=\(scale):force_original_aspect_ratio=decrease"])
            }
        }

        if settings.preserveMetadata {
            args.append(contentsOf: ["-map_metadata", "0"])
        }

        // 进度写到 stdout，ProcessRunner 边读边解析
        args.append(contentsOf: ["-progress", "pipe:1", "-y", outputURL.path])

        _ = try await ProcessRunner.runWithProgress(
            executable: ffmpegPath,
            arguments: args,
            progressParser: { line in
                guard line.hasPrefix("out_time_us="), let total = durationSeconds, total > 0 else {
                    return nil
                }
                let us = Double(line.dropFirst("out_time_us=".count)) ?? 0
                return min(max(us / 1_000_000.0 / total, 0), 1)
            },
            onProgress: progressHandler,
            timeout: 7200
        )

        let size = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0 else {
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "视频转换完成但输出文件为空")
        }

        return outputURL
    }

    /// 用 ffprobe 风格参数问 ffmpeg 总时长（秒）
    private func probeDuration(ffmpegPath: String, input: URL) async -> Double? {
        // ffmpeg -i 会把信息打到 stderr 并以非 0 退出，属正常
        do {
            _ = try await ProcessRunner.run(
                executable: ffmpegPath,
                arguments: ["-hide_banner", "-i", input.path],
                timeout: 30
            )
            return nil
        } catch let ProcessRunnerError.executionFailed(_, stderr) {
            // Duration: 00:01:23.45
            guard let range = stderr.range(of: #"Duration:\s*(\d+):(\d+):(\d+\.\d+)"#, options: .regularExpression) else {
                return nil
            }
            let token = String(stderr[range])
            let parts = token
                .replacingOccurrences(of: "Duration:", with: "")
                .trimmingCharacters(in: .whitespaces)
                .split(separator: ":")
            guard parts.count == 3,
                  let h = Double(parts[0]),
                  let m = Double(parts[1]),
                  let s = Double(parts[2]) else { return nil }
            return h * 3600 + m * 60 + s
        } catch {
            return nil
        }
    }
}
