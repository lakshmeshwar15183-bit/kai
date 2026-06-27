import Foundation

/// Buckets files by purpose when organising a folder. Extensible: add a case and
/// its extensions without touching the organiser logic.
public enum FileCategory: String, Sendable, CaseIterable {
    case images = "Images"
    case documents = "Documents"
    case pdfs = "PDFs"
    case archives = "Archives"
    case audio = "Audio"
    case video = "Video"
    case code = "Code"
    case other = "Other"

    private static let map: [String: FileCategory] = {
        var result: [String: FileCategory] = [:]
        let table: [FileCategory: [String]] = [
            .images: ["png", "jpg", "jpeg", "gif", "heic", "tiff", "bmp", "webp", "svg"],
            .documents: ["doc", "docx", "txt", "rtf", "pages", "md", "csv", "xlsx", "xls", "key", "ppt", "pptx"],
            .pdfs: ["pdf"],
            .archives: ["zip", "tar", "gz", "tgz", "rar", "7z", "bz2"],
            .audio: ["mp3", "wav", "aac", "flac", "m4a", "aiff"],
            .video: ["mp4", "mov", "avi", "mkv", "m4v", "webm"],
            .code: ["swift", "py", "js", "ts", "java", "c", "cpp", "h", "rb", "go", "rs", "sh", "json", "yml", "yaml"]
        ]
        for (category, extensions) in table {
            for ext in extensions { result[ext] = category }
        }
        return result
    }()

    /// Classifies a file by its (lowercased) extension.
    public static func forExtension(_ ext: String) -> FileCategory {
        map[ext.lowercased()] ?? .other
    }
}
