//
//  TitleRefreshManager.swift
//  MangaDen
//
//  Created by Brody Wells on 10/7/25.
//


import WebKit

class TitleRefreshManager {
    
    // MARK: - Refresh Title Logic
    
    enum RefreshResult {
        case success([Chapter])
        case failure(String)
    }

    // Add these functions to the AddTitleJAVA class
    static func refreshTitle(in webView: WKWebView, for title: Title, completion: @escaping (RefreshResult) -> Void) {
        // First force desktop view for consistent scraping
        WebViewUserAgentManager.forceDesktopView(in: webView) { success in
            guard success else {
                completion(.failure("Failed to load desktop view"))
                return
            }
            
            // Wait for DOM changes to take effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Find new chapter links
                ChapterExtractionManager.findChapterLinks(in: webView) { newChapterDict in
                    DispatchQueue.main.async {
                        if let newChapterDict = newChapterDict {
                            let newChapters = processNewChapters(newChapterDict, for: title)
                            completion(.success(newChapters))
                        } else {
                            completion(.failure("No chapters found"))
                        }
                    }
                }
            }
        }
    }

    private static func processNewChapters(_ newChapterDict: [String: [String: String]], for existingTitle: Title) -> [Chapter] {
        var newChapters: [Chapter] = []
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        
        let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
        let titleFile = titlesDirectory.appendingPathComponent("\(existingTitle.id.uuidString).json")
        
        // Convert new chapter dict to Chapter objects and filter out existing ones
        for (chapterNumber, chapterData) in newChapterDict {
            if let url = chapterData["url"],
               let title = chapterData["title"] {
                
                // Check if this chapter already exists by URL
                let existingChapter = existingTitle.chapters.first { $0.url == url }
                
                if existingChapter == nil {
                    // This is a new chapter
                    let newChapter = Chapter(
                        chapterNumber: Double(chapterNumber) ?? 0.0,
                        url: url,
                        title: title,
                        uploadDate: chapterData["upload_date"],
                        isDownloaded: false,
                        isRead: false
                    )
                    newChapters.append(newChapter)
                }
            }
        }
        
        // If we found new chapters, update the title file
        if !newChapters.isEmpty {
            do {
                var updatedTitle = existingTitle
                
                // Combine existing chapters with new chapters
                let allChapters = updatedTitle.chapters + newChapters
                
                // Sort all chapters by chapter number in descending order (newest first)
                updatedTitle.chapters = allChapters.sorted { $0.chapterNumber > $1.chapterNumber }
                
                let titleData = try JSONEncoder().encode(updatedTitle)
                try titleData.write(to: titleFile)
                
                print("Successfully updated title with \(newChapters.count) new chapters")
                
            } catch {
                print("Error saving updated title: \(error)")
            }
        }
        
        return newChapters
    }
}
