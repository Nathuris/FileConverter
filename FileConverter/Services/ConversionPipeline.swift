import Foundation

/// 批量转换调度器 — 用 actor 保证线程安全
actor ConversionPipeline {
    /// 活跃的转换任务映射
    private var activeTasks: [UUID: Task<ConversionResult?, Never>] = [:]

    /// 完成文件数
    private var completedCount: Int = 0

    /// 总文件数
    private var totalCount: Int = 0

    /// 是否正在取消
    private var isCancelling = false

    // MARK: - 转换

    /// 执行批量转换
    /// - Parameters:
    ///   - files: 待转换文件列表
    ///   - converters: 按类别分组的转换器
    ///   - settings: 全局转换设置
    ///   - outputDirectory: 输出目录
    ///   - maxConcurrency: 最大并行数
    ///   - onFileComplete: 单个文件完成时的回调
    ///   - onOverallProgress: 总体进度回调 (0.0 - 1.0)
    /// - Returns: 所有文件的转换结果
    func convert(
        files: [ConversionFile],
        converters: [FormatCategory: any FormatConverter],
        settings: ConversionSettings,
        outputDirectory: URL,
        maxConcurrency: Int = 4,
        onFileComplete: @escaping @Sendable (ConversionResult) -> Void,
        onOverallProgress: @escaping @Sendable (Double) -> Void
    ) async -> [ConversionResult] {
        totalCount = files.count
        completedCount = 0
        isCancelling = false
        activeTasks.removeAll()

        var results: [ConversionResult] = []

        // 确保输出目录存在
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        // 使用 TaskGroup 并行执行
        await withTaskGroup(of: ConversionResult?.self) { group in
            var running = 0

            for file in files {
                // 检查取消
                if isCancelling || Task.isCancelled { break }

                // 等待有空闲槽位
                while running >= maxConcurrency {
                    if let result = await group.next(), let r = result {
                        results.append(r)
                        onFileComplete(r)
                        completedCount += 1
                        onOverallProgress(Double(completedCount) / Double(totalCount))
                        running -= 1
                    }
                }

                guard let converter = converters[file.detectedFormat.category] else {
                    let errResult = ConversionResult(
                        sourceFile: file,
                        outputURL: file.sourceURL,
                        success: false,
                        sourceSize: file.fileSize,
                        outputSize: 0,
                        duration: 0,
                        errorMessage: "该类别没有可用转换器"
                    )
                    results.append(errResult)
                    onFileComplete(errResult)
                    completedCount += 1
                    continue
                }

                running += 1
                let taskId = file.id
                let capturedTask = Task<ConversionResult?, Never> {
                    return await convertOne(
                        file: file,
                        converter: converter,
                        settings: settings,
                        outputDirectory: outputDirectory,
                        taskId: taskId
                    )
                }
                activeTasks[taskId] = capturedTask

                group.addTask {
                    return await capturedTask.value
                }
            }

            // 等待剩余任务完成
            for await result in group {
                if let r = result {
                    results.append(r)
                    onFileComplete(r)
                    completedCount += 1
                    let progress = Double(completedCount) / Double(totalCount)
                    await MainActor.run {
                        onOverallProgress(progress)
                    }
                }
            }
        }

        return results
    }

    /// 转换单个文件
    private func convertOne(
        file: ConversionFile,
        converter: any FormatConverter,
        settings: ConversionSettings,
        outputDirectory: URL,
        taskId: UUID
    ) async -> ConversionResult? {
        // 检查是否可以执行转换
        guard converter.canConvert(source: file.detectedFormat, target: file.targetFormat) else {
            return ConversionResult(
                sourceFile: file,
                outputURL: file.sourceURL,
                success: false,
                sourceSize: file.fileSize,
                outputSize: 0,
                duration: 0,
                errorMessage: "不支持该转换：\(file.detectedFormat.displayName) → \(file.targetFormat.displayName)"
            )
        }

        let startTime = Date()

        do {
            // 先输出到临时目录
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("FileConverter-\(UUID().uuidString.prefix(8))")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // 执行转换
            let outputURL = try await converter.convert(
                input: file.sourceURL,
                sourceFormat: file.detectedFormat,
                targetFormat: file.targetFormat,
                settings: settings
            )

            // 移动到最终目录
            let finalOutput = outputDirectory.appendingPathComponent(file.suggestedOutputName)
            let finalURL = resolveConflict(for: finalOutput, settings: settings)

            if outputURL != finalURL {
                try? FileManager.default.removeItem(at: finalURL)
                try FileManager.default.moveItem(at: outputURL, to: finalURL)
            }

            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)

            let duration = Date().timeIntervalSince(startTime)
            let outputSize = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0

            return ConversionResult(
                sourceFile: file,
                outputURL: finalURL,
                success: true,
                sourceSize: file.fileSize,
                outputSize: outputSize,
                duration: duration,
                errorMessage: nil
            )

        } catch let error as ProcessRunnerError {
            return ConversionResult(
                sourceFile: file,
                outputURL: file.sourceURL,
                success: false,
                sourceSize: file.fileSize,
                outputSize: 0,
                duration: Date().timeIntervalSince(startTime),
                errorMessage: error.localizedDescription
            )
        } catch {
            return ConversionResult(
                sourceFile: file,
                outputURL: file.sourceURL,
                success: false,
                sourceSize: file.fileSize,
                outputSize: 0,
                duration: Date().timeIntervalSince(startTime),
                errorMessage: error.localizedDescription
            )
        }
    }

    // MARK: - 取消

    func cancelAll() {
        isCancelling = true
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }

    // MARK: - 辅助

    /// 处理文件名冲突
    private func resolveConflict(for url: URL, settings: ConversionSettings) -> URL {
        if settings.overwriteExisting { return url }
        guard FileManager.default.fileExists(atPath: url.path) else { return url }

        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let dir = url.deletingDirectory()

        var counter = 1
        var newURL: URL
        repeat {
            newURL = dir.appendingPathComponent("\(baseName)_\(counter).\(ext)")
            counter += 1
        } while FileManager.default.fileExists(atPath: newURL.path)

        return newURL
    }
}

// MARK: - URL 扩展

extension URL {
    func deletingDirectory() -> URL {
        var path = self.path
        if path.hasSuffix("/") {
            path = String(path.dropLast())
        }
        return URL(fileURLWithPath: path).deletingLastPathComponent()
    }
}
