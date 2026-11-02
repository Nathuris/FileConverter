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

        // CSV ↔ TSV：按单元格拆，不能整文件替换逗号/制表符
        case (.csv, .tsv):
            try rewriteDelimited(input: input, output: outputURL, from: ",", to: "\t")
        case (.tsv, .csv):
            try rewriteDelimited(input: input, output: outputURL, from: "\t", to: ",")

        // CSV/TSV ↔ JSON 用 Swift
        case (.csv, .json), (.tsv, .json):
            try delimitedToJson(input: input, output: outputURL, delimiter: sourceFormat == .csv ? "," : "\t")
        case (.json, .csv):
            try jsonToDelimited(input: input, output: outputURL, delimiter: ",")
        case (.json, .tsv):
            try jsonToDelimited(input: input, output: outputURL, delimiter: "\t")

        // 其余组合走 Python（含 YAML / XML / PLIST 交叉）
        default:
            try await pythonConvert(input: input, output: outputURL, source: sourceFormat, target: targetFormat)
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

    /// 按行、按分隔符拆单元格后再拼，避免「单元格里自带逗号」被整文件替换搞乱
    private func rewriteDelimited(input: URL, output: URL, from: String, to: String) throws {
        let content = try String(contentsOf: input, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        let rewritten = lines.map { line -> String in
            guard !line.isEmpty else { return line }
            let cells = parseDelimitedLine(line, delimiter: from)
            return cells.map { escapeDelimited($0, delimiter: to) }.joined(separator: to)
        }.joined(separator: "\n")
        try rewritten.write(to: output, atomically: true, encoding: .utf8)
    }

    private func parseDelimitedLine(_ line: String, delimiter: String) -> [String] {
        // 简易 CSV：支持双引号包裹、引号内原样保留分隔符
        var cells: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0
        let delim = delimiter.first ?? ","

        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if inQuotes, i + 1 < chars.count, chars[i + 1] == "\"" {
                    current.append("\"")
                    i += 2
                    continue
                }
                inQuotes.toggle()
                i += 1
                continue
            }
            if c == delim, !inQuotes {
                cells.append(current)
                current = ""
                i += 1
                continue
            }
            current.append(c)
            i += 1
        }
        cells.append(current)
        return cells
    }

    private func escapeDelimited(_ value: String, delimiter: String) -> String {
        let needsQuote = value.contains(delimiter) || value.contains("\"") || value.contains("\n")
        guard needsQuote else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    // MARK: - JSON 转换

    private func delimitedToJson(input: URL, output: URL, delimiter: String) throws {
        let content = try String(contentsOf: input, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let headerLine = lines.first else {
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "空文件")
        }

        let headers = parseDelimitedLine(headerLine, delimiter: delimiter).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        var records: [[String: String]] = []

        for line in lines.dropFirst() {
            let values = parseDelimitedLine(line, delimiter: delimiter)
            var record: [String: String] = [:]
            for (i, value) in values.enumerated() where i < headers.count {
                record[headers[i]] = value.trimmingCharacters(in: .whitespaces)
            }
            records.append(record)
        }

        let jsonData = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: output)
    }

    private func jsonToDelimited(input: URL, output: URL, delimiter: String) throws {
        let data = try Data(contentsOf: input)
        let json = try JSONSerialization.jsonObject(with: data)

        if let array = json as? [[String: Any]] {
            guard !array.isEmpty else {
                throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "空数组")
            }
            // 保持表头顺序稳定：按首次出现顺序收集键
            var keys: [String] = []
            var seen = Set<String>()
            for record in array {
                for key in record.keys where !seen.contains(key) {
                    seen.insert(key)
                    keys.append(key)
                }
            }
            var outputStr = keys.map { escapeDelimited($0, delimiter: delimiter) }.joined(separator: delimiter) + "\n"
            for record in array {
                let values = keys.map { key -> String in
                    if let value = record[key] {
                        return escapeDelimited(stringifyJSONValue(value), delimiter: delimiter)
                    }
                    return ""
                }
                outputStr += values.joined(separator: delimiter) + "\n"
            }
            try outputStr.write(to: output, atomically: true, encoding: .utf8)
        } else {
            throw ProcessRunnerError.executionFailed(exitCode: -1, stderr: "JSON 格式不支持（需要对象数组）")
        }
    }

    private func stringifyJSONValue(_ value: Any) -> String {
        switch value {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        case is NSNull: return ""
        default:
            if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
               let s = String(data: data, encoding: .utf8) {
                return s
            }
            return String(describing: value)
        }
    }

    // MARK: - Python 真转换

    private func pythonConvert(input: URL, output: URL, source: ConversionFormat, target: ConversionFormat) async throws {
        let pythonPath = toolDetector?.path(for: "python3") ?? "/usr/bin/python3"

        // 用环境变量传路径，避免路径里的引号把脚本弄坏
        let script = #"""
import csv, json, os, plistlib, sys, xml.etree.ElementTree as ET

src = os.environ["FC_INPUT"]
dst = os.environ["FC_OUTPUT"]
source = os.environ["FC_SOURCE"]
target = os.environ["FC_TARGET"]

def load_yaml(text):
    try:
        import yaml
    except ImportError as e:
        raise SystemExit("需要 PyYAML 才能处理 YAML。请执行：pip3 install pyyaml") from e
    return yaml.safe_load(text)

def dump_yaml(data):
    try:
        import yaml
    except ImportError as e:
        raise SystemExit("需要 PyYAML 才能处理 YAML。请执行：pip3 install pyyaml") from e
    return yaml.safe_dump(data, allow_unicode=True, sort_keys=False)

def xml_to_obj(elem):
    children = list(elem)
    node = {"_tag": elem.tag}
    if elem.attrib:
        node["_attrs"] = dict(elem.attrib)
    text = (elem.text or "").strip()
    if text:
        node["_text"] = text
    if children:
        node["_children"] = [xml_to_obj(c) for c in children]
    return node

def obj_to_xml(data, default_tag="root"):
    if isinstance(data, dict):
        tag = str(data.get("_tag") or default_tag)
        elem = ET.Element(tag)
        attrs = data.get("_attrs") or {}
        if isinstance(attrs, dict):
            for k, v in attrs.items():
                elem.set(str(k), str(v))
        if "_text" in data and data["_text"] is not None:
            elem.text = str(data["_text"])
        for child in data.get("_children") or []:
            elem.append(obj_to_xml(child, default_tag="item"))
        # 普通字典：键作为子节点
        skip = {"_tag", "_attrs", "_text", "_children"}
        for k, v in data.items():
            if k in skip:
                continue
            child = obj_to_xml(v, default_tag=str(k))
            if child.tag == "item" or child.tag == str(k):
                # 若无 _tag，用键名
                if "_tag" not in (v if isinstance(v, dict) else {}):
                    child.tag = str(k)
            elem.append(child)
        return elem
    if isinstance(data, list):
        elem = ET.Element(default_tag)
        for item in data:
            elem.append(obj_to_xml(item, default_tag="item"))
        return elem
    elem = ET.Element(default_tag)
    elem.text = "" if data is None else str(data)
    return elem

def read_csv_like(path, delimiter):
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter=delimiter)
        return list(reader)

def write_csv_like(path, rows, delimiter):
    if not rows:
        open(path, "w", encoding="utf-8").close()
        return
    # 合并所有键，保持稳定顺序
    keys = []
    seen = set()
    for row in rows:
        for k in row.keys():
            if k not in seen:
                seen.add(k)
                keys.append(k)
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=keys, delimiter=delimiter, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({k: ("" if row.get(k) is None else row.get(k)) for k in keys})

def load():
    with open(src, "rb") as f:
        raw = f.read()
    text = raw.decode("utf-8")

    if source == "json":
        return json.loads(text)
    if source == "yaml":
        return load_yaml(text)
    if source == "plist":
        return plistlib.loads(raw)
    if source == "xml":
        root = ET.fromstring(text)
        return xml_to_obj(root)
    if source == "csv":
        return read_csv_like(src, ",")
    if source == "tsv":
        return read_csv_like(src, "\t")
    raise SystemExit(f"不支持的源格式: {source}")

def save(data):
    if target == "json":
        with open(dst, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        return
    if target == "yaml":
        with open(dst, "w", encoding="utf-8") as f:
            f.write(dump_yaml(data))
        return
    if target == "plist":
        with open(dst, "wb") as f:
            plistlib.dump(data, f)
        return
    if target == "xml":
        root = obj_to_xml(data)
        tree = ET.ElementTree(root)
        try:
            ET.indent(tree, space="  ")
        except Exception:
            pass
        tree.write(dst, encoding="utf-8", xml_declaration=True)
        return
    if target in ("csv", "tsv"):
        delim = "," if target == "csv" else "\t"
        if isinstance(data, dict):
            data = [data]
        if not isinstance(data, list):
            raise SystemExit("转为表格需要对象数组或对象列表")
        # 若是 XML 风格节点列表，压成扁平行会很难看，要求用户先转 JSON
        rows = []
        for item in data:
            if isinstance(item, dict) and set(item.keys()) <= {"_tag", "_attrs", "_text", "_children"}:
                raise SystemExit("XML 结构请先转为 JSON，再导出为 CSV/TSV")
            if not isinstance(item, dict):
                raise SystemExit("表格导出需要对象数组")
            flat = {}
            for k, v in item.items():
                if isinstance(v, (dict, list)):
                    flat[k] = json.dumps(v, ensure_ascii=False)
                else:
                    flat[k] = v
            rows.append(flat)
        write_csv_like(dst, rows, delim)
        return
    raise SystemExit(f"不支持的目标格式: {target}")

try:
    save(load())
except SystemExit:
    raise
except Exception as e:
    raise SystemExit(str(e)) from e
"""#

        let tempScript = FileManager.default.temporaryDirectory
            .appendingPathComponent("convert-\(UUID().uuidString.prefix(8)).py")
        try script.write(to: tempScript, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempScript) }

        var env = ProcessInfo.processInfo.environment
        env["FC_INPUT"] = input.path
        env["FC_OUTPUT"] = output.path
        env["FC_SOURCE"] = source.rawValue
        env["FC_TARGET"] = target.rawValue

        _ = try await ProcessRunner.run(
            executable: pythonPath,
            arguments: [tempScript.path],
            environment: env
        )
    }

    func canPreview(source: ConversionFormat, target: ConversionFormat) -> Bool { true }

    func preview(input: URL, sourceFormat: ConversionFormat, targetFormat: ConversionFormat) async throws -> Data? {
        try Data(contentsOf: input)
    }
}
