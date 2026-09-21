import Foundation

/// 音频转换器自身的错误（与共享的 ProcessRunnerError 区分开，
/// 这样翻译过的提示不会被「命令执行失败（退出码 N）：」前缀包一层）
private enum AudioConversionError: LocalizedError {
    case unsupportedFormat(String)
    case ffmpegRequired(ConversionFormat)
    case bothEnginesFailed(afconvert: String, ffmpeg: String)
    case emptyOutput

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let name):
            return "不支持的音频输出格式：\(name)"
        case .ffmpegRequired(let format):
            return "转换到 \(format.displayName) 需要 ffmpeg，请先安装：brew install ffmpeg"
        case .bothEnginesFailed(let afconvert, let ffmpeg):
            return "afconvert 与 ffmpeg 都无法处理该文件。\n系统音频引擎：\(afconvert)\nffmpeg：\(ffmpeg)"
        case .emptyOutput:
            return "转换命令执行成功，但没有生成输出文件"
        }
    }
}

/// 音频格式转换器 — 优先用 afconvert（系统自带），CoreAudio 读不了时回退到 ffmpeg
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

    /// 默认采样率；保持这个值时不做重采样
    private static let defaultSampleRate = 44100

    func supportedInputFormats() -> [ConversionFormat] {
        var formats: [ConversionFormat] = [.wav, .aiff, .caf, .mp3, .aac, .flac, .alac, .m4a]
        if toolDetector?.isAvailable("ffmpeg") == true {
            formats.append(contentsOf: [.ogg, .opus, .wma])
        }
        return formats
    }

    func supportedOutputFormats() -> [ConversionFormat] {
        var formats: [ConversionFormat] = [.aac, .alac, .aiff, .wav, .caf, .m4a, .flac]
        // MP3 编码需要 ffmpeg（afconvert 只支持 MP3 解码，不支持编码）
        if toolDetector?.isAvailable("ffmpeg") == true {
            formats.append(contentsOf: [.mp3, .ogg, .opus])
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

    // MARK: - 编码参数表

    /// 一个目标格式在两个引擎上各自的编码参数
    private struct Encoding {
        /// afconvert 的 `-d` 参数，nil 表示 CoreAudio 没有该格式的编码器
        let afconvertData: String?
        /// afconvert 的 `-f` 参数（容器）
        let afconvertFile: String?
        /// ffmpeg 的 `-c:a` 候选编码器，按顺序尝试，取第一个可用的
        let ffmpegCodecs: [(name: String, extra: [String])]
        /// ffmpeg 的 `-f` 参数。显式指定容器，避免扩展名（如 .alac）没有对应 muxer
        let ffmpegMuxer: String
        /// 有损编码才传比特率，PCM/无损传了只会刷警告
        let isLossy: Bool
    }

    /// 目标格式 → 编码参数。
    ///
    /// 刻意不留 `default` 兜底：新增格式若忘了配表会直接报错，而不是悄悄写出
    /// 扩展名与真实容器不符的文件。之前正是两处知识各管一摊 —— `afconvertFormats`
    /// 这个 Set 决定「谁来做」，`mapToAfconvertFormat` 这个 switch 决定「参数是啥」，
    /// 两者对不上时 `.mp3` 就落进了兜底分支，被写成 M4A 容器。
    private func encoding(for target: ConversionFormat) -> Encoding? {
        switch target {
        // AAC 裸流用 adts 容器。用 m4af 会写出一个扩展名是 .aac 的 M4A 文件，
        // CoreAudio 再打开时直接报 "Couldn't open input file ('sync')"。
        case .aac:
            return Encoding(afconvertData: "aac", afconvertFile: "adts",
                            ffmpegCodecs: [("aac", [])], ffmpegMuxer: "adts", isLossy: true)
        case .m4a:
            return Encoding(afconvertData: "aac", afconvertFile: "m4af",
                            ffmpegCodecs: [("aac", [])], ffmpegMuxer: "ipod", isLossy: true)
        case .alac:
            return Encoding(afconvertData: "alac", afconvertFile: "m4af",
                            ffmpegCodecs: [("alac", [])], ffmpegMuxer: "ipod", isLossy: false)
        case .flac:
            return Encoding(afconvertData: "flac", afconvertFile: "flac",
                            ffmpegCodecs: [("flac", [])], ffmpegMuxer: "flac", isLossy: false)
        case .wav:
            return Encoding(afconvertData: "LEI16", afconvertFile: "WAVE",
                            ffmpegCodecs: [("pcm_s16le", [])], ffmpegMuxer: "wav", isLossy: false)
        case .aiff:
            return Encoding(afconvertData: "BEI16", afconvertFile: "AIFF",
                            ffmpegCodecs: [("pcm_s16be", [])], ffmpegMuxer: "aiff", isLossy: false)
        case .caf:
            return Encoding(afconvertData: "LEI16", afconvertFile: "caff",
                            ffmpegCodecs: [("pcm_s16le", [])], ffmpegMuxer: "caf", isLossy: false)
        // CoreAudio 只有 MP3 解码器，没有编码器，必须走 ffmpeg
        case .mp3:
            return Encoding(afconvertData: nil, afconvertFile: nil,
                            ffmpegCodecs: [("libmp3lame", [])], ffmpegMuxer: "mp3", isLossy: true)
        // 部分 ffmpeg 构建没编进 libvorbis，退到实验性的内置 vorbis 编码器。
        // 内置编码器只支持立体声，单声道源必须显式补成 2 声道，否则它直接拒绝编码。
        case .ogg:
            return Encoding(afconvertData: nil, afconvertFile: nil,
                            ffmpegCodecs: [("libvorbis", []),
                                           ("vorbis", ["-strict", "-2", "-ac", "2"])],
                            ffmpegMuxer: "ogg", isLossy: true)
        case .opus:
            return Encoding(afconvertData: nil, afconvertFile: nil,
                            ffmpegCodecs: [("libopus", [])], ffmpegMuxer: "opus", isLossy: true)
        default:
            return nil
        }
    }

    // MARK: - 转换

    func convert(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat,
        settings: ConversionSettings
    ) async throws -> URL {
        guard let encoding = encoding(for: targetFormat) else {
            throw AudioConversionError.unsupportedFormat(targetFormat.displayName)
        }

        let afconvertPath = toolDetector?.path(for: "afconvert") ?? "/usr/bin/afconvert"

        if encoding.afconvertFile != nil {
            do {
                return try await convertWithAfconvert(
                    input: input, targetFormat: targetFormat, encoding: encoding,
                    settings: settings, afconvertPath: afconvertPath
                )
            } catch {
                let afconvertError = error

                // 取消或超时不重试，否则会给一个已经结束的任务再起一个进程
                guard shouldRetry(after: afconvertError) else { throw afconvertError }

                guard let ffmpegPath = ffmpegPath else {
                    throw ProcessRunnerError.executionFailed(
                        exitCode: exitCode(of: afconvertError),
                        stderr: friendlyExplanation(for: stderrText(of: afconvertError))
                    )
                }

                // CoreAudio 对容器很挑：扩展名和实际内容不符就直接拒绝打开。
                // ffmpeg 靠嗅探内容，宽容得多，回退一次通常能救回来
                // —— 包括早期版本自己写出的那些扩展名与容器不符的文件。
                do {
                    return try await convertWithFFmpeg(
                        input: input, targetFormat: targetFormat, encoding: encoding,
                        settings: settings, ffmpegPath: ffmpegPath
                    )
                } catch {
                    throw AudioConversionError.bothEnginesFailed(
                        afconvert: friendlyExplanation(for: stderrText(of: afconvertError)),
                        ffmpeg: stderrText(of: error)
                    )
                }
            }
        }

        guard let ffmpegPath = ffmpegPath else {
            throw AudioConversionError.ffmpegRequired(targetFormat)
        }
        return try await convertWithFFmpeg(
            input: input, targetFormat: targetFormat, encoding: encoding,
            settings: settings, ffmpegPath: ffmpegPath
        )
    }

    // MARK: - afconvert

    private func convertWithAfconvert(
        input: URL,
        targetFormat: ConversionFormat,
        encoding: Encoding,
        settings: ConversionSettings,
        afconvertPath: String
    ) async throws -> URL {
        guard let fileFormat = encoding.afconvertFile, let dataFormat = encoding.afconvertData else {
            throw AudioConversionError.unsupportedFormat(targetFormat.displayName)
        }

        let outputURL = temporaryOutputURL(for: targetFormat)
        var args = ["-d", dataFormatFor(dataFormat, settings: settings), "-f", fileFormat]

        if encoding.isLossy {
            args.append(contentsOf: ["-b", "\(settings.audioBitrate * 1000)"])
        }

        args.append(contentsOf: [input.path, "-o", outputURL.path])

        _ = try await ProcessRunner.run(executable: afconvertPath, arguments: args)
        try verifyOutput(at: outputURL)
        return outputURL
    }

    /// 把目标采样率拼进 afconvert 的 data format。
    ///
    /// 注意不能用 `-r`：那是 `--src-quality`（0–127 的采样率转换器质量），不是采样率，
    /// 传进去会被静默忽略（实测输出仍是 44100 Hz）。正确写法是 `LEI16@48000` / `aac@48000`。
    private func dataFormatFor(_ dataFormat: String, settings: ConversionSettings) -> String {
        guard settings.audioSampleRate != Self.defaultSampleRate else { return dataFormat }
        return "\(dataFormat)@\(settings.audioSampleRate)"
    }

    // MARK: - ffmpeg

    private func convertWithFFmpeg(
        input: URL,
        targetFormat: ConversionFormat,
        encoding: Encoding,
        settings: ConversionSettings,
        ffmpegPath: String
    ) async throws -> URL {
        // -nostdin / -nostats / -loglevel error 不只是降噪：ProcessRunner 只在进程结束时
        // 才读管道，ffmpeg 默认往 stderr 持续写进度，大文件会写满管道缓冲区把双方卡死。
        // -vn 用来丢弃封面图之类的内嵌视频流，否则 mp4 系容器会因无法映射而报错。
        var baseArgs = ["-hide_banner", "-loglevel", "error", "-nostdin", "-nostats",
                        "-i", input.path, "-vn"]

        if settings.audioSampleRate != Self.defaultSampleRate {
            baseArgs.append(contentsOf: ["-ar", "\(settings.audioSampleRate)"])
        }
        baseArgs.append(contentsOf: ["-f", encoding.ffmpegMuxer])

        // 候选编码器按顺序试，第一个能跑通的就用
        var lastError: Error = AudioConversionError.emptyOutput
        for codec in encoding.ffmpegCodecs {
            let outputURL = temporaryOutputURL(for: targetFormat)

            var args = baseArgs
            args.append(contentsOf: ["-c:a", codec.name])
            args.append(contentsOf: codec.extra)
            if encoding.isLossy {
                args.append(contentsOf: ["-b:a", "\(settings.audioBitrate)k"])
            }
            args.append(contentsOf: ["-y", outputURL.path])

            do {
                _ = try await ProcessRunner.run(executable: ffmpegPath, arguments: args)
                try verifyOutput(at: outputURL)
                return outputURL
            } catch {
                lastError = error
                try? FileManager.default.removeItem(at: outputURL)
            }
        }
        throw lastError
    }

    // MARK: - 辅助

    private func temporaryOutputURL(for targetFormat: ConversionFormat) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(targetFormat.preferredExtension)
    }

    private var ffmpegPath: String? {
        guard toolDetector?.isAvailable("ffmpeg") == true else { return nil }
        return toolDetector?.path(for: "ffmpeg")
    }

    /// 退出码为 0 不代表真的写出了文件，落盘后校验一次再报成功
    private func verifyOutput(at url: URL) throws {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0 else { throw AudioConversionError.emptyOutput }
    }

    private func shouldRetry(after error: Error) -> Bool {
        if Task.isCancelled { return false }
        if case ProcessRunnerError.cancelled = error { return false }
        if case ProcessRunnerError.timedOut = error { return false }
        return true
    }

    private func stderrText(of error: Error) -> String {
        if case ProcessRunnerError.executionFailed(_, let stderr) = error {
            let text = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }
        return error.localizedDescription
    }

    private func exitCode(of error: Error) -> Int32 {
        if case ProcessRunnerError.executionFailed(let code, _) = error { return code }
        return -1
    }

    /// 把 afconvert 抛出的 4 字符 CoreAudio 状态码翻成能看懂的中文提示
    private func friendlyExplanation(for stderr: String) -> String {
        let hints: [(code: String, hint: String)] = [
            ("'wht?'", "无法打开源文件，可能已损坏、还没下载完，或格式无法识别"),
            ("'dta?'", "文件内容与扩展名不符，扩展名很可能是错的"),
            ("'sync'", "文件不是真正的 AAC/MP3 数据流：扩展名和实际容器对不上（例如 .aac 里装的其实是 M4A 容器）"),
            ("'typ?'", "系统音频引擎不支持该源文件格式，安装 ffmpeg 可以解决"),
            ("'fmt?'", "该容器不支持目标编码格式"),
            ("'who?'", "编码器不接受当前参数，通常是比特率或声道数超出范围"),
            ("'chk?'", "文件结构损坏"),
            ("'pck?'", "文件索引损坏"),
            ("'prm?'", "没有权限读取源文件"),
            ("'off?'", "文件过大，超出该容器上限"),
        ]
        for entry in hints where stderr.contains(entry.code) {
            return "\(stderr)\n提示：\(entry.hint)"
        }
        return stderr
    }
}
