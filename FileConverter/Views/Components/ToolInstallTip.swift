import SwiftUI

/// 工具安装提示条
struct ToolInstallTip: View {
    let toolName: String
    let displayName: String
    let description: String
    let installCommand: String
    let homepage: String?

    @State private var showInstallSheet = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wrench.adjustable")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button("如何安装") {
                showInstallSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .sheet(isPresented: $showInstallSheet) {
            InstallSheet(
                displayName: displayName,
                installCommand: installCommand,
                homepage: homepage
            )
            .frame(width: 450, height: 300)
        }
    }
}

/// 安装指引弹窗
struct InstallSheet: View {
    let displayName: String
    let installCommand: String
    let homepage: String?
    var onInstalled: (() -> Void)? = nil  // 安装完成回调（重新扫描）

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    /// 检测 Homebrew 是否已安装
    private var homebrewInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/brew") ||
        FileManager.default.isExecutableFile(atPath: "/usr/local/bin/brew")
    }

    /// 是否需要先安装 Homebrew
    private var needsHomebrew: Bool {
        !homebrewInstalled && installCommand.hasPrefix("brew")
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: needsHomebrew ? "exclamationmark.triangle" : "terminal")
                .font(.system(size: 40))
                .foregroundStyle(needsHomebrew ? .orange : .blue)

            Text(needsHomebrew ? "需要 Homebrew" : "安装 \(displayName)")
                .font(.title2)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 14) {
                if needsHomebrew {
                    // ─── 没有 Homebrew → 先指导安装 Homebrew ───
                    Text("Homebrew 是什么？")
                        .font(.headline)
                    Text("Homebrew 是 macOS 上的软件包管理器。你需要的命令行工具（ffmpeg、pandoc 等）都可以通过它一键安装。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()
                    Text("第 1 步：安装 Homebrew")
                        .font(.headline)

                    let brewCmd = "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                    HStack {
                        Text(brewCmd)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                            .textSelection(.enabled)

                        Button(action: { copyToClipboard(brewCmd) }) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("复制命令")
                    }

                    Text("打开「终端」App，粘贴上面的命令并回车。安装完成后回到这里。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()
                    Text("第 2 步：安装 \(displayName)")
                        .font(.headline)

                    Text(installCommand)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        .textSelection(.enabled)

                    Text("Homebrew 装好后，点下方按钮运行这个命令。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    // ─── 已有 Homebrew → 正常安装流程 ───
                    Text("使用 Homebrew 安装（推荐）")
                        .font(.headline)

                    HStack {
                        Text(installCommand)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                            .textSelection(.enabled)

                        Button(action: copyCommand) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("复制命令")
                    }

                    Text("点击下方按钮会自动打开「终端」并执行命令。安装可能需要几分钟。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let url = homepage {
                        Divider()
                        Text("手动下载")
                            .font(.headline)
                        Link("访问 \(displayName) 官网 →", destination: URL(string: url)!)
                            .font(.callout)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 8))

            // 操作按钮
            HStack(spacing: 12) {
                Button("取消") { dismiss() }
                    .buttonStyle(.bordered)

                if needsHomebrew {
                    Button(action: { runInTerminal(installCommand) }) {
                        Label("运行安装命令", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!homebrewInstalled)
                } else {
                    Button(action: { runInTerminal(installCommand) }) {
                        Label("在终端运行", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if onInstalled != nil {
                    Button(action: { onInstalled?(); dismiss() }) {
                        Label("重新扫描", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 480, idealHeight: needsHomebrew ? 520 : 420)
    }

    private func copyCommand() {
        copyToClipboard(installCommand)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copied = false }
        }
    }

    private func runInTerminal(_ command: String = "") {
        let cmd = command.isEmpty ? installCommand : command
        let escaped = cmd
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """
        NSAppleScript(source: script)?.executeAndReturnError(nil)
    }
}

