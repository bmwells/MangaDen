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
                VStack(spacing: 20) {
                    // Current Downloads Section
                    VStack(alignment: .leading, spacing: 10) {
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
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(downloadManager.pauseResumeColor)
                                        .clipShape(Circle())
                                }
                            }
                            
                            Spacer()
                            
                            if !downloadManager.downloadQueue.isEmpty {
                                Button("Clear All") {
                                    clearQueueWithLoading()
                                }
                                .font(.caption)
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
                                LazyVStack(spacing: 12) {
                                    ForEach(downloadManager.downloadQueue) { task in
                                        DownloadTaskRow(task: task, isPaused: downloadManager.isPaused)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Completed Downloads Section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Completed")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if !downloadManager.completedDownloads.isEmpty {
                                Button("Clear All") {
                                    downloadManager.clearCompleted()
                                }
                                .font(.caption)
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
                                LazyVStack(spacing: 8) {
                                    ForEach(downloadManager.completedDownloads) { task in
                                        CompletedDownloadRow(task: task)
                                    }
                                }
                            }
                            .frame(maxHeight: 150)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Failed Downloads Section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Failed")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if !downloadManager.failedDownloads.isEmpty {
                                Button("Clear All") {
                                    downloadManager.clearFailed()
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }
                        
                        if downloadManager.failedDownloads.isEmpty {
                            Text("No failed downloads")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(downloadManager.failedDownloads) { task in
                                        FailedDownloadRow(task: task)
                                    }
                                }
                            }
                            .frame(maxHeight: 150)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
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
                        .frame(width: UIScreen.main.bounds.width * 0.6)
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
                        .frame(width: UIScreen.main.bounds.width * 0.6)
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
                        .frame(width: UIScreen.main.bounds.width * 0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.bottom, 20)
                    
                    // Tip
                    Text("Tip:")
                        .padding(-4)
                        .font(.title3)
                        .bold()
                        .underline()
                        .tracking(1.5)
                    Text("• Swipe down from the top of the page to exit pages such as this one or the In-App browser")
                }
                .padding()
            }
            .padding(15)
        }
    }
}

// Download Task Row Views
struct DownloadTaskRow: View {
    let task: DownloadTask
    let isPaused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Chapter \(task.chapter.formattedChapterNumber)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if isPaused && task.status == .downloading {
                        Image(systemName: "pause.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                if let title = task.chapter.title {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    
                    if let remaining = task.estimatedTimeRemaining, remaining > 0 && !isPaused {
                        Text("ETA: \(formatTime(remaining))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: timeInterval) ?? ""
    }
}

struct CompletedDownloadRow: View {
    let task: DownloadTask
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Chapter \(task.chapter.formattedChapterNumber)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                if let title = task.chapter.title {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Use the fileSize from the DownloadTask instead of the chapter
                if task.fileSize > 0 {
                    Text(formatFileSize(task.fileSize))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if let chapterFileSize = task.chapter.fileSize, chapterFileSize > 0 {
                    Text(formatFileSize(chapterFileSize))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("Completed")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
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
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Chapter \(task.chapter.formattedChapterNumber)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                if let title = task.chapter.title {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let error = task.error {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button("Retry") {
                DownloadManager.shared.retryDownload(chapterId: task.chapter.id)
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }
}

#Preview {
    DownloadsHelpView()
}
