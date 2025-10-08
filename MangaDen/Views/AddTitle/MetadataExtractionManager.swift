//
//  MetadataExtractionManager.swift
//  MangaDen
//
//  Created by Brody Wells on 10/7/25.
//

import WebKit

class MetadataExtractionManager {
    
    // MARK: - Metadata Extraction
    
    // Updated findMangaMetadata function to include title extraction
    static func findMangaMetadata(in webView: WKWebView, completion: @escaping ([String: Any]?) -> Void) {
        // First get current URL for title extraction
        let currentURL = webView.url?.absoluteString ?? ""
        
        // First force desktop view, then scrape
        WebViewUserAgentManager.forceDesktopView(in: webView) { success in
            guard success else {
                completion(nil)
                return
            }
            
            // Wait a moment for the DOM changes to take effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let javascript = MetadataExtractionJavaScript.getMetadataExtractionScript()
                
                webView.evaluateJavaScript(javascript) { result, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("Error finding manga metadata: \(error.localizedDescription)")
                            completion(nil)
                            return
                        }
                        
                        if var metadata = result as? [String: Any] {
                            // Prioritize URL-based title extraction
                            if let urlTitle = extractTitleFromURL(currentURL) {
                                metadata["title"] = urlTitle
                            }
                            
                            self.saveMangaMetadata(metadata)
                            completion(metadata)
                        } else {
                            completion(nil)
                        }
                    }
                }
            }
        }
    }
    
    // Add this function to extract title from URL
    static func extractTitleFromURL(_ url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              urlComponents.host != nil else {
            return nil
        }
        
        // Common manga/comic path patterns
        let patterns = [
            "/manga/", "/comic/", "/series/", "/title/", "/read/"
        ]
        
        // Find which pattern exists in the path
        var foundPattern: String?
        for pattern in patterns {
            if urlComponents.path.contains(pattern) {
                foundPattern = pattern
                break
            }
        }
        
        guard let pattern = foundPattern else {
            return nil
        }
        
        // Extract the title portion from the path
        if let range = urlComponents.path.range(of: pattern) {
            let titlePart = String(urlComponents.path[range.upperBound...])
            
            // Remove any file extensions and special characters
            let cleanedTitle = titlePart
                .replacingOccurrences(of: "[a-zA-Z]\\.[^.]*$", with: "", options: .regularExpression) // Remove single letter before extension
                .replacingOccurrences(of: "\\.[^.]*$", with: "", options: .regularExpression) // Remove file extension
                .replacingOccurrences(of: "-", with: " ") // Replace hyphens with spaces
                .replacingOccurrences(of: "_", with: " ") // Replace underscores with spaces
                .replacingOccurrences(of: "[0-9]", with: "", options: .regularExpression) // Remove numbers
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Capitalize first letter of each word
            let words = cleanedTitle.components(separatedBy: " ")
            let capitalizedWords = words.map { $0.capitalized }
            return capitalizedWords.joined(separator: " ")
        }
        
        return nil
    }
    
    // Save manga metadata to separate JSON file
    static func saveMangaMetadata(_ metadata: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted])
            
            // Get documents directory
            if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsDirectory.appendingPathComponent("manga_metadata.json")
                
                try jsonData.write(to: fileURL)
                print("Manga metadata saved to: \(fileURL.path)")
            }
        } catch {
            print("Error saving manga metadata to JSON: \(error.localizedDescription)")
        }
    }

    // Function to load manga metadata (for use in your views)
    static func loadMangaMetadata() -> [String: Any]? {
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent("manga_metadata.json")
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let metadata = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    return metadata
                } catch {
                    print("Error loading manga metadata: \(error.localizedDescription)")
                }
            }
        }
        return nil
    }
}
