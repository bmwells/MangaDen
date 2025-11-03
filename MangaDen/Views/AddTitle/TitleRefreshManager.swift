//
//  TitleRefreshManager.swift
//  MangaDen
//
//  Created by Brody Wells on 10/7/25.
//

import WebKit

class TitleRefreshManager {
    // Add this to keep WebView references alive during refresh operations
    private static var activeWebViews: [WKWebView] = []
    
    // MARK: - Refresh Title Logic
    
    enum RefreshResult {
        case success([Chapter])
        case failure(String)
    }

    // Refresh Title
    static func refreshTitle(in webView: WKWebView, for title: Title, completion: @escaping (RefreshResult) -> Void) {
        
        // CRITICAL: Keep WebView alive by storing reference to prevent GPU process termination
        activeWebViews.append(webView)
        
        // Clean up after completion to prevent memory leaks
        let cleanup = {
            if let index = activeWebViews.firstIndex(where: { $0 == webView }) {
                activeWebViews.remove(at: index)
            }
        }
        
        // Force desktop user agent BEFORE any loading for consistent scraping
        WebViewUserAgentManager.setDesktopUserAgent(for: webView)
        
        // First force desktop view for consistent scraping
        WebViewUserAgentManager.forceDesktopView(in: webView) { success in
            guard success else {
                cleanup()
                completion(.failure("Failed to load desktop view"))
                return
            }
                        
            // INCREASED WAIT TIME for cellular networks and ensure WebView stays active
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { // Increased to 5.0 seconds
                
                // Add readiness check before extraction to ensure page is fully loaded
                checkWebViewReadiness(in: webView) { isReady in
                    guard isReady else {
                        cleanup()
                        completion(.failure("Page failed to load properly"))
                        return
                    }
                                        
                    // Use enhanced chapter extraction with retry capability
                    ChapterExtractionManager.findChapterLinksWithRetry(in: webView) { newChapterDict in
                        DispatchQueue.main.async {
                            cleanup() // Clean up after extraction is complete
                            
                            if let newChapterDict = newChapterDict {
                                let newChapters = processNewChapters(newChapterDict, for: title)
                                completion(.success(newChapters))
                            } else {
                                completion(.failure("No new chapters found"))
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - WebView Readiness Check
    
    private static func checkWebViewReadiness(in webView: WKWebView, completion: @escaping (Bool) -> Void) {
        let readinessScript = """
        (function() {
            return {
                readyState: document.readyState,
                bodyExists: !!document.body,
                bodyTextLength: document.body ? document.body.textContent.length : 0,
                title: document.title,
                url: window.location.href,
                chapterLinks: document.querySelectorAll('a[href*="chapter"]').length,
                anyLinks: document.querySelectorAll('a').length,
                loaded: true
            };
        })();
        """
        
        print("🔍 Checking WebView readiness...")
        
        webView.evaluateJavaScript(readinessScript) { result, error in
            if let error = error {
                completion(false)
                return
            }
            
            if let readinessInfo = result as? [String: Any] {
                let readyState = readinessInfo["readyState"] as? String
                let bodyExists = readinessInfo["bodyExists"] as? Bool
                let bodyTextLength = readinessInfo["bodyTextLength"] as? Int
                
                // More lenient criteria for readiness
                let isReady = readyState == "complete" && bodyExists == true && (bodyTextLength ?? 0) > 50
                
                completion(isReady)
            } else {
                completion(false)
            }
        }
    }
    
    // MARK: - Process New Chapters
    
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
                
            } catch {
                print("Error saving updated title: \(error)")
            }
        }
        
        return newChapters
    }
    
}
