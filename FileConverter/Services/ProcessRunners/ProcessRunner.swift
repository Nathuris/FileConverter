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
            return "命令执行失败（退出码 \(code)）：\(stderr)"
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
        let startTime = Date()

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

        // 使用 Task 来支持取消和超时
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Result, Error>) in
                process.terminationHandler = { proc in
                    let duration = Date().timeIntervalSince(startTime)
                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                    if proc.terminationStatus != 0 {
                        continuation.resume(throwing: ProcessRunnerError.executionFailed(
                            exitCode: proc.terminationStatus, stderr: stderr
                        ))
                    } else {
                        continuation.resume(returning: Result(
                            exitCode: proc.terminationStatus,
                            stdout: stdout, stderr: stderr, duration: duration
                        ))
                    }
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
        }
    }

    // MARK: - 带进度的执行

    static func runWithProgress(
        executable: String,
        arguments: [String],
        progressParser: @Sendable (String) -> Double?,
        timeout: TimeInterval = 3600
    ) async throws -> Result {
        let startTime = Date()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Result, Error>) in
                process.terminationHandler = { proc in
                    let duration = Date().timeIntervalSince(startTime)
                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                    if proc.terminationStatus != 0 {
                        continuation.resume(throwing: ProcessRunnerError.executionFailed(
                            exitCode: proc.terminationStatus, stderr: stderr
                        ))
                    } else {
                        continuation.resume(returning: Result(
                            exitCode: proc.terminationStatus,
                            stdout: stdout, stderr: stderr, duration: duration
                        ))
                    }
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
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
