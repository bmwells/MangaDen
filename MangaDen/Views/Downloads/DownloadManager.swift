//
//  DownloadManager.swift
//  MangaDen
//
//  Created by Brody Wells on 9/26/25.
//

import SwiftUI

@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var downloadQueue: [DownloadTask] = []
    @Published var completedDownloads: [DownloadTask] = []
    @Published var failedDownloads: [DownloadTask] = []
    @Published var isDownloading: Bool = false
    
    private var currentTask: DownloadTask?
    private var readerJava = ReaderViewJava()
    private let maxConcurrentDownloads = 1 // One at a time for simplicity
    
    private init() {
        loadDownloadState()
    }
    
    // MARK: - Public Methods
    
    func addToDownloadQueue(chapter: Chapter) {
        // Check if already in queue or completed
        guard !downloadQueue.contains(where: { $0.chapter.id == chapter.id }) &&
              !completedDownloads.contains(where: { $0.chapter.id == chapter.id }) &&
              !failedDownloads.contains(where: { $0.chapter.id == chapter.id }) else {
            return
        }
        
        let task = DownloadTask(chapter: chapter)
        downloadQueue.append(task)
        saveDownloadState()
        
        // Start downloading if not already
        if !isDownloading {
            startNextDownload()
        }
    }
    
    func downloadAllChapters(chapters: [Chapter], titleId: UUID) {
        // Load hidden chapters for this title
        let hiddenKey = "hiddenChapters_\(titleId.uuidString)"
        let hiddenChapterURLs = UserDefaults.standard.array(forKey: hiddenKey) as? [String] ?? []
        
        for chapter in chapters {
            // Skip hidden chapters
            if hiddenChapterURLs.contains(chapter.url) {
                print("Skipping hidden chapter: \(chapter.title ?? "Chapter \(chapter.formattedChapterNumber)")")
                continue
            }
            
            // Check if already in queue or completed
            guard !downloadQueue.contains(where: { $0.chapter.id == chapter.id }) &&
                  !completedDownloads.contains(where: { $0.chapter.id == chapter.id }) &&
                  !failedDownloads.contains(where: { $0.chapter.id == chapter.id }) else {
                continue
            }
            
            let task = DownloadTask(chapter: chapter)
            downloadQueue.append(task)
        }
        
        saveDownloadState()
        
        // Start downloading if not already
        if !isDownloading && !downloadQueue.isEmpty {
            startNextDownload()
        }
    }
    
    func cancelDownload(chapterId: UUID) {
        if let index = downloadQueue.firstIndex(where: { $0.chapter.id == chapterId }) {
            downloadQueue.remove(at: index)
            saveDownloadState()
            
            // Update chapter status in title
            updateChapterDownloadStatus(chapterId: chapterId, isDownloaded: false)
        }
        
        // If this was the current task, start next one
        if currentTask?.chapter.id == chapterId {
            currentTask = nil
            startNextDownload()
        }
    }
    
    func retryDownload(chapterId: UUID) {
        if let index = failedDownloads.firstIndex(where: { $0.chapter.id == chapterId }) {
            let task = failedDownloads[index]
            failedDownloads.remove(at: index)
            var newTask = task
            newTask.status = .queued
            newTask.progress = 0.0
            newTask.error = nil
            downloadQueue.append(newTask)
            saveDownloadState()
            
            if !isDownloading {
                startNextDownload()
            }
        }
    }
    
    func clearCompleted() {
        completedDownloads.removeAll()
        saveDownloadState()
    }
    
    func clearFailed() {
        for task in failedDownloads {
            updateChapterDownloadStatus(chapterId: task.chapter.id, isDownloaded: false)
        }
        failedDownloads.removeAll()
        saveDownloadState()
    }
    
    func clearQueue() {
        for task in downloadQueue {
            updateChapterDownloadStatus(chapterId: task.chapter.id, isDownloaded: false)
        }
        downloadQueue.removeAll()
        currentTask = nil
        isDownloading = false
        saveDownloadState()
    }
    
    // MARK: - Private Methods
    
    private func startNextDownload() {
        guard !isDownloading, let nextTaskIndex = downloadQueue.firstIndex(where: { $0.status == .queued }) else {
            return
        }
        
        isDownloading = true
        var task = downloadQueue[nextTaskIndex]
        task.status = .downloading
        task.startTime = Date()
        downloadQueue[nextTaskIndex] = task
        currentTask = task
        
        Task {
            await downloadChapter(task: task)
        }
    }
    
    private func downloadChapter(task: DownloadTask) async {
        guard let url = URL(string: task.chapter.url) else {
            markDownloadFailed(task: task, error: "Invalid URL")
            return
        }
        
        do {
            // Load chapter images
            readerJava.clearCache()
            readerJava.loadChapter(url: url)
            
            // Wait for images to load
            var attempts = 0
            while readerJava.isLoading && attempts < 30 { // 30 second timeout
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                attempts += 1
            }
            
            if readerJava.error != nil || readerJava.images.isEmpty {
                markDownloadFailed(task: task, error: readerJava.error ?? "No images found")
                return
            }
            
            // Download images
            let totalImages = readerJava.images.count
            var downloadedImages: [UIImage] = []
            var totalSize: Int64 = 0
            
            for (index, image) in readerJava.images.enumerated() {
                // Update progress
                let progress = Double(index + 1) / Double(totalImages)
                updateDownloadProgress(taskId: task.id, progress: progress)
                
                // Simulate download delay
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                
                downloadedImages.append(image)
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    totalSize += Int64(imageData.count)
                }
            }
            
            // Save chapter to storage
            saveDownloadedChapter(task: task, images: downloadedImages, totalSize: totalSize)
            
        } catch {
            markDownloadFailed(task: task, error: error.localizedDescription)
        }
    }
    
    private func updateDownloadProgress(taskId: UUID, progress: Double) {
        if let index = self.downloadQueue.firstIndex(where: { $0.id == taskId }) {
            // Create a new task with updated progress
            var updatedTask = self.downloadQueue[index]
            updatedTask.progress = progress
            
            // Calculate estimated time remaining
            let elapsedTime = Date().timeIntervalSince(updatedTask.startTime)
            if progress > 0 {
                let totalEstimatedTime = elapsedTime / progress
                updatedTask.estimatedTimeRemaining = totalEstimatedTime - elapsedTime
            }
            
            self.downloadQueue[index] = updatedTask
        }
    }

    private func saveDownloadedChapter(task: DownloadTask, images: [UIImage], totalSize: Int64) {
        // Save images to file system
        let chapterId = task.chapter.id.uuidString
        let fileManager = FileManager.default
        
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            self.markDownloadFailed(task: task, error: "Could not access documents directory")
            return
        }
        
        let chapterDirectory = documentsDirectory.appendingPathComponent("Downloads/\(chapterId)")
        
        do {
            // Create directory
            try fileManager.createDirectory(at: chapterDirectory, withIntermediateDirectories: true)
            
            // Save each image
            for (index, image) in images.enumerated() {
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    let imagePath = chapterDirectory.appendingPathComponent("\(index).jpg")
                    try imageData.write(to: imagePath)
                }
            }
            
            // Save chapter info
            let infoPath = chapterDirectory.appendingPathComponent("info.json")
            let chapterInfo: [String: Any] = [
                "chapterId": chapterId,
                "chapterNumber": task.chapter.chapterNumber,
                "title": task.chapter.title ?? "",
                "url": task.chapter.url,
                "totalImages": images.count,
                "fileSize": totalSize,
                "downloadDate": Date().timeIntervalSince1970
            ]
            
            let infoData = try JSONSerialization.data(withJSONObject: chapterInfo)
            try infoData.write(to: infoPath)
            
            // Mark as completed
            self.markDownloadCompleted(task: task, fileSize: totalSize)
            
        } catch {
            self.markDownloadFailed(task: task, error: error.localizedDescription)
        }
    }

    private func markDownloadFailed(task: DownloadTask, error: String) {
        if let index = self.downloadQueue.firstIndex(where: { $0.id == task.id }) {
            var failedTask = self.downloadQueue[index]
            failedTask.status = .failed
            failedTask.error = error
            
            self.downloadQueue.remove(at: index)
            self.failedDownloads.append(failedTask)
            
            // Update chapter status
            self.updateChapterDownloadStatus(chapterId: task.chapter.id, isDownloaded: false)
            
            self.currentTask = nil
            self.isDownloading = false
            self.saveDownloadState()
            
            // Start next download
            self.startNextDownload()
        }
    }
    
    private func markDownloadCompleted(task: DownloadTask, fileSize: Int64) {
        if let index = self.downloadQueue.firstIndex(where: { $0.id == task.id }) {
            var completedTask = self.downloadQueue[index]
            completedTask.status = .completed
            completedTask.progress = 1.0
            completedTask.fileSize = fileSize // Set the file size here
            
            self.downloadQueue.remove(at: index)
            self.completedDownloads.append(completedTask)
            
            // Update chapter status in title
            self.updateChapterDownloadStatus(chapterId: task.chapter.id, isDownloaded: true, fileSize: fileSize)
            
            self.currentTask = nil
            self.isDownloading = false
            self.saveDownloadState()
            
            // Start next download
            self.startNextDownload()
        }
    }
    
    private func updateChapterDownloadStatus(chapterId: UUID, isDownloaded: Bool, fileSize: Int64? = nil) {
        // Find and update the title containing this chapter
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            
            let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
            let titleFiles = try fileManager.contentsOfDirectory(at: titlesDirectory, includingPropertiesForKeys: nil)
            
            for file in titleFiles where file.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: file)
                    var title = try JSONDecoder().decode(Title.self, from: data)
                    
                    // Update chapter if found
                    if let chapterIndex = title.chapters.firstIndex(where: { $0.id == chapterId }) {
                        title.chapters[chapterIndex].isDownloaded = isDownloaded
                        if let fileSize = fileSize {
                            title.chapters[chapterIndex].fileSize = fileSize
                        }
                        
                        // Save updated title
                        let titleData = try JSONEncoder().encode(title)
                        try titleData.write(to: file)
                        
                        // Notify views to update
                        NotificationCenter.default.post(name: .titleUpdated, object: nil)
                        break
                    }
                } catch {
                    print("Error updating chapter status: \(error)")
                }
            }
        } catch {
            print("Error accessing title files: \(error)")
        }
    }
    
    private func saveDownloadState() {
        let downloadState = DownloadState(
            queue: downloadQueue,
            completed: completedDownloads,
            failed: failedDownloads
        )
        
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            
            let stateFile = documentsDirectory.appendingPathComponent("download_state.json")
            let data = try JSONEncoder().encode(downloadState)
            try data.write(to: stateFile)
        } catch {
            print("Error saving download state: \(error)")
        }
    }
    
    private func loadDownloadState() {
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            
            let stateFile = documentsDirectory.appendingPathComponent("download_state.json")
            if fileManager.fileExists(atPath: stateFile.path) {
                let data = try Data(contentsOf: stateFile)
                let downloadState = try JSONDecoder().decode(DownloadState.self, from: data)
                
                downloadQueue = downloadState.queue
                completedDownloads = downloadState.completed
                failedDownloads = downloadState.failed
            }
        } catch {
            print("Error loading download state: \(error)")
        }
    }
}
