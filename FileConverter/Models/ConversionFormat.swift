import Foundation
import UniformTypeIdentifiers

/// 所有支持的文件格式 — 程序中唯一标识格式的枚举
enum ConversionFormat: String, CaseIterable, Identifiable, Codable {

    // MARK: - 图片 (Images)

    case jpeg      = "jpeg"
    case png       = "png"
    case gif       = "gif"
    case bmp       = "bmp"
    case tiff      = "tiff"
    case heic      = "heic"
    case webp      = "webp"
    case ico       = "ico"
    case svg       = "svg"
    case psd       = "psd"
    case avif      = "avif"
    case jp2       = "jp2"
    case jxl       = "jxl"
    case tga       = "tga"
    case exr       = "exr"
    case dds       = "dds"
    case icns      = "icns"
    case pdfImage  = "pdf_image"   // PDF 作为图片

    // RAW 图片（只读，sips 支持读取但不支持写入）
    case cr2       = "cr2"
    case nef       = "nef"
    case arw       = "arw"
    case dng       = "dng"
    case orf       = "orf"
    case raf       = "raf"
    case rw2       = "rw2"
    case pef       = "pef"

    // MARK: - 文档 (Documents)

    case docx      = "docx"
    case doc       = "doc"
    case rtf       = "rtf"
    case rtfd      = "rtfd"
    case txt       = "txt"
    case markdown  = "markdown"
    case html      = "html"
    case odt       = "odt"
    case pages     = "pages"
    case pdfDoc    = "pdf_doc"      // PDF 作为文档

    // MARK: - 音频 (Audio)

    case mp3       = "mp3"
    case wav       = "wav"
    case aac       = "aac"
    case flac      = "flac"
    case ogg       = "ogg"
    case m4a       = "m4a"
    case aiff      = "aiff"
    case alac      = "alac"
    case opus      = "opus"
    case wma       = "wma"
    case caf       = "caf"

    // MARK: - 视频 (Video)

    case mp4       = "mp4"
    case mov       = "mov"
    case avi       = "avi"
    case mkv       = "mkv"
    case webm      = "webm"
    case flv       = "flv"
    case wmv       = "wmv"
    case m4v       = "m4v"
    case gifVideo  = "gif_video"    // GIF 动图

    // MARK: - 归档 (Archives)

    case zip       = "zip"
    case tar       = "tar"
    case gz        = "gz"
    case bz2       = "bz2"
    case xz        = "xz"
    case sevenZ    = "7z"
    case rar       = "rar"
    case dmg       = "dmg"
    case cpio      = "cpio"

    // MARK: - 文本数据 (Text & Data)

    case csv       = "csv"
    case json      = "json"
    case xml       = "xml"
    case plist     = "plist"
    case yaml      = "yaml"
    case tsv       = "tsv"

    // MARK: - 电子书 (E-books)

    case epub      = "epub"
    case mobi      = "mobi"
    case azw3      = "azw3"
    case fb2       = "fb2"

    // MARK: - 字体 (Fonts)

    case ttf       = "ttf"
    case otf       = "otf"
    case woff      = "woff"
    case woff2     = "woff2"

    // MARK: - 3D 模型 (CAD/3D)

    case stl       = "stl"
    case obj       = "obj"
    case fbx       = "fbx"
    case usdz      = "usdz"

    // MARK: - 协议

    var id: String { rawValue }
    var displayName: String { rawValue.uppercased() }

    var category: FormatCategory {
        switch self {
        case .jpeg, .png, .gif, .bmp, .tiff, .heic, .webp, .ico, .svg, .psd,
             .avif, .jp2, .jxl, .tga, .exr, .dds, .icns, .pdfImage,
             .cr2, .nef, .arw, .dng, .orf, .raf, .rw2, .pef:
            return .images

        case .docx, .doc, .rtf, .rtfd, .txt, .markdown, .html, .odt, .pages, .pdfDoc:
            return .documents

        case .mp3, .wav, .aac, .flac, .ogg, .m4a, .aiff, .alac, .opus, .wma, .caf:
            return .audio

        case .mp4, .mov, .avi, .mkv, .webm, .flv, .wmv, .m4v, .gifVideo:
            return .video

        case .zip, .tar, .gz, .bz2, .xz, .sevenZ, .rar, .dmg, .cpio:
            return .archives

        case .csv, .json, .xml, .plist, .yaml, .tsv:
            return .textData

        case .epub, .mobi, .azw3, .fb2:
            return .ebooks

        case .ttf, .otf, .woff, .woff2:
            return .fonts

        case .stl, .obj, .fbx, .usdz:
            return .cad3D
        }
    }

    /// 文件扩展名
    var preferredExtension: String {
        switch self {
        case .jpeg:      return "jpg"
        case .png:       return "png"
        case .gif:       return "gif"
        case .bmp:       return "bmp"
        case .tiff:      return "tiff"
        case .heic:      return "heic"
        case .webp:      return "webp"
        case .ico:       return "ico"
        case .svg:       return "svg"
        case .psd:       return "psd"
        case .avif:      return "avif"
        case .jp2:       return "jp2"
        case .jxl:       return "jxl"
        case .tga:       return "tga"
        case .exr:       return "exr"
        case .dds:       return "dds"
        case .icns:      return "icns"
        case .pdfImage:  return "pdf"
        case .cr2:       return "cr2"
        case .nef:       return "nef"
        case .arw:       return "arw"
        case .dng:       return "dng"
        case .orf:       return "orf"
        case .raf:       return "raf"
        case .rw2:       return "rw2"
        case .pef:       return "pef"

        case .docx:      return "docx"
        case .doc:       return "doc"
        case .rtf:       return "rtf"
        case .rtfd:      return "rtfd"
        case .txt:       return "txt"
        case .markdown:  return "md"
        case .html:      return "html"
        case .odt:       return "odt"
        case .pages:     return "pages"
        case .pdfDoc:    return "pdf"

        case .mp3:       return "mp3"
        case .wav:       return "wav"
        case .aac:       return "aac"
        case .flac:      return "flac"
        case .ogg:       return "ogg"
        case .m4a:       return "m4a"
        case .aiff:      return "aiff"
        case .alac:      return "alac"
        case .opus:      return "opus"
        case .wma:       return "wma"
        case .caf:       return "caf"

        case .mp4:       return "mp4"
        case .mov:       return "mov"
        case .avi:       return "avi"
        case .mkv:       return "mkv"
        case .webm:      return "webm"
        case .flv:       return "flv"
        case .wmv:       return "wmv"
        case .m4v:       return "m4v"
        case .gifVideo:  return "gif"

        case .zip:       return "zip"
        case .tar:       return "tar"
        case .gz:        return "gz"
        case .bz2:       return "bz2"
        case .xz:        return "xz"
        case .sevenZ:    return "7z"
        case .rar:       return "rar"
        case .dmg:       return "dmg"
        case .cpio:      return "cpio"

        case .csv:       return "csv"
        case .json:      return "json"
        case .xml:       return "xml"
        case .plist:     return "plist"
        case .yaml:      return "yaml"
        case .tsv:       return "tsv"

        case .epub:      return "epub"
        case .mobi:      return "mobi"
        case .azw3:      return "azw3"
        case .fb2:       return "fb2"

        case .ttf:       return "ttf"
        case .otf:       return "otf"
        case .woff:      return "woff"
        case .woff2:     return "woff2"

        case .stl:       return "stl"
        case .obj:       return "obj"
        case .fbx:       return "fbx"
        case .usdz:      return "usdz"
        }
    }

    /// UTType 用于格式识别
    var utType: UTType? {
        switch self {
        case .jpeg:     return .jpeg
        case .png:      return .png
        case .gif:      return .gif
        case .bmp:      return .bmp
        case .tiff:     return .tiff
        case .heic:     return .heic
        case .webp:     return .webP
        case .ico:      return .ico
        case .svg:      return .svg
        case .avif:     return UTType("public.avif")
        case .jp2:      return UTType("public.jpeg-2000")
        case .tga:      return UTType("com.truevision.tga-image")
        case .exr:      return UTType("com.ilm.openexr-image")
        case .icns:     return .icns
        case .psd:      return UTType("com.adobe.photoshop-image")
        case .pdfImage: return .pdf
        case .cr2:      return .rawImage
        case .nef:      return .rawImage
        case .arw:      return .rawImage
        case .dng:      return .rawImage
        case .orf:      return .rawImage
        case .raf:      return .rawImage
        case .rw2:      return .rawImage
        case .pef:      return .rawImage

        case .pdfDoc:   return .pdf

        case .mp3:      return .mp3
        case .wav:      return .wav
        case .aac:      return UTType("public.aac-audio")
        case .flac:     return UTType("org.xiph.flac")
        case .ogg:      return UTType("org.xiph.ogg")
        case .m4a:      return UTType("com.apple.m4a-audio")
        case .aiff:     return .aiff
        case .alac:     return UTType("com.apple.m4a-alac")
        case .caf:      return UTType("com.apple.coreaudio-format")

        case .mp4:      return .mpeg4Movie
        case .mov:      return .quickTimeMovie
        case .avi:      return .avi
        case .mkv:      return UTType("org.matroska.mkv")
        case .m4v:      return UTType("com.apple.m4v-video")

        case .zip:      return .zip
        case .tar:      return UTType("public.tar-archive")
        case .gz:       return .gzip
        case .bz2:      return .bz2
        case .xz:       return UTType("public.xz-archive")
        case .cpio:     return UTType("public.cpio-archive")

        case .csv:      return .commaSeparatedText
        case .json:     return .json
        case .xml:      return .xml
        case .plist:    return .propertyList
        case .yaml:     return UTType("public.yaml")
        case .tsv:      return UTType("public.tab-separated-values-text")

        case .epub:     return .epub

        case .ttf:      return UTType("public.truetype-font")
        case .otf:      return UTType("public.opentype-font")

        case .stl:      return UTType("com.autodesk.stl")
        case .obj:      return UTType("com.autodesk.obj")
        case .fbx:      return UTType("com.autodesk.fbx")
        case .usdz:     return UTType("com.pixar.universal-scene-description-mobile")

        default:        return nil
        }
    }

    /// 该格式是否为 RAW 图片（只读）
    var isRAW: Bool {
        switch self {
        case .cr2, .nef, .arw, .dng, .orf, .raf, .rw2, .pef: return true
        default: return false
        }
    }
}
