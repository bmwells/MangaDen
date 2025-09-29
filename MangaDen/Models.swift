//
//  Models.swift
//  MangaDen
//
//  Created by Brody Wells on 9/26/25.
//

import Foundation

// MARK: - Chapter Model
struct Chapter: Identifiable, Codable, Equatable {
    let id: UUID
    let chapterNumber: Double
    let url: String
    let title: String?
    let uploadDate: String?
    var isDownloaded: Bool
    var isRead: Bool
    var downloadProgress: Double
    var downloadError: String?
    var totalImages: Int
    var downloadedImages: Int
    var fileSize: Int64?
    
    var formattedChapterNumber: String {
        if chapterNumber.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", chapterNumber)
        } else {
            return String(chapterNumber)
        }
    }
    
    init(id: UUID = UUID(), chapterNumber: Double, url: String, title: String? = nil,
         uploadDate: String? = nil, isDownloaded: Bool = false, isRead: Bool = false,
         downloadProgress: Double = 0.0, downloadError: String? = nil,
         totalImages: Int = 0, downloadedImages: Int = 0, fileSize: Int64? = nil) {
        self.id = id
        self.chapterNumber = chapterNumber
        self.url = url
        self.title = title
        self.uploadDate = uploadDate
        self.isDownloaded = isDownloaded
        self.isRead = isRead
        self.downloadProgress = downloadProgress
        self.downloadError = downloadError
        self.totalImages = totalImages
        self.downloadedImages = downloadedImages
        self.fileSize = fileSize
    }
    
    init?(from dict: [String: Any]) {
        guard let chapterNumber = dict["chapter_number"] as? Double,
              let url = dict["url"] as? String else {
            return nil
        }
        
        self.id = UUID()
        self.chapterNumber = chapterNumber
        self.url = url
        self.title = dict["title"] as? String
        self.uploadDate = dict["upload_date"] as? String
        self.isDownloaded = false
        self.isRead = false
        self.downloadProgress = 0.0
        self.downloadError = nil
        self.totalImages = 0
        self.downloadedImages = 0
        self.fileSize = nil
    }
}

// MARK: - Download Task Model
struct DownloadTask: Identifiable, Codable {
    let id: UUID
    let chapter: Chapter
    var status: DownloadStatus
    var progress: Double
    var error: String?
    var startTime: Date
    var estimatedTimeRemaining: TimeInterval?
    
    init(chapter: Chapter) {
        self.id = UUID()
        self.chapter = chapter
        self.status = .queued
        self.progress = 0.0
        self.error = nil
        self.startTime = Date()
        self.estimatedTimeRemaining = nil
    }
}

enum DownloadStatus: String, Codable {
    case queued = "Queued"
    case downloading = "Downloading"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

// MARK: - Download State Model (ADD THIS)
struct DownloadState: Codable {
    let queue: [DownloadTask]
    let completed: [DownloadTask]
    let failed: [DownloadTask]
}

// MARK: - Title Model (Updated)
struct Title: Identifiable, Codable {
    let id: UUID
    var title: String
    var author: String
    var status: String
    var coverImageData: Data?
    var chapters: [Chapter]
    let metadata: [String: Any]
    var isDownloaded: Bool
    var isArchived: Bool
    var sourceURL: String?
    
    var downloadedChapters: [Chapter] {
        chapters.filter { $0.isDownloaded }
    }
    
    var totalDownloadedSize: Int64 {
        downloadedChapters.reduce(0) { $0 + ($1.fileSize ?? 0) }
    }
    
    var formattedDownloadSize: String {
        let bytes = totalDownloadedSize
        if bytes >= 1_000_000_000 {
            return String(format: "%.1f GB", Double(bytes) / 1_000_000_000.0)
        } else {
            return String(format: "%.0f MB", Double(bytes) / 1_000_000.0)
        }
    }
    
    // Coding keys to handle the metadata dictionary
    enum CodingKeys: String, CodingKey {
        case id, title, author, status, coverImageData, chapters, isDownloaded, isArchived, metadata, sourceURL
    }
    
    init(id: UUID = UUID(), title: String, author: String, status: String,
         coverImageData: Data?, chapters: [Chapter], metadata: [String: Any],
         isDownloaded: Bool = false, isArchived: Bool = false, sourceURL: String? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.status = status
        self.coverImageData = coverImageData
        self.chapters = chapters
        self.metadata = metadata
        self.isDownloaded = isDownloaded
        self.isArchived = isArchived
        self.sourceURL = sourceURL
    }
    
    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(author, forKey: .author)
        try container.encode(status, forKey: .status)
        try container.encode(coverImageData, forKey: .coverImageData)
        try container.encode(chapters, forKey: .chapters)
        try container.encode(isDownloaded, forKey: .isDownloaded)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(sourceURL, forKey: .sourceURL)
        
        // Encode metadata as JSON data
        let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [])
        try container.encode(metadataData, forKey: .metadata)
    }
    
    // Custom decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        status = try container.decode(String.self, forKey: .status)
        coverImageData = try container.decode(Data?.self, forKey: .coverImageData)
        chapters = try container.decode([Chapter].self, forKey: .chapters)
        isDownloaded = try container.decode(Bool.self, forKey: .isDownloaded)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
        
        // Decode metadata from JSON data
        let metadataData = try container.decode(Data.self, forKey: .metadata)
        metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any] ?? [:]
    }
}
