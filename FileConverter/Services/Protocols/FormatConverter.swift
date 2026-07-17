import Foundation

/// 所有格式转换器必须遵循的协议
protocol FormatConverter: AnyObject, Sendable {
    /// 显示名称
    var displayName: String { get }

    /// 所属类别
    var category: FormatCategory { get }

    /// 该转换器依赖的工具名称列表
    var requiredTools: [String] { get }

    /// 所支持的可选工具（有的话扩展能力）
    var optionalTools: [String] { get }

    /// 该转换器可以处理哪些输入格式
    func supportedInputFormats() -> [ConversionFormat]

    /// 该转换器可以输出哪些格式
    func supportedOutputFormats() -> [ConversionFormat]

    /// 基于当前可用工具，返回所有可行的转换对
    func availableConversions() -> [(source: ConversionFormat, target: ConversionFormat)]

    /// 检查是否能执行某个转换
    func canConvert(source: ConversionFormat, target: ConversionFormat) -> Bool

    /// 执行转换，返回输出文件的 URL
    func convert(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat,
        settings: ConversionSettings
    ) async throws -> URL

    /// 转换过程中是否支持进度回调
    var supportsProgress: Bool { get }

    /// 执行转换（带进度回调），默认实现调用无进度版本
    func convert(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat,
        settings: ConversionSettings,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL

    /// 该转换对是否能生成预览
    func canPreview(source: ConversionFormat, target: ConversionFormat) -> Bool

    /// 生成预览数据
    func preview(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat
    ) async throws -> Data?
}

// MARK: - 默认实现

extension FormatConverter {
    var supportsProgress: Bool { false }

    func convert(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat,
        settings: ConversionSettings,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        // 默认实现：直接调用无进度版本
        return try await convert(
            input: input,
            sourceFormat: sourceFormat,
            targetFormat: targetFormat,
            settings: settings
        )
    }

    func canPreview(source: ConversionFormat, target: ConversionFormat) -> Bool { false }

    func preview(
        input: URL,
        sourceFormat: ConversionFormat,
        targetFormat: ConversionFormat
    ) async throws -> Data? { nil }
}
