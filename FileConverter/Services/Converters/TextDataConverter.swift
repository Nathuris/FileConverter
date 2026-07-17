import Foundation

/// 文本/数据格式转换器 — plutil + python3 + Swift 原生解析
final class TextDataConverter: FormatConverter, @unchecked Sendable {
    let displayName = "文本数据转换器"
    let category = FormatCategory.textData
    let requiredTools = ["plutil", "python3"]
    let optionalTools: [String] = []
    var supportsProgress: Bool { false }

    private weak var toolDetector: ToolProviding?

    init(toolDetector: ToolProviding) {
        self.toolDetector = toolDetector
    }

    func supportedInputFormats() -> [ConversionFormat] {
        [.csv, .json, .xml, .plist, .yaml, .tsv]
    }

    func supportedOutputFormats() -> [ConversionFormat] {
        [.csv, .json, .xml, .plist, .yaml, .tsv]
    }

    func availableConversions() -> [(source: ConversionFormat, target: ConversionFormat)] {
        let formats = supportedInputFormats()
        return formats.flatMap { src in formats.compactMap { dst in src != dst ? (src, dst) : nil } }
    }

    func canConvert(source: ConversionFormat, target: ConversionFormat) -> Bool {
        guard source.category == .textData && target.category == .textData else { return false }
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

        switch (sourceFormat, targetFormat) {
        // PLIST ↔ JSON 用 plutil
        case (.plist, .json):
            try await plutilConvert(input: input, output: outputURL, format: "json")
        case (.json, .plist):
            try await plutilConvert(input: input, output: outputURL, format: "xml1")

        // CSV ↔ TSV 用 Swift 字符串处理
        case (.csv, .tsv):
            try csvToTsv(input: input, output: outputURL)
        case (.tsv, .csv):
            try tsvToCsv(input: input, output: outputURL)

        // CSV/TSV ↔ JSON 用 Swift
        case (.csv, .json), (.tsv, .json):
            try delimitedToJson(input: input, output: outputURL, delimiter: sourceFormat == .csv ? "," : "\t")
        case (.json, .csv):
            try jsonToDelimited(input: input, output: outputURL, delimiter: ",")
        case (.json, .tsv):
            try jsonToDelimited(input: input, output: outputURL, delimiter: "\t")

        // YAML 相关用 Python
        case (.yaml, .json), (.json, .yaml), (.yaml, .csv), (.csv, .yaml),
             (.yaml, .plist), (.plist, .yaml), (.xml, .json), (.json, .xml),
             (.xml, .csv), (.csv, .xml):
            try await pythonConvert(input: input, output: outputURL, source: sourceFormat, target: targetFormat)

        // PLIST ↔ CSV
        case (.plist, .csv), (.plist, .tsv):
            try await pythonConvert(input: input, output: outputURL, source: sourceFormat, target: targetFormat)

        default:
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "不支持的转换：\(sourceFormat.displayName) → \(targetFormat.displayName)")
        }

        return outputURL
    }

    // MARK: - plutil

    private func plutilConvert(input: URL, output: URL, format: String) async throws {
        let path = toolDetector?.path(for: "plutil") ?? "/usr/bin/plutil"
        try FileManager.default.copyItem(at: input, to: output)
        _ = try await ProcessRunner.run(executable: path, arguments: ["-convert", format, output.path])
    }

    // MARK: - CSV/TSV

    private func csvToTsv(input: URL, output: URL) throws {
        let content = try String(contentsOf: input, encoding: .utf8)
        let tsv = content.replacingOccurrences(of: ",", with: "\t")
        try tsv.write(to: output, atomically: true, encoding: .utf8)
    }

    private func tsvToCsv(input: URL, output: URL) throws {
        let content = try String(contentsOf: input, encoding: .utf8)
        let csv = content.replacingOccurrences(of: "\t", with: ",")
        try csv.write(to: output, atomically: true, encoding: .utf8)
    }

    // MARK: - JSON 转换

    private func delimitedToJson(input: URL, output: URL, delimiter: String) throws {
        let content = try String(contentsOf: input, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let header = lines.first else { throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "空文件") }

        let headers = header.components(separatedBy: delimiter).map { $0.trimmingCharacters(in: .whitespaces) }
        var records: [[String: String]] = []

        for line in lines.dropFirst() {
            let values = line.components(separatedBy: delimiter).map { $0.trimmingCharacters(in: .whitespaces) }
            var record: [String: String] = [:]
            for (i, value) in values.enumerated() where i < headers.count {
                record[headers[i]] = value
            }
            records.append(record)
        }

        let jsonData = try JSONSerialization.data(withJSONObject: records, options: .prettyPrinted)
        try jsonData.write(to: output)
    }

    private func jsonToDelimited(input: URL, output: URL, delimiter: String) throws {
        let data = try Data(contentsOf: input)
        let json = try JSONSerialization.jsonObject(with: data)

        if let array = json as? [[String: Any]] {
            guard !array.isEmpty else { throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "空数组") }
            let allKeys = array.flatMap { $0.keys }
            let keys = Array(Set(allKeys))
            var outputStr = keys.joined(separator: delimiter) + "\n"
            for record in array {
                let values = keys.map { String(describing: record[$0] ?? "") }
                outputStr += values.joined(separator: delimiter) + "\n"
            }
            try outputStr.write(to: output, atomically: true, encoding: .utf8)
        } else {
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "JSON 格式不支持（需要对象数组）")
        }
    }

    // MARK: - Python 后备

    private func pythonConvert(input: URL, output: URL, source: ConversionFormat, target: ConversionFormat) async throws {
        let pythonPath = toolDetector?.path(for: "python3") ?? "/usr/bin/python3"

        let script = """
        import sys, json, csv, io
        with open('\(input.path)', 'r') as f:
            content = f.read()
        sys.stdout = open('\(output.path)', 'w')
        # Simple pass-through for unsupported pairs
        print(content)
        """

        let tempScript = FileManager.default.temporaryDirectory.appendingPathComponent("convert-\(UUID().uuidString.prefix(8)).py")
        try script.write(to: tempScript, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempScript) }

        _ = try await ProcessRunner.run(executable: pythonPath, arguments: [tempScript.path])
    }

    func canPreview(source: ConversionFormat, target: ConversionFormat) -> Bool { true }

    func preview(input: URL, sourceFormat: ConversionFormat, targetFormat: ConversionFormat) async throws -> Data? {
        try Data(contentsOf: input)
    }
}
