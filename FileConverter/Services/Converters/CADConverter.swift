import Foundation
import ModelIO

/// 3D 模型格式转换器 — Model I/O（系统自带）+ 可选 assimp
final class CADConverter: FormatConverter, @unchecked Sendable {
    let displayName = "3D 模型转换器"
    let category = FormatCategory.cad3D
    let requiredTools: [String] = []
    let optionalTools = ["assimp"]
    var supportsProgress: Bool { false }

    private weak var toolDetector: ToolProviding?

    init(toolDetector: ToolProviding) {
        self.toolDetector = toolDetector
    }

    func supportedInputFormats() -> [ConversionFormat] {
        var formats: [ConversionFormat] = [.obj, .stl, .usdz]
        if toolDetector?.isAvailable("assimp") == true {
            formats.append(.fbx)
        }
        return formats
    }

    func supportedOutputFormats() -> [ConversionFormat] {
        var formats: [ConversionFormat] = [.obj, .stl, .usdz]
        if toolDetector?.isAvailable("assimp") == true {
            formats.append(.fbx)
        }
        return formats
    }

    func availableConversions() -> [(source: ConversionFormat, target: ConversionFormat)] {
        let formats = supportedInputFormats()
        return formats.flatMap { src in formats.compactMap { dst in src != dst ? (src, dst) : nil } }
    }

    func canConvert(source: ConversionFormat, target: ConversionFormat) -> Bool {
        guard source.category == .cad3D && target.category == .cad3D else { return false }
        return source != target && supportedOutputFormats().contains(target)
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

        // Model I/O 能直接处理 OBJ / STL / USDZ
        let modelIOFormats: Set<ConversionFormat> = [.obj, .stl, .usdz]
        if modelIOFormats.contains(sourceFormat) && modelIOFormats.contains(targetFormat) {
            return try await convertWithModelIO(input: input, output: outputURL)
        }

        // FBX 等格式交给 assimp
        if toolDetector?.isAvailable("assimp") == true {
            let assimpPath = toolDetector?.path(for: "assimp") ?? "assimp"
            _ = try await ProcessRunner.run(
                executable: assimpPath,
                arguments: ["export", input.path, outputURL.path]
            )
            try verifyNonEmpty(outputURL)
            return outputURL
        }

        throw ProcessRunnerError.executionFailed(
            exitCode: -1,
            stderr: "需要安装 assimp 来转换该 3D 格式。安装命令：brew install assimp"
        )
    }

    private func convertWithModelIO(input: URL, output: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let asset = MDLAsset(url: input)
            do {
                try asset.export(to: output)
            } catch {
                throw ProcessRunnerError.executionFailed(
                    exitCode: -1,
                    stderr: "3D 模型导出失败：\(error.localizedDescription)"
                )
            }

            let size = (try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard size > 0 else {
                throw ProcessRunnerError.executionFailed(
                    exitCode: -1,
                    stderr: "3D 模型导出失败：输出文件为空。源文件可能损坏，或格式不受系统支持"
                )
            }
            return output
        }.value
    }

    private func verifyNonEmpty(_ url: URL) throws {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0 else {
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "转换完成但输出文件为空")
        }
    }
}
