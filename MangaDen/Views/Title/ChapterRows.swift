//
//  ChapterRows.swift
//  MangaDen
//
//  Created by Brody Wells on 10/1/25.
//

import SwiftUI

// MARK: - Chapter Row View
struct ChapterRowView: View {
    let chapter: Chapter
    let readingDirection: ReadingDirection
    let showDownloadMode: Bool
    let showManageMode: Bool
    let onDelete: () -> Void
    let onDownload: () -> Void
    let onRead: () -> Void
    
    @StateObject private var downloadManager = DownloadManager.shared
    
    private var isInQueue: Bool {
        downloadManager.downloadQueue.contains { $0.chapter.id == chapter.id }
    }
    
    private var isDownloaded: Bool {
        chapter.isDownloaded
    }
    
    var body: some View {
        HStack {
            if showDownloadMode {
                Button(action: onDownload) {
                    Image(systemName: isDownloaded || isInQueue ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(isDownloaded || isInQueue ? .green : .blue)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isDownloaded || isInQueue)
            }
            
            if showManageMode {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            NavigationLink(
                destination: ReaderView(chapter: chapter, readingDirection: readingDirection)
            ) {
                ChapterRowContent(
                    chapter: chapter,
                    showDownloadButton: showDownloadMode,
                    showManageMode: showManageMode
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(TapGesture().onEnded(onRead))
            .id(chapter.id)
        }
    }
}

// MARK: - Chapter Row Content
struct ChapterRowContent: View {
    let chapter: Chapter
    let showDownloadButton: Bool
    let showManageMode: Bool
    
    @StateObject private var downloadManager = DownloadManager.shared
    
    private var isInQueue: Bool {
        downloadManager.downloadQueue.contains { $0.chapter.id == chapter.id }
    }
    
    private var isDownloaded: Bool {
        chapter.isDownloaded
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Combined chapter number and title on first line
                if let title = chapter.title, !title.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(chapter.formattedChapterNumber):  ")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(chapter.isRead ? .gray : .primary)
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.light)
                            .foregroundColor(chapter.isRead ? .gray : .primary)
                    }
                } else {
                    Text("Chapter \(chapter.formattedChapterNumber)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(chapter.isRead ? .gray : .primary)
                }
                
                // Upload date on second line
                if let uploadDate = chapter.uploadDate, !uploadDate.isEmpty {
                    Text(uploadDate)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.leading, showDownloadButton ? 0 : 20)
                        .padding(.top, 5)
                }
            }
            
            Spacer()
            
            if isInQueue {
                ProgressView()
                    .scaleEffect(0.8)
            } else if isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .contentShape(Rectangle())
    }
}

// MARK: - Legacy Chapter Row (if still needed)
struct ChapterRow: View {
    let chapter: Chapter
    let showDownloadButton: Bool
    let onDownloadTapped: () -> Void
    
    @StateObject private var downloadManager = DownloadManager.shared
    
    private var isInQueue: Bool {
        downloadManager.downloadQueue.contains { $0.chapter.id == chapter.id }
    }
    
    private var isDownloaded: Bool {
        chapter.isDownloaded
    }
    
    var body: some View {
        HStack {
            if showDownloadButton {
                Button(action: onDownloadTapped) {
                    Image(systemName: isDownloaded || isInQueue ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(isDownloaded || isInQueue ? .green : .blue)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isDownloaded || isInQueue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Combined chapter number and title on first line
                if let title = chapter.title, !title.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(chapter.formattedChapterNumber):  ")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(chapter.isRead ? .gray : .primary)
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.light)
                            .foregroundColor(chapter.isRead ? .gray : .primary)
                    }
                } else {
                    Text("Chapter \(chapter.formattedChapterNumber)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(chapter.isRead ? .gray : .primary)
                }
                
                // Upload date on second line
                if let uploadDate = chapter.uploadDate, !uploadDate.isEmpty {
                    Text(uploadDate)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.leading, showDownloadButton ? 0 : 20)
                        .padding(.top, 5)
                }
            }
            
            Spacer()
            
            if isInQueue {
                ProgressView()
                    .scaleEffect(0.8)
            } else if isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .contentShape(Rectangle())
    }
}
