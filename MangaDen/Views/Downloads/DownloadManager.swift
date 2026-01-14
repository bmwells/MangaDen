//
//  DownloadManager.swift
//  MangaDen
//
//  Created by Brody Wells on 9/26/25.
//  — Fixed by ChatGPT: improved lifecycle coordination with ReaderViewJava to prevent
//    duplicate extractions, premature cancellations, and false failures.
//

import SwiftUI
import Foundation
import UIKit
import Combine

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
    
    // ReaderViewJava instance for progress tracking & extraction
    private var currentReaderJava: ReaderViewJava?
    
    // MINIMUM_IMAGES_REQUIRED for download
    private let MINIMUM_IMAGES_REQUIRED = 9
    
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
        
        // Only start downloading if this is the FIRST chapter added to an empty queue
        // and not already downloading and not paused
        if !isDownloading && !isPaused && downloadQueue.count == 1 {
            print("DownloadManager: First chapter added to empty queue, starting download automatically")
            startNextDownload()
        }
    }
    
    func downloadAllChapters(chapters: [Chapter], titleId: UUID) {
        // Load hidden chapters for this title
        let hiddenKey = "hiddenChapters_\(titleId.uuidString)"
        let hiddenChapterURLs = UserDefaults.standard.array(forKey: hiddenKey) as? [String] ?? []
        
        var chaptersAdded = 0
        var eligibleChapters: [Chapter] = []
        
        // First, collect eligible chapters
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
            
            eligibleChapters.append(chapter)
        }
        
        // Sort chapters by chapter number (oldest first)
        let sortedChapters = eligibleChapters.sorted { $0.chapterNumber < $1.chapterNumber }
        
        // Add sorted chapters to queue
        for chapter in sortedChapters {
            let task = DownloadTask(chapter: chapter)
            downloadQueue.append(task)
            chaptersAdded += 1
        }
        
        saveDownloadState()
        
        // Only start downloading if chapters were added to an EMPTY queue
        // and not already downloading and not paused
        if chaptersAdded > 0 {
            if !isDownloading && !isPaused && downloadQueue.count == chaptersAdded {
                startNextDownload()
            }
        }
    }
    
    func cancelDownload(chapterId: UUID) {
        if let index = downloadQueue.firstIndex(where: { $0.chapter.id == chapterId }) {
            downloadQueue.remove(at: index)
            saveDownloadState()
            
            // Update chapter status in title
            updateChapterDownloadStatus(chapterId: chapterId, isDownloaded: false)
        }
        
        // If this was the current task, stop the extraction
        if currentTask?.chapter.id == chapterId {
            print("DownloadManager: Cancelling current download task for chapter \(chapterId)")
            
            // 1. Cancel the current download task
            currentDownloadTask?.cancel()
            currentDownloadTask = nil
            
            // 2. Stop ALL ReaderViewJava operations (robust cleanup)
            currentReaderJava?.stopLoading()
            currentReaderJava?.clearCache()
            currentReaderJava = nil
            
            // 3. Reset downloading state
            isDownloading = false
            currentTask = nil
            
            print("DownloadManager: Current download task fully cancelled")
            
            // Only start next download if not paused and queue not empty
            if !isPaused && !downloadQueue.isEmpty {
                // Add a longer delay to ensure everything is fully stopped
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("DownloadManager: Starting next download after cancellation")
                    self.startNextDownload()
                }
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
        
        // Stop the current reader robustly
        currentReaderJava?.stopLoading()
        currentReaderJava?.clearCache()
        
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
        
        // Ensure previous reader is fully cleaned up
        if currentReaderJava != nil {
            currentReaderJava?.stopLoading()
            currentReaderJava?.clearCache()
            currentReaderJava = nil
        }
        
        // Add a small delay to ensure cleanup
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 second delay
            
            await MainActor.run {
                guard !self.isDownloading && !self.isPaused else { return }
                
                self.isDownloading = true
                var task = self.downloadQueue[nextTaskIndex]
                task.status = .downloading
                task.startTime = Date()
                task.progress = 0.1
                self.downloadQueue[nextTaskIndex] = task
                self.currentTask = task
                
                // Create new ReaderViewJava for this download
                self.currentReaderJava = ReaderViewJava()
                
                // Store the async task
                self.currentDownloadTask = Task { [weak self] in
                    guard let self = self else { return }
                    await self.downloadChapter(task: task)
                }
            }
        }
    }
    
    private func downloadChapter(task: DownloadTask) async {
        print("DownloadManager: Starting download for chapter \(task.chapter.formattedChapterNumber)")
        
        // Quick guard for cancellation/paused
        guard !Task.isCancelled && !isPaused else {
            print("DownloadManager: Task cancelled or paused before starting")
            return
        }
        
        guard let url = URL(string: task.chapter.url) else {
            markDownloadFailed(task: task, error: "Invalid URL")
            return
        }
        
        // Initialize reader
        guard let readerJava = currentReaderJava else {
            markDownloadFailed(task: task, error: "Reader initialization failed")
            return
        }
        
        // A flag to indicate this block is the active downloader (for defer cleanup)
        var isCurrentlyDownloading = true
        
        // Defer cleanup: ALWAYS attempt to stop & clear the ReaderViewJava so it doesn't continue extracting
        defer {
            if isCurrentlyDownloading {
                // Best-effort graceful shutdown of reader
                readerJava.stopLoading()
                readerJava.clearCache()
                
                // Ensure manager references are cleared only if they still point to this reader
                if self.currentReaderJava === readerJava {
                    self.currentReaderJava = nil
                }
                
                self.currentTask = nil
                self.isDownloading = false
            }
        }
        
        do {
            // Prepare reader
            readerJava.clearCache()
            readerJava.loadChapter(url: url)
            
            // Wait for images to load with cancellation support
            let imagesLoaded = await waitForImagesToLoad(readerJava: readerJava, task: task)
            
            // Check for cancellation after loading
            if Task.isCancelled || isPaused {
                isCurrentlyDownloading = false
                readerJava.stopLoading()
                readerJava.clearCache()
                return
            }
            
            if !imagesLoaded {
                markDownloadFailed(task: task, error: readerJava.error ?? "Failed to load sufficient images (\(readerJava.images.count) of \(MINIMUM_IMAGES_REQUIRED) required)")
                return
            }
            
            let totalImages = readerJava.images.count
            print("DownloadManager: Images loading completed. Count: \(totalImages)")
            
            // Check if we have minimum required images
            if totalImages < MINIMUM_IMAGES_REQUIRED {
                print("DownloadManager: INSUFFICIENT IMAGES - only \(totalImages) available, need \(MINIMUM_IMAGES_REQUIRED)")
                markDownloadFailed(task: task, error: "Insufficient images found (\(totalImages) of \(MINIMUM_IMAGES_REQUIRED) minimum required)")
                return
            }
            
            // Download images with cancellation support
            var downloadedImages: [UIImage] = []
            var totalSize: Int64 = 0
            var failedImages = 0
            
            for (index, image) in readerJava.images.enumerated() {
                // Check for cancellation frequently
                if Task.isCancelled || isPaused {
                    isCurrentlyDownloading = false
                    readerJava.stopLoading()
                    readerJava.clearCache()
                    return
                }
                
                let imageProgress = 0.5 + (Double(index + 1) / Double(totalImages)) * 0.5
                updateDownloadProgress(taskId: task.id, progress: imageProgress)
                
                // Add small delay to avoid overwhelming the system
                try await Task.sleep(nanoseconds: 25_000_000) // 25 ms
                
                // Validate image
                if image.size.width > 10 && image.size.height > 10 {
                    downloadedImages.append(image)
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        totalSize += Int64(imageData.count)
                    }
                    print("Downloaded image \(index + 1)/\(totalImages) for chapter \(task.chapter.formattedChapterNumber)")
                } else {
                    failedImages += 1
                }
            }
            
            // Final cancellation check before saving
            if Task.isCancelled || isPaused {
                isCurrentlyDownloading = false
                readerJava.stopLoading()
                readerJava.clearCache()
                return
            }
            
            // Check if we still have minimum required images after filtering
            if downloadedImages.count < MINIMUM_IMAGES_REQUIRED {
                markDownloadFailed(task: task, error: "Insufficient valid images after filtering (\(downloadedImages.count) of \(MINIMUM_IMAGES_REQUIRED) minimum required)")
                return
            }
            
            // Save chapter to storage
            saveDownloadedChapter(task: task, images: downloadedImages, totalSize: totalSize)
            
            // If we get here, markDownloadCompleted will be called from saveDownloadedChapter
            // Prevent deferred cleanup from nullifying state prematurely; mark that cleanup should still happen
            isCurrentlyDownloading = true
            
        } catch {
            // If the error is cancellation, don't mark as failed
            if error is CancellationError || isPaused {
                isCurrentlyDownloading = false
                readerJava.stopLoading()
                readerJava.clearCache()
                return
            }
            markDownloadFailed(task: task, error: error.localizedDescription)
            return
        }
    }
    
    // Waits for ReaderViewJava to populate its `images` array.
    // Returns true if at least MINIMUM_IMAGES_REQUIRED images were loaded before timeout/cancellation.
    private func waitForImagesToLoad(readerJava: ReaderViewJava, task: DownloadTask) async -> Bool {
        var attempts = 0
        let maxAttempts = 300 // 300 seconds total wait (1 second per attempt)
        
        while (readerJava.isLoading || readerJava.images.isEmpty) && attempts < maxAttempts {
            if Task.isCancelled || isPaused {
                return false
            }
            
            // Update progress using reader state
            updateProgressBasedOnStatus(readerJava: readerJava, task: task)
            
            // If we have enough images after a few seconds, proceed
            if readerJava.images.count >= MINIMUM_IMAGES_REQUIRED && attempts > 3 {
                print("DownloadManager: Sufficient images loaded (\(readerJava.images.count)), proceeding...")
                return true
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            attempts += 1
            
            if attempts % 30 == 0 {
                print("DownloadManager: Still waiting for images... attempt \(attempts), images count: \(readerJava.images.count)")
            }
        }
        
        return readerJava.images.count >= MINIMUM_IMAGES_REQUIRED
    }
    
    private func updateProgressBasedOnStatus(readerJava: ReaderViewJava, task: DownloadTask) {
        let progressText = readerJava.downloadProgress
        
        // Update progress based on the current stage
        var progress: Double = 0.1 // Start at 10%
        
        if progressText.localizedCaseInsensitiveContains("DOWNLOAD") || progressText.localizedCaseInsensitiveContains("Downloading") {
            progress = 0.5
        } else if progressText.localizedCaseInsensitiveContains("Starting extraction") || progressText.localizedCaseInsensitiveContains("Strategy") {
            progress = 0.2
        } else if progressText.localizedCaseInsensitiveContains("Processing") || progressText.localizedCaseInsensitiveContains("Sorting") {
            progress = 0.3
        } else if progressText.localizedCaseInsensitiveContains("Extraction completed") && !readerJava.images.isEmpty {
            progress = 0.4 // Images found, ready to download
        } else if progressText.localizedCaseInsensitiveContains("Attempt") || progressText.localizedCaseInsensitiveContains("RETRY") {
            progress = 0.15
        }
        
        // If we have images but progress is still low, bump it up to indicate progress
        if !readerJava.images.isEmpty && progress < 0.4 && !progressText.localizedCaseInsensitiveContains("DOWNLOAD") && !progressText.localizedCaseInsensitiveContains("Downloading") {
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
                let totalEstimatedTime = elapsedTime / max((progress - 0.1), 0.0001) * 0.9 // Adjust for starting at 10%
                updatedTask.estimatedTimeRemaining = max(totalEstimatedTime - elapsedTime, 0)
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
            // Create directory (remove existing temp directory if present to avoid stale files)
            if fileManager.fileExists(atPath: chapterDirectory.path) {
                try fileManager.removeItem(at: chapterDirectory)
            }
            try fileManager.createDirectory(at: chapterDirectory, withIntermediateDirectories: true)
            
            // Save images with sequential numbering starting from 0
            for (index, image) in images.enumerated() {
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    // Use sequential numbering: 0.jpg, 1.jpg, 2.jpg, etc.
                    let imagePath = chapterDirectory.appendingPathComponent("\(index).jpg")
                    try imageData.write(to: imagePath, options: .atomic)
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
            try infoData.write(to: infoPath, options: .atomic)
                        
            // Mark as completed
            self.markDownloadCompleted(task: task, fileSize: totalSize)
            
        } catch {
            self.markDownloadFailed(task: task, error: error.localizedDescription)
        }
    }

    private func markDownloadFailed(task: DownloadTask, error: String) {
        print("DownloadManager: Marking download FAILED for chapter \(task.chapter.formattedChapterNumber) - \(error)")
        
        // Attempt to gracefully stop reader if it belongs to this task
        currentReaderJava?.stopLoading()
        currentReaderJava?.clearCache()
        
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
                // Small delay to ensure cleanup propagation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.startNextDownload()
                }
            }
        } else {
            // If task not found in queue (maybe was being processed), ensure it's added to failed list
            var failedCopy = task
            failedCopy.status = .failed
            failedCopy.error = error
            self.failedDownloads.append(failedCopy)
            self.currentTask = nil
            self.currentReaderJava = nil
            self.isDownloading = false
            self.saveDownloadState()
            
            if !self.isPaused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.startNextDownload()
                }
            }
        }
    }
    
    private func markDownloadCompleted(task: DownloadTask, fileSize: Int64) {
        print("DownloadManager: Marking download completed for chapter \(task.chapter.formattedChapterNumber)")
        
        // Ensure reader is fully stopped and cleared to avoid any further extraction or timers
        currentReaderJava?.stopLoading()
        currentReaderJava?.clearCache()
        
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
                        
            print("DownloadManager: Download completed successfully for chapter \(task.chapter.formattedChapterNumber)")
            
            // Start next download only if not paused
            if !self.isPaused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.startNextDownload()
                }
            }
        } else {
            // If the task isn't in the queue (edge case), still append to completed
            var completedTask = task
            completedTask.status = .completed
            completedTask.progress = 1.0
            completedTask.fileSize = fileSize
            self.completedDownloads.insert(completedTask, at: 0)
            self.currentTask = nil
            self.currentReaderJava = nil
            self.isDownloading = false
            self.saveDownloadState()
            
            if !self.isPaused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.startNextDownload()
                }
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
                    print("DownloadManager: Error updating chapter status: \(error)")
                }
            }
        } catch {
            print("DownloadManager: Error accessing title files: \(error)")
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
            try data.write(to: stateFile, options: .atomic)
        } catch {
            print("DownloadManager: Error saving download state: \(error)")
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
            print("DownloadManager: Error loading download state: \(error)")
        }
    }
}
