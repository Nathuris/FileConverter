import Foundation

// MARK: - 自定义错误

enum ProcessRunnerError: LocalizedError {
    case executionFailed(exitCode: Int32, stderr: String)
    case timedOut(after: TimeInterval)
    case executableNotFound(name: String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .executionFailed(let code, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "命令执行失败（退出码 \(code)）"
            }
            return "命令执行失败（退出码 \(code)）：\(detail)"
        case .timedOut(let interval):
            return "命令超时（\(Int(interval)) 秒）"
        case .executableNotFound(let name):
            return "找不到工具：\(name)"
        case .cancelled:
            return "操作已被取消"
        }
    }
}

// MARK: - ProcessRunner

/// 封装 Foundation.Process 提供现代化的 async/await 调用方式
struct ProcessRunner {

    /// 命令执行结果
    struct Result: Sendable {
        let exitCode: Int32
        let stdout: String
        let stderr: String
        let duration: TimeInterval

        var isSuccess: Bool { exitCode == 0 }
    }

    // MARK: - 基本执行

    /// 执行一个命令并等待结果
    static func run(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 300,
        workingDirectory: URL? = nil
    ) async throws -> Result {
        try await runInternal(
            executable: executable,
            arguments: arguments,
            environment: environment,
            timeout: timeout,
            workingDirectory: workingDirectory,
            progressParser: nil,
            onProgress: nil
        )
    }

    // MARK: - 带进度的执行

    static func runWithProgress(
        executable: String,
        arguments: [String],
        progressParser: @escaping @Sendable (String) -> Double?,
        onProgress: (@Sendable (Double) -> Void)? = nil,
        timeout: TimeInterval = 3600
    ) async throws -> Result {
        try await runInternal(
            executable: executable,
            arguments: arguments,
            environment: nil,
            timeout: timeout,
            workingDirectory: nil,
            progressParser: progressParser,
            onProgress: onProgress
        )
    }

    // MARK: - 内部实现

    private static func runInternal(
        executable: String,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval,
        workingDirectory: URL?,
        progressParser: (@Sendable (String) -> Double?)?,
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws -> Result {
        let startTime = Date()

        guard FileManager.default.isExecutableFile(atPath: executable) || !executable.hasPrefix("/") else {
            throw ProcessRunnerError.executableNotFound(name: executable)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        if let env = environment {
            process.environment = env
        }
        if let dir = workingDirectory {
            process.currentDirectoryURL = dir
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // 一边跑一边读管道，避免 ffmpeg 之类把缓冲区写满后双方卡死
        let outputBox = OutputBox()
        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        stdoutHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            outputBox.appendStdout(data)
            if let parser = progressParser, let onProgress,
               let text = String(data: data, encoding: .utf8) {
                for line in text.split(whereSeparator: \.isNewline) {
                    if let value = parser(String(line)) {
                        onProgress(value)
                    }
                }
            }
        }
        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            outputBox.appendStderr(data)
            // ffmpeg 进度有时在 stderr
            if let parser = progressParser, let onProgress,
               let text = String(data: data, encoding: .utf8) {
                for line in text.split(whereSeparator: \.isNewline) {
                    if let value = parser(String(line)) {
                        onProgress(value)
                    }
                }
            }
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Result, Error>) in
                let state = ResumeOnce(continuation: continuation)

                let timeoutFlag = TimeoutFlag()

                process.terminationHandler = { proc in
                    stdoutHandle.readabilityHandler = nil
                    stderrHandle.readabilityHandler = nil

                    // 再读干净残留
                    let restOut = stdoutHandle.readDataToEndOfFile()
                    let restErr = stderrHandle.readDataToEndOfFile()
                    outputBox.appendStdout(restOut)
                    outputBox.appendStderr(restErr)

                    let duration = Date().timeIntervalSince(startTime)
                    let stdout = outputBox.stdoutString
                    let stderr = outputBox.stderrString

                    if timeoutFlag.isSet {
                        state.resume(throwing: ProcessRunnerError.timedOut(after: timeout))
                        return
                    }

                    if Task.isCancelled {
                        state.resume(throwing: ProcessRunnerError.cancelled)
                        return
                    }

                    if proc.terminationStatus != 0 {
                        state.resume(throwing: ProcessRunnerError.executionFailed(
                            exitCode: proc.terminationStatus, stderr: stderr
                        ))
                    } else {
                        state.resume(returning: Result(
                            exitCode: proc.terminationStatus,
                            stdout: stdout, stderr: stderr, duration: duration
                        ))
                    }
                }

                do {
                    try process.run()
                } catch {
                    stdoutHandle.readabilityHandler = nil
                    stderrHandle.readabilityHandler = nil
                    state.resume(throwing: error)
                    return
                }

                // 真正生效的超时：到点就杀掉进程
                if timeout > 0 {
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        if process.isRunning {
                            timeoutFlag.mark()
                            process.terminate()
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            if process.isRunning {
                                kill(process.processIdentifier, SIGKILL)
                            }
                        }
                    }
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }

    // MARK: - 工具检测

    /// 检查可执行文件是否可用
    static func isToolAvailable(_ name: String) -> Bool {
        if name.hasPrefix("/") {
            return FileManager.default.isExecutableFile(atPath: name)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !path.isEmpty && process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// 获取工具版本号
    static func getToolVersion(_ name: String, versionFlag: String = "--version") -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: name)
        process.arguments = [versionFlag]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.components(separatedBy: .newlines).first
        } catch {
            return nil
        }
    }
}

// MARK: - 辅助：线程安全输出缓冲 + 只 resume 一次

private final class OutputBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stdout = Data()
    private var stderr = Data()

    func appendStdout(_ data: Data) {
        lock.lock(); stdout.append(data); lock.unlock()
    }

    func appendStderr(_ data: Data) {
        lock.lock(); stderr.append(data); lock.unlock()
    }

    var stdoutString: String {
        lock.lock(); defer { lock.unlock() }
        return String(data: stdout, encoding: .utf8) ?? ""
    }

    var stderrString: String {
        lock.lock(); defer { lock.unlock() }
        return String(data: stderr, encoding: .utf8) ?? ""
    }
}

private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ProcessRunner.Result, Error>?
    private var resumed = false

    init(continuation: CheckedContinuation<ProcessRunner.Result, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: ProcessRunner.Result) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed, let c = continuation else { return }
        resumed = true
        continuation = nil
        c.resume(returning: value)
    }

    func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed, let c = continuation else { return }
        resumed = true
        continuation = nil
        c.resume(throwing: error)
    }
}

private final class TimeoutFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func mark() {
        lock.lock(); value = true; lock.unlock()
    }

    var isSet: Bool {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}
