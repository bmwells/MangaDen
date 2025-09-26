//
//  DownloadsView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI

struct DownloadsView: View {
    @StateObject private var downloadManager = DownloadManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Current Downloads Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Downloading")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !downloadManager.downloadQueue.isEmpty {
                            Button("Clear All") {
                                downloadManager.clearQueue()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        
                        Button(action: {
                            // Pause/Resume logic would go here
                        }) {
                            Image(systemName: downloadManager.isDownloading ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(Circle())
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
                                    DownloadTaskRow(task: task)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Completed Downloads Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Completed")
                            .font(.headline)
                        
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
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Failed Downloads Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Failed")
                            .font(.headline)
                        
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
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Downloads")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// Download Task Row Views
struct DownloadTaskRow: View {
    let task: DownloadTask
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chapter \(task.chapter.formattedChapterNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let title = task.chapter.title {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Progress bar
                ProgressView(value: task.progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 4)
                
                HStack {
                    Text("\(Int(task.progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let remaining = task.estimatedTimeRemaining, remaining > 0 {
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
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Chapter \(task.chapter.formattedChapterNumber)")
                    .font(.subheadline)
                
                if let title = task.chapter.title {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let fileSize = task.chapter.fileSize {
                    Text(formatFileSize(fileSize))
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
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        if size >= 1_000_000_000 {
            return String(format: "%.1f GB", Double(size) / 1_000_000_000.0)
        } else {
            return String(format: "%.0f MB", Double(size) / 1_000_000.0)
        }
    }
}

struct FailedDownloadRow: View {
    let task: DownloadTask
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Chapter \(task.chapter.formattedChapterNumber)")
                    .font(.subheadline)
                
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
    }
}
