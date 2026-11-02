import Foundation

/// 归档格式转换器 — 使用 ditto/tar（系统自带）+ 可选 p7zip
final class ArchiveConverter: FormatConverter, @unchecked Sendable {
    let displayName = "归档转换器"
    let category = FormatCategory.archives
    let requiredTools = ["ditto", "tar"]
    let optionalTools = ["7z"]
    var supportsProgress: Bool { false }

    private weak var toolDetector: ToolProviding?

    init(toolDetector: ToolProviding) {
        self.toolDetector = toolDetector
    }

    func supportedInputFormats() -> [ConversionFormat] {
        var formats: [ConversionFormat] = [.zip, .tar, .gz, .bz2, .xz, .cpio]
        if toolDetector?.isAvailable("7z") == true {
            formats.append(contentsOf: [.sevenZ, .rar, .dmg])
        } else {
            // 没装 7z 时 dmg 仍可尝试用 hdiutil 挂载，但跨格式重打包不稳定，先不宣称
            formats.append(.dmg)
        }
        return formats
    }

    func supportedOutputFormats() -> [ConversionFormat] {
        var formats: [ConversionFormat] = [.zip, .tar, .gz, .bz2, .xz, .cpio]
        if toolDetector?.isAvailable("7z") == true {
            formats.append(.sevenZ)
        }
        return formats
    }

    func availableConversions() -> [(source: ConversionFormat, target: ConversionFormat)] {
        let inputs = supportedInputFormats()
        let outputs = supportedOutputFormats()
        return inputs.flatMap { src in outputs.compactMap { dst in src != dst ? (src, dst) : nil } }
    }

    func canConvert(source: ConversionFormat, target: ConversionFormat) -> Bool {
        guard source.category == .archives && target.category == .archives else { return false }
        guard source != target else { return false }
        return supportedOutputFormats().contains(target)
            && supportedInputFormats().contains(source)
    }

    func convert(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat,
        settings: ConversionSettings
    ) async throws -> URL {
        // 归档转换策略：先解压到临时目录，再重新打包
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-extract-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 步骤 1：解压
        try await extract(input: input, format: sourceFormat, to: tempDir)

        // 步骤 2：重新打包
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(targetFormat.preferredExtension)

        try await archive(source: tempDir, format: targetFormat, to: outputURL)

        let size = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0 else {
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "打包完成但输出文件为空")
        }

        return outputURL
    }

    private func extract(input: URL, format: ConversionFormat, to dir: URL) async throws {
        let dittoPath = toolDetector?.path(for: "ditto") ?? "/usr/bin/ditto"

        switch format {
        case .zip:
            _ = try await ProcessRunner.run(executable: dittoPath, arguments: ["-x", "-k", input.path, dir.path])
        case .tar:
            _ = try await ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-xf", input.path, "-C", dir.path])
        case .gz:
            _ = try await ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-xzf", input.path, "-C", dir.path])
        case .bz2:
            _ = try await ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-xjf", input.path, "-C", dir.path])
        case .xz:
            _ = try await ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-xJf", input.path, "-C", dir.path])
        case .cpio:
            // 通过 shell 把文件内容喂给 cpio，避免同步阻塞当前 actor
            let cmd = "cd '\(dir.path)' && /usr/bin/cpio -idm < '\(input.path)'"
            _ = try await ProcessRunner.run(executable: "/bin/sh", arguments: ["-c", cmd])
        case .sevenZ, .rar:
            try await extractWith7z(input: input, to: dir)
        case .dmg:
            try await extractDMG(input: input, to: dir)
        default:
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "不支持的源格式: \(format.displayName)")
        }
    }

    private func extractWith7z(input: URL, to dir: URL) async throws {
        guard let sevenZ = toolDetector?.path(for: "7z") else {
            throw ProcessRunnerError.executableNotFound(name: "7z")
        }
        _ = try await ProcessRunner.run(
            executable: sevenZ,
            arguments: ["x", input.path, "-o\(dir.path)", "-y"]
        )
    }

    /// DMG：挂载后拷贝内容。需要 7z 时也可用 7z 直接解。
    private func extractDMG(input: URL, to dir: URL) async throws {
        if let sevenZ = toolDetector?.path(for: "7z"), toolDetector?.isAvailable("7z") == true {
            _ = try await ProcessRunner.run(
                executable: sevenZ,
                arguments: ["x", input.path, "-o\(dir.path)", "-y"]
            )
            return
        }

        // hdiutil attach → 拷贝 → detach
        let mountRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("dmg-mount-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: mountRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mountRoot) }

        let attach = try await ProcessRunner.run(
            executable: "/usr/bin/hdiutil",
            arguments: ["attach", input.path, "-mountroot", mountRoot.path, "-nobrowse", "-readonly"]
        )

        // 挂载点通常是 mountRoot 下的子目录
        let contents = try FileManager.default.contentsOfDirectory(
            at: mountRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        guard let volume = contents.first else {
            _ = try? await ProcessRunner.run(executable: "/usr/bin/hdiutil", arguments: ["detach", mountRoot.path, "-force"])
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "无法挂载 DMG：\(attach.stderr)")
        }

        let dittoPath = toolDetector?.path(for: "ditto") ?? "/usr/bin/ditto"
        do {
            _ = try await ProcessRunner.run(executable: dittoPath, arguments: [volume.path, dir.path])
        } catch {
            _ = try? await ProcessRunner.run(executable: "/usr/bin/hdiutil", arguments: ["detach", volume.path, "-force"])
            throw error
        }
        _ = try await ProcessRunner.run(executable: "/usr/bin/hdiutil", arguments: ["detach", volume.path, "-force"])
    }

    private func archive(source dir: URL, format: ConversionFormat, to output: URL) async throws {
        let dittoPath = toolDetector?.path(for: "ditto") ?? "/usr/bin/ditto"

        switch format {
        case .zip:
            _ = try await ProcessRunner.run(executable: dittoPath, arguments: ["-c", "-k", "--keepParent", dir.path, output.path])
        case .tar:
            _ = try await ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-cf", output.path, "-C", dir.path, "."])
        case .gz:
            _ = try await ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-czf", output.path, "-C", dir.path, "."])
        case .bz2:
            _ = try await ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-cjf", output.path, "-C", dir.path, "."])
        case .xz:
            _ = try await ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-cJf", output.path, "-C", dir.path, "."])
        case .cpio:
            // 先创建空文件，FileHandle(forWritingTo:) 要求文件已存在
            FileManager.default.createFile(atPath: output.path, contents: nil)
            let cmd = "cd '\(dir.path)' && /usr/bin/find . -print0 | /usr/bin/cpio -o -H newc > '\(output.path)'"
            _ = try await ProcessRunner.run(executable: "/bin/sh", arguments: ["-c", cmd])
        case .sevenZ:
            guard let sevenZ = toolDetector?.path(for: "7z") else {
                throw ProcessRunnerError.executableNotFound(name: "7z")
            }
            _ = try await ProcessRunner.run(
                executable: sevenZ,
                arguments: ["a", "-t7z", output.path, "\(dir.path)/."]
            )
        default:
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "不支持的输出格式: \(format.displayName)")
        }
    }
}
