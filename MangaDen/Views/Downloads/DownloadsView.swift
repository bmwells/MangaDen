//
//  DownloadsView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI

struct DownloadsView: View {
    @StateObject private var downloadManager = DownloadManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isClearingQueue = false
    @State private var showHelp = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 12) {
                    // Current Downloads Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Downloading")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Pause/Resume button - only show when there are downloads in queue
                            if !downloadManager.downloadQueue.isEmpty {
                                Button(action: {
                                    downloadManager.toggleDownloads()
                                }) {
                                    Image(systemName: downloadManager.pauseResumeIcon)
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(downloadManager.pauseResumeColor)
                                        .clipShape(Circle())
                                }
                            }
                            
                            Spacer()
                            
                            if !downloadManager.downloadQueue.isEmpty {
                                Button("Clear All") {
                                    clearQueueWithLoading()
                                }
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .disabled(isClearingQueue)
                            }
                        }
                        
                        if downloadManager.downloadQueue.isEmpty {
                            Text("No active downloads")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(downloadManager.downloadQueue) { task in
                                        DownloadTaskRow(task: task, isPaused: downloadManager.isPaused)
                                    }
                                }
                            }
                            .frame(maxHeight: 256)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Completed Downloads Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Completed")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if !downloadManager.completedDownloads.isEmpty {
                                Button("Clear All") {
                                    downloadManager.clearCompleted()
                                }
                                .font(.subheadline)
                                .foregroundColor(.red)
                            }
                        }
                        
                        if downloadManager.completedDownloads.isEmpty {
                            Text("No completed downloads")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 6) {
                                    ForEach(downloadManager.completedDownloads) { task in
                                        CompletedDownloadRow(task: task)
                                    }
                                }
                            }
                            .frame(maxHeight: 150)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Failed Downloads Section - Only show when there are failed downloads
                    if !downloadManager.failedDownloads.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Failed")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button("Clear All") {
                                    downloadManager.clearFailed()
                                }
                                .font(.subheadline)
                                .foregroundColor(.red)
                            }
                            
                            ScrollView {
                                LazyVStack(spacing: 6) {
                                    ForEach(downloadManager.failedDownloads) { task in
                                        FailedDownloadRow(task: task)
                                    }
                                }
                            }
                            .frame(maxHeight: 65)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, -30)
                .toolbar {
                    // Page title
                    ToolbarItem(placement: .principal) {
                        Text("Downloads")
                            .font(.largeTitle)
                            .bold()
                    }
                    
                    // Help button
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showHelp = true
                        }) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 22))
                                .foregroundColor(.blue)
                        }
                        .padding(.trailing, 10)
                    }
                }
                .background(Color(.systemGroupedBackground))
                .blur(radius: isClearingQueue ? 3 : 0)
                .allowsHitTesting(!isClearingQueue)
                
                // Loading Popup
                if isClearingQueue {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Clearing queue...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray2))
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showHelp) {
            DownloadsHelpView()
        }
    }
    
    private func clearQueueWithLoading() {
        isClearingQueue = true
        
        // Use a small delay to ensure the UI updates before the clearing operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            downloadManager.clearQueue()
            
            // Hide the loading popup after a brief delay to ensure the operation is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isClearingQueue = false
            }
        }
    }
}

// MARK: Downloads Help View
struct DownloadsHelpView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Downloads Guide
                    Text("Downloads Guide")
                        .font(.title)
                        .bold()
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    
                    Text("**Downloading Section**")
                        .font(.title2)
                        .underline()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Displays chapters currently being downloaded. Use the pause/resume button to temporarily stop or restart all active downloads. Cancel individual downloads with the 'Cancel' button, or remove the entire queue at once using 'Clear all'.")
                        .font(.system(size: 18))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tracking(1.0)
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: 400) // Changed from fixed width to maxWidth
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    
                    Text("**Completed Section**")
                        .font(.title2)
                        .underline()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Shows successfully downloaded chapters that are available for offline reading. Use the 'Clear all' button to clear the list of completed downloads.")
                        .font(.system(size: 18))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tracking(1.0)
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    
                    Text("**Failed Section**")
                        .font(.title2)
                        .underline()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Shows chapters that failed to download. Click the 'Retry' button to rerun the failed downloads individually. Use the 'Clear all' button to clear the list of failed downloads.")
                        .font(.system(size: 18))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tracking(1.0)
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.bottom, 20)
                    
                    // Tips
                    Text("Tips:")
                        .padding(-4)
                        .font(.title2)
                        .bold()
                        .underline()
                        .tracking(1.5)
                    Text("• If recently downloaded chapter is uninstalled, it must be cleared from the completed section in order to be downloaded again")
                        .font(.system(size: 18))
                        .tracking(1.0)
                    Text("• Swipe down from the top of the page to exit pages such as this one or the In-App browser")
                        .font(.system(size: 18))
                        .tracking(1.0)
                }
                .padding()
                .frame(maxWidth: .infinity) // Ensure content uses available width
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 20 : 15) // Only horizontal padding
            .frame(maxWidth: horizontalSizeClass == .regular ? 800 : .infinity) // Wider on iPad
        }
    }
}

// Load series title of chapter for view
private func loadSeriesTitle(for chapterId: UUID, completion: @escaping (String) -> Void) {
    Task {
        let seriesTitle = await findSeriesTitle(for: chapterId)
        DispatchQueue.main.async {
            completion(seriesTitle)
        }
    }
}

private func findSeriesTitle(for chapterId: UUID) async -> String {
    do {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return ""
        }
        
        let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
        let titleFiles = try fileManager.contentsOfDirectory(at: titlesDirectory, includingPropertiesForKeys: nil)
        
        for file in titleFiles where file.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: file)
                let title = try JSONDecoder().decode(Title.self, from: data)
                
                if title.chapters.contains(where: { $0.id == chapterId }) {
                    return title.title
                }
            } catch {
                print("Error loading title for chapter: \(error)")
            }
        }
    } catch {
        print("Error accessing title files: \(error)")
    }
    return ""
}


// Download Task Row Views
struct DownloadTaskRow: View {
    let task: DownloadTask
    let isPaused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var seriesTitle: String = ""
    @ObservedObject private var downloadManager = DownloadManager.shared // Use shared instance
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let title = task.chapter.title {
                        Text(title)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    if !seriesTitle.isEmpty {
                        Text(seriesTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    if isPaused && task.status == .downloading {
                        Image(systemName: "pause.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            
                
                // Progress bar
                if !isPaused || task.status != .downloading {
                    ProgressView(value: task.progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 4)
                } else {
                    // Show paused progress bar
                    ProgressView(value: task.progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        .frame(height: 4)
                }
                
                HStack {
                    if isPaused && task.status == .downloading {
                        Text("Paused")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        Text("\(Int(task.progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Replace ETA time with download progress text
                    if task.status == .downloading && !isPaused {
                        Text(getProgressText())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            
            Spacer()
            
            Button("Cancel") {
                DownloadManager.shared.cancelDownload(chapterId: task.chapter.id)
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 2, x: 0, y: 1)
        .onAppear {
            loadSeriesTitle(for: task.chapter.id) { title in
                seriesTitle = title
            }
        }
    }
    
    private func getProgressText() -> String {
        // Get the current download progress text from DownloadManager
        return downloadManager.getCurrentDownloadProgressText()
    }
}

struct CompletedDownloadRow: View {
    let task: DownloadTask
    @Environment(\.colorScheme) private var colorScheme
    @State private var seriesTitle: String = ""
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.body)
            
            VStack(alignment: .leading, spacing: 2) {
                
                // CHAPTER TITLE
                if let chapterTitle = task.chapter.title, !chapterTitle.isEmpty {
                    Text(chapterTitle)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                // SERIES TITLE AND FILE SIZE ON SAME LINE
                HStack(spacing: 4) {
                    if !seriesTitle.isEmpty {
                        Text(seriesTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    if !seriesTitle.isEmpty && (task.fileSize > 0 || task.chapter.fileSize ?? 0 > 0) {
                        Text(" - ")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if task.fileSize > 0 {
                        Text(formatFileSize(task.fileSize))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if let chapterFileSize = task.chapter.fileSize, chapterFileSize > 0 {
                        Text(formatFileSize(chapterFileSize))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 2, x: 0, y: 1)
        .onAppear {
            loadSeriesTitle(for: task.chapter.id) { title in
                seriesTitle = title
            }
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}


struct FailedDownloadRow: View {
    let task: DownloadTask
    @Environment(\.colorScheme) private var colorScheme
    @State private var seriesTitle: String = ""
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.body)
            
            VStack(alignment: .leading, spacing: 4) {
                // First line: Chapter number and series title
                HStack(spacing: 4) {
                    Text("Chapter \(task.chapter.formattedChapterNumber)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                        .frame(width: 8)
                                        
                    if !seriesTitle.isEmpty {
                        Text(seriesTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                            .lineLimit(1)
                    }
                }
                
                // Second line: Error message
                if let error = task.error {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            
            
            Spacer()
            
            Button("Retry") {
                DownloadManager.shared.retryDownload(chapterId: task.chapter.id)
            }
            .font(.body)
            .bold()
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 2, x: 0, y: 1)
        .onAppear {
            loadSeriesTitle(for: task.chapter.id) { title in
                seriesTitle = title
            }
        }
        
    }
    
    
}



#Preview {
    DownloadsHelpView()
}
