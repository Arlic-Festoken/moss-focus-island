import AppKit
import Foundation
import PDFKit

enum JournalImportError: LocalizedError {
    case unsupportedFormat
    case unreadable
    case emptyDocument

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            "支持 Apple 手记导出的文件夹、index.html、单篇 HTML、PDF，以及 TXT / Markdown。"
        case .unreadable:
            "无法读取这个文件。请确认它没有被移动或加密。"
        case .emptyDocument:
            "文件中没有可导入的文字。"
        }
    }
}

enum JournalImportService {
    static func records(from url: URL) throws -> [JournalRecord] {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return try recordsFromAppleJournalDirectory(url)
        }

        if url.pathExtension.lowercased() == "html" {
            if url.lastPathComponent.lowercased() == "index.html" {
                let entriesDirectory = url.deletingLastPathComponent()
                    .appendingPathComponent("Entries", isDirectory: true)
                if FileManager.default.fileExists(atPath: entriesDirectory.path) {
                    return try recordsFromAppleJournalDirectory(entriesDirectory)
                }
            }
            return [try htmlRecord(from: url)]
        }

        return [try record(fromDocument: url)]
    }

    static func record(from url: URL) throws -> JournalRecord {
        guard let first = try records(from: url).first else {
            throw JournalImportError.emptyDocument
        }
        return first
    }

    private static func record(fromDocument url: URL) throws -> JournalRecord {
        let body: String
        switch url.pathExtension.lowercased() {
        case "pdf":
            guard let document = PDFDocument(url: url) else {
                throw JournalImportError.unreadable
            }
            body = (0..<document.pageCount)
                .compactMap { document.page(at: $0)?.string }
                .joined(separator: "\n\n")
        case "txt", "text", "md", "markdown":
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                throw JournalImportError.unreadable
            }
            body = text
        default:
            throw JournalImportError.unsupportedFormat
        }

        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty else {
            throw JournalImportError.emptyDocument
        }

        let firstLine = cleanBody
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTitle = url.deletingPathExtension().lastPathComponent
        let title = firstLine.flatMap { $0.count <= 48 ? $0 : nil } ?? fallbackTitle
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        let entryDate = values?.contentModificationDate ?? values?.creationDate ?? .now

        return JournalRecord(
            title: title,
            body: cleanBody,
            entryDate: entryDate,
            source: .appleJournal,
            importedFileName: url.lastPathComponent
        )
    }

    private static func recordsFromAppleJournalDirectory(_ directory: URL) throws -> [JournalRecord] {
        let entriesDirectory: URL
        if directory.lastPathComponent == "Entries" {
            entriesDirectory = directory
        } else {
            let nestedEntries = directory.appendingPathComponent("Entries", isDirectory: true)
            entriesDirectory = FileManager.default.fileExists(atPath: nestedEntries.path)
                ? nestedEntries
                : directory
        }

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: entriesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            throw JournalImportError.unreadable
        }

        let htmlURLs = urls
            .filter { $0.pathExtension.lowercased() == "html" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !htmlURLs.isEmpty else {
            throw JournalImportError.emptyDocument
        }
        return try htmlURLs.map(htmlRecord(from:))
    }

    private static func htmlRecord(from url: URL) throws -> JournalRecord {
        guard let data = try? Data(contentsOf: url),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            throw JournalImportError.unreadable
        }

        let lines = attributed.string
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            throw JournalImportError.emptyDocument
        }

        let fileStem = url.deletingPathExtension().lastPathComponent
        let stemParts = fileStem.split(separator: "_", maxSplits: 1).map(String.init)
        let fileTitle = stemParts.count > 1
            ? stemParts[1].replacingOccurrences(of: "_", with: " ")
            : ""
        let entryDate = date(from: lines.first ?? "")
            ?? date(fromISOFileStem: stemParts.first ?? "")
            ?? ((try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate)
            ?? .now

        var contentLines = lines
        if contentLines.first.map({ date(from: $0) != nil }) == true {
            contentLines.removeFirst()
        }

        let title: String
        if !fileTitle.isEmpty {
            title = fileTitle
            if contentLines.first?.localizedCaseInsensitiveCompare(fileTitle) == .orderedSame {
                contentLines.removeFirst()
            }
        } else if contentLines.count > 1, (contentLines.first?.count ?? 0) <= 48 {
            title = contentLines.removeFirst()
        } else {
            title = entryDate.formatted(.dateTime.year().month().day())
        }

        let body = contentLines.joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            throw JournalImportError.emptyDocument
        }

        return JournalRecord(
            title: title,
            body: body,
            entryDate: entryDate,
            source: .appleJournal,
            importedFileName: url.lastPathComponent
        )
    }

    private static func date(from text: String) -> Date? {
        let pattern = #"(\d{4})年(\d{1,2})月(\d{1,2})日"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
              ),
              match.numberOfRanges == 4,
              let yearRange = Range(match.range(at: 1), in: text),
              let monthRange = Range(match.range(at: 2), in: text),
              let dayRange = Range(match.range(at: 3), in: text),
              let year = Int(text[yearRange]),
              let month = Int(text[monthRange]),
              let day = Int(text[dayRange]) else {
            return nil
        }
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }

    private static func date(fromISOFileStem stem: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: stem)
    }
}
