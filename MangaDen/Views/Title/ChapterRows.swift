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
    let titleID: UUID
    
    @StateObject private var downloadManager = DownloadManager.shared
    
    @AppStorage("accentColor") private var accentColor: String = "systemBlue"
        
    // Get current accent color
    private var currentAccentColor: Color {
        Color.fromStorage(accentColor)
    }
    
    private var isInQueue: Bool {
        downloadManager.downloadQueue.contains { $0.chapter.id == chapter.id }
    }
    
    private var isDownloaded: Bool {
        chapter.safeIsDownloaded
    }
    
    var body: some View {
        HStack {
            if showDownloadMode {
                Button(action: onDownload) {
                    if !isDownloaded && !isInQueue {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(currentAccentColor)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isDownloaded || isInQueue)
            }
            
            if showManageMode {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            NavigationLink(
                destination: ReaderView(chapter: chapter, readingDirection: readingDirection, titleID: titleID)
            ) {
                ChapterRowContent(
                    chapter: chapter,
                    showDownloadButton: showDownloadMode,
                    showManageMode: showManageMode
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .id(chapter.id)
        }
        .padding(.leading, 20)
    }
}


// MARK: - Chapter Row Content
struct ChapterRowContent: View {
    let chapter: Chapter
    let showDownloadButton: Bool
    let showManageMode: Bool
    
    @StateObject private var downloadManager = DownloadManager.shared
    
    @AppStorage("accentColor") private var accentColor: String = "systemBlue"
        
    // Get current accent color
    private var currentAccentColor: Color {
        Color.fromStorage(accentColor)
    }
    
    private var isInQueue: Bool {
        downloadManager.downloadQueue.contains { $0.chapter.id == chapter.id }
    }
    
    private var isDownloaded: Bool {
        chapter.safeIsDownloaded
    }
    
    // Format the date to uniform "MMM d, yyyy" format
    private var formattedUploadDate: String? {
        guard let uploadDateString = chapter.uploadDate else { return nil }
        
        let inputFormatters = [
            createDateFormatter(format: "MM/dd/yyyy"),
            createDateFormatter(format: "MM/dd/yy"),
            createDateFormatter(format: "MMM d, yyyy"),
            createDateFormatter(format: "MMMM d, yyyy")
        ]
        
        // Try to parse the date with any format
        for formatter in inputFormatters {
            if let date = formatter.date(from: uploadDateString) {
                // Format to uniform output format
                let outputFormatter = DateFormatter()
                outputFormatter.dateFormat = "MMM d, yyyy"
                return outputFormatter.string(from: date)
            }
        }
        
        // If we can't parse it, return the original string
        return uploadDateString
    }
    
    // Check if chapter is recently uploaded (within 10 days)
    private var isRecentlyUploaded: Bool {
        guard let uploadDateString = chapter.uploadDate else { return false }
        
        let inputFormatters = [
            createDateFormatter(format: "MM/dd/yyyy"),
            createDateFormatter(format: "MM/dd/yy"),
            createDateFormatter(format: "MMM d, yyyy"),
            createDateFormatter(format: "MMMM d, yyyy")
        ]
        
        // Try all date formatters
        for formatter in inputFormatters {
            if let uploadDate = formatter.date(from: uploadDateString) {
                let calendar = Calendar.current
                let currentDate = Date()
                
                if let daysDifference = calendar.dateComponents([.day], from: uploadDate, to: currentDate).day {
                    return daysDifference <= 10 && daysDifference >= 0 // 10 DAYS for NEW
                }
            }
        }
        
        return false
    }
    
    private func createDateFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX") // Ensure consistent parsing
        return formatter
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
                            .foregroundColor(chapter.safeIsRead ? .gray : .primary)
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.light)
                            .foregroundColor(chapter.safeIsRead ? .gray : .primary)
                    }
                } else {
                    Text("Chapter \(chapter.formattedChapterNumber)")
                        .font(.subheadline)
                        .tracking(2.0)
                        .lineLimit(1)
                        .fontWeight(.medium)
                        .foregroundColor(chapter.safeIsRead ? .gray : .primary)
                }
                
                // Upload date on second line - now using formatted date
                if let formattedDate = formattedUploadDate {
                    HStack(spacing: 6) {
                        
                        // "NEW" indicator if recently uploaded
                        if isRecentlyUploaded {
                            Text("NEW")
                                .font(.footnote)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                        // Chapter upload date
                        Text(formattedDate)
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        
                    }
                    .padding(.leading, showDownloadButton ? 0 : 20)
                    .padding(.top, 5)
                }
            }
            
            Spacer()
            
            if chapter.safeIsBookmarked {
                Image(systemName: "bookmark.fill")
                    .font(.title2)
                    .foregroundColor(currentAccentColor)
            }
            
            Spacer()
            
            if isInQueue {
                ProgressView()
                    .scaleEffect(0.8)
            } else if isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
            }
                        
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .padding()
        .contentShape(Rectangle())
    }
}

#Preview {
    ContentView()
}
