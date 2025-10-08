//
//  ChapterExtractionManager.swift
//  MangaDen
//
//  Created by Brody Wells on 10/7/25.
//

import WebKit

class ChapterExtractionManager {
    
    // MARK: - Chapter Extraction
    
    // Function to find chapter links with enhanced pattern matching and table date detection
    static func findChapterLinks(in webView: WKWebView, completion: @escaping ([String: [String: String]]?) -> Void) {
        let javascript = ChapterExtractionJavaScript.getChapterExtractionScript()
        
        webView.evaluateJavaScript(javascript) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error finding chapter links: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                if let chapterDict = result as? [String: [String: String]] {
                    self.processAndSaveChapters(chapterDict, completion: completion)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    // Process found chapters and save to JSON
    private static func processAndSaveChapters(_ chapterDict: [String: [String: String]], completion: @escaping ([String: [String: String]]?) -> Void) {
        // Convert string keys to doubles for sorting
        let sortedChapters = chapterDict
            .compactMap { key, value -> (Double, String, [String: String])? in
                guard let number = Double(key) else { return nil }
                return (number, key, value)
            }
            .sorted { $0.0 > $1.0 } // Changed to descending order
            .map { ($0.1, $0.2) } // Convert back to original string keys
        
        // Create final dictionary with sorted chapters
        var sortedDict: [String: [String: String]] = [:]
        for (key, value) in sortedChapters {
            sortedDict[key] = value
        }
        
        // Save to JSON file
        saveChaptersToJSON(sortedDict)
        completion(sortedDict)
    }
    
    // Save chapters to JSON file with proper ordering
    static func saveChaptersToJSON(_ chapters: [String: [String: String]]) {
        do {
            // Convert to array of objects with chapter number for proper ordering
            let sortedChapters = chapters
                .compactMap { key, value -> (Double, [String: Any])? in
                    guard let number = Double(key) else { return nil }
                    // Convert [String: String] to [String: Any] to allow mixed types
                    var chapterDict: [String: Any] = [:]
                    for (k, v) in value {
                        chapterDict[k] = v
                    }
                    chapterDict["chapter_number"] = number
                    return (number, chapterDict)
                }
                .sorted { $0.0 > $1.0 } // Sort in descending order
                .map { $0.1 } // Extract the chapter dictionary
            
            let jsonData = try JSONSerialization.data(withJSONObject: sortedChapters, options: [.prettyPrinted])
            
            // Get documents directory
            if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsDirectory.appendingPathComponent("chapters.json")
                
                try jsonData.write(to: fileURL)
                print("Chapters saved to: \(fileURL.path)")
            }
        } catch {
            print("Error saving chapters to JSON: \(error.localizedDescription)")
        }
    }
    
    // Add a helper function to extract just URLs for backward compatibility
    static func extractURLs(from chapterDict: [String: [String: String]]) -> [String: String] {
        var urlDict: [String: String] = [:]
        for (key, value) in chapterDict {
            if let url = value["url"] {
                urlDict[key] = url
            }
        }
        return urlDict
    }
}
