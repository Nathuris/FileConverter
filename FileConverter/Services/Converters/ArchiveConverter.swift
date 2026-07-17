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
        var formats: [ConversionFormat] = [.zip, .tar, .gz, .bz2, .xz, .cpio, .dmg]
        if toolDetector?.isAvailable("7z") == true {
            formats.append(contentsOf: [.sevenZ, .rar])
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

        return outputURL
    }

    private func extract(input: URL, format: ConversionFormat, to dir: URL) async throws {
        let dittoPath = toolDetector?.path(for: "ditto") ?? "/usr/bin/ditto"

        switch format {
        case .zip, .dmg:
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
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/cpio")
            task.arguments = ["-idm"]
            task.currentDirectoryURL = dir
            task.standardInput = try FileHandle(forReadingFrom: input)
            try task.run()
            task.waitUntilExit()
        default:
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "不支持的源格式: \(format.displayName)")
        }
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
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
            process.arguments = [dir.path, "-print0"]
            let pipe = Pipe()
            process.standardOutput = pipe
            try process.run()

            let process2 = Process()
            process2.executableURL = URL(fileURLWithPath: "/usr/bin/cpio")
            process2.arguments = ["-o", "-H", "newc"]
            process2.currentDirectoryURL = dir
            let outHandle = try FileHandle(forWritingTo: output)
            process2.standardOutput = outHandle
            process2.standardInput = pipe
            try process2.run()
            process.waitUntilExit()
            process2.waitUntilExit()
            try outHandle.close()
        default:
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "不支持的输出格式: \(format.displayName)")
        }
    }
}
