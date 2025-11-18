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
    @Published var isPaused: Bool = false
    
    private var currentTask: DownloadTask?
    private var currentDownloadTask: Task<Void, Never>?
    
    // Add ReaderViewJava instance for progress tracking
    private var currentReaderJava: ReaderViewJava?
    
    // MINIMUM_IMAGES_REQUIRED for download
    private let MINIMUM_IMAGES_REQUIRED = 11
    
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
        
        // Start downloading if not already and not paused
        if !isDownloading && !isPaused {
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
                continue
            }
            
            // Check if already in queue or completed
            guard !downloadQueue.contains(where: { $0.chapter.id == chapter.id }) &&
                  !completedDownloads.contains(where: { $0.chapter.id == chapter.id }) &&
                  !failedDownloads.contains(where: { $0.chapter.id == chapter.id }) else {
                continue
            }
            
            // Check if chapter is already marked as downloaded
            if chapter.safeIsDownloaded {
                continue
            }
            
            let task = DownloadTask(chapter: chapter)
            downloadQueue.append(task)
        }
        
        saveDownloadState()
        
        // Start downloading if not already and not paused
        if !isDownloading && !isPaused && !downloadQueue.isEmpty {
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
            currentReaderJava?.stopLoading()
            currentReaderJava = nil
            if !isPaused {
                startNextDownload()
            }
        }
    }
    
    func retryDownload(chapterId: UUID) {
        if let index = failedDownloads.firstIndex(where: { $0.chapter.id == chapterId }) {
            let task = failedDownloads[index]
            failedDownloads.remove(at: index)
            var newTask = task
            newTask.status = .queued
            newTask.progress = 0.0 // Reset progress to 0% when retrying
            newTask.error = nil
            downloadQueue.append(newTask)
            saveDownloadState()
            
            if !isDownloading && !isPaused {
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
        // Cancel any ongoing download first
        stopAllDownloads()
        
        // Remove all chapters from queue
        for task in downloadQueue {
            updateChapterDownloadStatus(chapterId: task.chapter.id, isDownloaded: false)
        }
        downloadQueue.removeAll()
        currentTask = nil
        currentReaderJava = nil
        isDownloading = false
        isPaused = false
        saveDownloadState()
    }
    
    // MARK: - Progress Text Access
    
    func getCurrentDownloadProgressText() -> String {
        return currentReaderJava?.downloadProgress ?? "Starting download..."
    }
    
    // MARK: - Stop/Resume Methods
    
    func stopAllDownloads() {
        guard !isPaused else { return } // Already paused
        
        isPaused = true
        isDownloading = false
        
        // Cancel the current async download task
        currentDownloadTask?.cancel()
        currentDownloadTask = nil
        
        // Stop the current reader
        currentReaderJava?.stopLoading()
        
        // Cancel the current task but keep it in queue for resuming
        if let currentTask = currentTask {
            // Reset the current task status to queued so it can be resumed later
            if let index = downloadQueue.firstIndex(where: { $0.id == currentTask.id }) {
                var updatedTask = downloadQueue[index]
                updatedTask.status = .queued
                updatedTask.progress = 0.1 // Keep at 10% when paused
                updatedTask.estimatedTimeRemaining = nil
                downloadQueue[index] = updatedTask
            }
            self.currentTask = nil
        }
        
        // CRITICAL: Notify ReaderViewJava to stop extraction
        NotificationCenter.default.post(name: .downloadsPaused, object: nil)
        
        saveDownloadState()
    }
    
    func resumeAllDownloads() {
        guard isPaused else { return } // Already running
        
        isPaused = false
        
        // CRITICAL: Notify ReaderViewJava that downloads can resume
        NotificationCenter.default.post(name: .downloadsResumed, object: nil)
        
        if !downloadQueue.isEmpty && !isDownloading {
            startNextDownload()
        }
    }
    
    func toggleDownloads() {
        if isPaused {
            resumeAllDownloads()
        } else {
            stopAllDownloads()
        }
    }
    
    // Get the appropriate button icon
    var pauseResumeIcon: String {
        if isPaused {
            return "play.fill"
        } else {
            return "pause.fill"
        }
    }
    
    // Get the appropriate button color
    var pauseResumeColor: Color {
        if isPaused {
            return .green
        } else {
            return .red
        }
    }
    
    // MARK: - Private Methods
    
    private func startNextDownload() {
        guard !isDownloading && !isPaused,
              let nextTaskIndex = downloadQueue.firstIndex(where: { $0.status == .queued }) else {
            return
        }
        
        isDownloading = true
        var task = downloadQueue[nextTaskIndex]
        task.status = .downloading
        task.startTime = Date()
        task.progress = 0.1 // Start at 10% when initiated
        downloadQueue[nextTaskIndex] = task
        currentTask = task
        
        // Create new ReaderViewJava for this download
        currentReaderJava = ReaderViewJava()
        
        // Store the async task so we can cancel it
        currentDownloadTask = Task {
            await downloadChapter(task: task)
        }
    }
    
    private func downloadChapter(task: DownloadTask) async {
        // Check for cancellation at the start
        if Task.isCancelled || isPaused {
            return
        }
        
        guard let url = URL(string: task.chapter.url),
              let readerJava = currentReaderJava else {
            markDownloadFailed(task: task, error: "Invalid URL or reader initialization failed")
            return
        }
        
        do {
            // Load chapter images
            readerJava.clearCache()
            readerJava.loadChapter(url: url)
            
            // Wait for images to load with cancellation support
            var attempts = 0
            while readerJava.isLoading && attempts < 180 {
                // Check for cancellation
                if Task.isCancelled || isPaused {
                    readerJava.stopLoading()
                    return
                }
                
                // Update progress based on download progress text
                updateProgressBasedOnStatus(readerJava: readerJava, task: task)
                
                try await Task.sleep(nanoseconds: 1_000_000_000)
                attempts += 1
                
                if readerJava.images.count > 0 && attempts > 30 {
                    break
                }
            }
            
            // Check for cancellation after loading
            if Task.isCancelled || isPaused {
                readerJava.stopLoading()
                return
            }
            
            // Check if we have images
            if readerJava.images.isEmpty {
                markDownloadFailed(task: task, error: readerJava.error ?? "No images found after \(attempts) seconds")
                return
            }
            
            let totalImages = readerJava.images.count
            
            // Check if we have minimum required images
            if totalImages < MINIMUM_IMAGES_REQUIRED {
                markDownloadFailed(task: task, error: "Insufficient images found (\(totalImages) of \(MINIMUM_IMAGES_REQUIRED) minimum required)")
                return
            }
            
            // Download images with cancellation support
            var downloadedImages: [UIImage] = []
            var totalSize: Int64 = 0
            var failedDownloads = 0
            
            for (index, image) in readerJava.images.enumerated() {
                // Check for cancellation frequently
                if Task.isCancelled || isPaused {
                    return
                }
                
                let imageProgress = 0.5 + (Double(index + 1) / Double(totalImages)) * 0.5
                updateDownloadProgress(taskId: task.id, progress: imageProgress)
                
                // Add small delay to avoid overwhelming the system
                try await Task.sleep(nanoseconds: 50_000_000)
                
                // Check cancellation again after sleep
                if Task.isCancelled || isPaused {
                    return
                }
                
                // Validate image
                if image.size.width > 10 && image.size.height > 10 {
                    downloadedImages.append(image)
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        totalSize += Int64(imageData.count)
                    }
                    print("Downloaded image \(index + 1)/\(totalImages) for chapter \(task.chapter.formattedChapterNumber)")
                } else {
                    failedDownloads += 1
                    print("Skipping invalid image \(index + 1) for chapter \(task.chapter.formattedChapterNumber)")
                }
            }
            
            // Final cancellation check before saving
            if Task.isCancelled || isPaused {
                return
            }
            
            // Check if we still have minimum required images after filtering
            if downloadedImages.count < MINIMUM_IMAGES_REQUIRED {
                markDownloadFailed(task: task, error: "Insufficient valid images after filtering (\(downloadedImages.count) of \(MINIMUM_IMAGES_REQUIRED) minimum required)")
                return
            }
            
            // Save chapter to storage
            saveDownloadedChapter(task: task, images: downloadedImages, totalSize: totalSize)
            
        } catch {
            // If the error is cancellation, don't mark as failed
            if error is CancellationError || isPaused {
                return
            }
            markDownloadFailed(task: task, error: error.localizedDescription)
        }
    }
    
    private func updateProgressBasedOnStatus(readerJava: ReaderViewJava, task: DownloadTask) {
        let progressText = readerJava.downloadProgress
        
        // Update progress based on the current stage
        var progress: Double = 0.1 // Start at 10%
        
        if progressText.contains("DOWNLOAD") || progressText.contains("Downloading") {
            progress = 0.5
        } else if progressText.contains("Starting extraction") || progressText.contains("Strategy") {
            progress = 0.2
        } else if progressText.contains("Processing") || progressText.contains("Sorting") {
            progress = 0.3
        } else if progressText.contains("Extraction completed") && !readerJava.images.isEmpty {
            progress = 0.4 // Images found, ready to download
        } else if progressText.contains("Attempt") || progressText.contains("RETRY") {
            progress = 0.15
        }
        
        // If we have images but progress is still low, bump it up to indicate progress
        if !readerJava.images.isEmpty && progress < 0.4 && !progressText.contains("DOWNLOAD") && !progressText.contains("Downloading") {
            progress = max(progress, 0.4)
        }
        
        updateDownloadProgress(taskId: task.id, progress: progress)
    }
    
    private func updateDownloadProgress(taskId: UUID, progress: Double) {
        if let index = self.downloadQueue.firstIndex(where: { $0.id == taskId }) {
            // Create a new task with updated progress
            var updatedTask = self.downloadQueue[index]
            updatedTask.progress = progress
            
            // Calculate estimated time remaining
            let elapsedTime = Date().timeIntervalSince(updatedTask.startTime)
            if progress > 0.1 { // Only calculate ETA after initial 10%
                let totalEstimatedTime = elapsedTime / (progress - 0.1) * 0.9 // Adjust for starting at 10%
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
            
            // FIX: Save images with sequential numbering starting from 0
            for (index, image) in images.enumerated() {
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    // Use sequential numbering: 0.jpg, 1.jpg, 2.jpg, etc.
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
                "downloadDate": Date().timeIntervalSince1970,
                "minimumImagesRequired": MINIMUM_IMAGES_REQUIRED
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
            self.currentReaderJava = nil
            self.isDownloading = false
            self.saveDownloadState()
            
            print("Download failed for chapter \(task.chapter.formattedChapterNumber): \(error)")
            
            // Start next download only if not paused
            if !self.isPaused {
                self.startNextDownload()
            }
        }
    }
    
    private func markDownloadCompleted(task: DownloadTask, fileSize: Int64) {
        if let index = self.downloadQueue.firstIndex(where: { $0.id == task.id }) {
            var completedTask = self.downloadQueue[index]
            completedTask.status = .completed
            completedTask.progress = 1.0
            completedTask.fileSize = fileSize // Set the file size here
            
            self.downloadQueue.remove(at: index)
            self.completedDownloads.insert(completedTask, at: 0) // Add to the beginning of the array
            
            // Update chapter status in title
            self.updateChapterDownloadStatus(chapterId: task.chapter.id, isDownloaded: true, fileSize: fileSize)
            
            self.currentTask = nil
            self.currentReaderJava = nil
            self.isDownloading = false
            self.saveDownloadState()
                        
            // Start next download only if not paused
            if !self.isPaused {
                self.startNextDownload()
            }
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
