# FileConverter

macOS 原生文件格式转换器，支持 100+ 格式互转，拖放即用。

## 技术栈

- **Swift 6 + SwiftUI**，零第三方依赖
- 所有转换通过 `Foundation.Process` 调用系统/开源命令行工具完成
- `@Observable` (Swift 6 Observation) + actor 并发模型
- 协议化转换器架构：`FormatConverter` → 9 个实现

## 转换引擎

| 类别 | 核心工具 | 可选扩展 |
|------|---------|---------|
| 📷 图片 | `sips` (macOS 内置) | ImageMagick, ffmpeg |
| 📄 文档 | `textutil` (macOS 内置) | pandoc, LibreOffice |
| 🎵 音频 | `afconvert` (macOS 内置) | ffmpeg |
| 🎬 视频 | ffmpeg | — |
| 📦 归档 | `ditto` / `tar` (macOS 内置) | p7zip |
| 📊 文本数据 | `plutil` + Swift 原生解析 | — |

## 架构

```
View (SwiftUI) → ViewModel (@Observable)
    → ConversionPipeline (actor, TaskGroup 并行)
        → FormatConverter 协议 → 9 个转换器
            → ProcessRunner (async Process 封装)
```

- **优雅降级**：启动时扫描工具，按实际可用性动态决定支持的格式
- **批量并行**：TaskGroup 控制并发数，实时进度回调
- **格式识别**：UTType + 扩展名 双层匹配
