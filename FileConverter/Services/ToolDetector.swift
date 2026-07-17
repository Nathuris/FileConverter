import Foundation

/// 工具检测服务 — 启动时扫描所有已知命令行工具
final class ToolDetector: ToolProviding, @unchecked Sendable {
    static let shared = ToolDetector()

    private let knownTools: [ToolInfo]
    private var toolPaths: [String: String] = [:]
    private var toolVersions: [String: String] = [:]
    private var customPaths: [String: String] = [:]

    private init() {
        knownTools = [
            ToolInfo(name: "sips", displayName: "sips (系统图片处理)", path: "/usr/bin/sips", version: nil, isBuiltIn: true, installCommand: nil, homepage: nil, unlocksDescription: "图片格式互转：JPEG, PNG, HEIC, GIF, BMP, TIFF, WebP 等 80+ 格式"),
            ToolInfo(name: "textutil", displayName: "textutil (系统文档转换)", path: "/usr/bin/textutil", version: nil, isBuiltIn: true, installCommand: nil, homepage: nil, unlocksDescription: "文档格式互转：TXT, RTF, HTML, DOC, DOCX, ODT 等"),
            ToolInfo(name: "afconvert", displayName: "afconvert (系统音频转换)", path: "/usr/bin/afconvert", version: nil, isBuiltIn: true, installCommand: nil, homepage: nil, unlocksDescription: "音频格式互转：WAV, AAC, ALAC, AIFF, FLAC, CAF 等"),
            ToolInfo(name: "ditto", displayName: "ditto (系统归档工具)", path: "/usr/bin/ditto", version: nil, isBuiltIn: true, installCommand: nil, homepage: nil, unlocksDescription: "ZIP 归档压缩与解压"),
            ToolInfo(name: "tar", displayName: "tar (系统归档工具)", path: "/usr/bin/tar", version: nil, isBuiltIn: true, installCommand: nil, homepage: nil, unlocksDescription: "TAR, GZ, BZ2, XZ 归档格式"),
            ToolInfo(name: "plutil", displayName: "plutil (系统属性列表工具)", path: "/usr/bin/plutil", version: nil, isBuiltIn: true, installCommand: nil, homepage: nil, unlocksDescription: "PLIST 与 JSON 互转"),
            ToolInfo(name: "python3", displayName: "Python 3 (系统自带)", path: "/usr/bin/python3", version: nil, isBuiltIn: true, installCommand: nil, homepage: "https://www.python.org/", unlocksDescription: "YAML、字体等转换"),
            ToolInfo(name: "ffmpeg", displayName: "FFmpeg", path: "", version: nil, isBuiltIn: false, installCommand: "brew install ffmpeg", homepage: "https://ffmpeg.org/", unlocksDescription: "视频全格式转换，高级音频和 WebP 支持"),
            ToolInfo(name: "pandoc", displayName: "Pandoc", path: "", version: nil, isBuiltIn: false, installCommand: "brew install pandoc", homepage: "https://pandoc.org/", unlocksDescription: "Markdown, LaTeX, EPUB 及 20+ 文本格式互转"),
            ToolInfo(name: "magick", displayName: "ImageMagick", path: "", version: nil, isBuiltIn: false, installCommand: "brew install imagemagick", homepage: "https://imagemagick.org/", unlocksDescription: "增强图片转换：SVG 读写, WebP/JXL 写入"),
            ToolInfo(name: "libreoffice", displayName: "LibreOffice", path: "", version: nil, isBuiltIn: false, installCommand: "brew install --cask libreoffice", homepage: "https://www.libreoffice.org/", unlocksDescription: "高质量 DOCX/XLSX/PPTX/PDF 转换"),
            ToolInfo(name: "ebook-convert", displayName: "Calibre (ebook-convert)", path: "", version: nil, isBuiltIn: false, installCommand: "brew install --cask calibre", homepage: "https://calibre-ebook.com/", unlocksDescription: "MOBI, AZW3, FB2 电子书格式互转"),
            ToolInfo(name: "7z", displayName: "p7zip", path: "", version: nil, isBuiltIn: false, installCommand: "brew install p7zip", homepage: "https://www.7-zip.org/", unlocksDescription: "7Z 创建和 RAR 提取"),
            ToolInfo(name: "fonttools", displayName: "fonttools (Python)", path: "", version: nil, isBuiltIn: false, installCommand: "pip3 install fonttools brotli", homepage: "https://github.com/fonttools/fonttools", unlocksDescription: "字体格式互转：TTF, OTF, WOFF, WOFF2"),
            ToolInfo(name: "assimp", displayName: "Assimp (3D)", path: "", version: nil, isBuiltIn: false, installCommand: "brew install assimp", homepage: "https://www.assimp.org/", unlocksDescription: "3D 模型互转：STL, OBJ, FBX 等 30+ 格式"),
        ]
    }

    // MARK: - 同步扫描（启动时调用）

    func scanAllSync() {
        let settings = AppSettings.load()
        customPaths = settings.customToolPaths

        for tool in knownTools {
            if let execPath = findToolSync(tool.name) {
                toolPaths[tool.name] = execPath
                let flag = tool.name == "python3" ? "--version" : "--version"
                toolVersions[tool.name] = ProcessRunner.getToolVersion(execPath, versionFlag: flag)
            }
        }
    }

    // MARK: - 异步扫描

    func scanAll() async { scanAllSync() }

    func rescanTool(_ name: String) async -> ToolInfo? {
        if let execPath = findToolSync(name) {
            toolPaths[name] = execPath
            toolVersions[name] = ProcessRunner.getToolVersion(execPath)
        }
        return getToolInfo(name)
    }

    func reScanAll() async {
        toolPaths.removeAll()
        toolVersions.removeAll()
        customPaths = AppSettings.load().customToolPaths
        scanAllSync()
    }

    // MARK: - 工具查找

    private func findToolSync(_ name: String) -> String? {
        // 1. 自定义路径
        if let cp = customPaths[name], FileManager.default.isExecutableFile(atPath: cp) {
            return cp
        }
        // 2. 系统内置路径
        if let known = knownTools.first(where: { $0.name == name }),
           known.isBuiltIn, FileManager.default.isExecutableFile(atPath: known.path) {
            return known.path
        }
        // 3. which 命令查找
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        p.arguments = [name]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            if p.terminationStatus == 0 {
                let d = pipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !path.isEmpty { return path }
            }
        } catch {}

        // 4. 检查常见 Homebrew 路径（which 在 GUI 应用中找不到 PATH 中的工具）
        let brewPaths = ["/opt/homebrew/bin", "/usr/local/bin"]
        for brew in brewPaths {
            let full = "\(brew)/\(name)"
            if FileManager.default.isExecutableFile(atPath: full) {
                return full
            }
        }

        return nil
    }

    func getToolInfo(_ name: String) -> ToolInfo? {
        knownTools.first(where: { $0.name == name })
    }

    // MARK: - ToolProviding

    func isAvailable(_ toolName: String) -> Bool {
        if let p = toolPaths[toolName] { return !p.isEmpty && FileManager.default.isExecutableFile(atPath: p) }
        return false
    }

    func path(for toolName: String) -> String? { toolPaths[toolName] }

    func version(for toolName: String) -> String? { toolVersions[toolName] }

    func allAvailableTools() -> [ToolInfo] {
        knownTools.compactMap { t in
            guard isAvailable(t.name) else { return nil }
            var r = t
            r.path = toolPaths[t.name] ?? ""
            r.version = toolVersions[t.name]
            return r
        }
    }

    func allMissingTools() -> [ToolInfo] {
        knownTools.filter { t in !isAvailable(t.name) && !t.isBuiltIn }
    }

    func availableToolNames() -> Set<String> {
        Set(toolPaths.keys.filter { isAvailable($0) })
    }

    func isCategoryAvailable(_ category: FormatCategory) -> Bool {
        category.isAvailable(given: availableToolNames())
    }
}
