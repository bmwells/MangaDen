//
//  AddMangaJava.swift
//  MangaDen
//
//  Created by Brody Wells on 8/26/25.
//

import SwiftUI
import WebKit

class AddMangaJAVA {
    
    // Function to check for chapter word
    static func checkForChapterWord(in webView: WKWebView, completion: @escaping (Bool) -> Void) {
        let javascript = """
        // Check if document body exists and has content
        if (document.body && document.body.innerText) {
            document.body.innerText.toLowerCase().includes('chapter');
        } else {
            false;
        }
        """
        
        webView.evaluateJavaScript(javascript) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error checking for chapter: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                if let containsChapter = result as? Bool {
                    completion(containsChapter)
                } else {
                    completion(false)
                }
            }
        }
    }
    
    
    // Function to find chapter links with specific numbering patterns
    static func findChapterLinks(in webView: WKWebView, completion: @escaping ([String: [String: String]]?) -> Void) {
        let javascript = """
            (function() {
                // Get all anchor tags on the page
                const links = document.getElementsByTagName('a');
                const chapterLinks = {};
                const chapterPattern = /chapter\\s*[\\d\\.]+/i;
                
                for (let i = 0; i < links.length; i++) {
                    const link = links[i];
                    const text = link.textContent || link.innerText;
                    const href = link.href;
                    
                    if (text && chapterPattern.test(text.toLowerCase())) {
                        // Extract the chapter number
                        const match = text.match(/(\\d+(?:\\.\\d+)?)/);
                        if (match && match[1]) {
                            // Clean up the title (remove extra whitespace, trim)
                            const cleanTitle = text.trim().replace(/\\s+/g, ' ');
                            chapterLinks[match[1]] = {
                                "url": href,
                                "title": cleanTitle
                            };
                        }
                    }
                }
                
                return Object.keys(chapterLinks).length > 0 ? chapterLinks : null;
            })();
            """
        
        webView.evaluateJavaScript(javascript) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error finding chapter links: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                if let chapterDict = result as? [String: [String: String]] {
                    // Sort and save to JSON
                    self.processAndSaveChapters(chapterDict, completion: completion)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    // Alternative approach: Find all potential chapter numbers programmatically
    static func findChapterNumbersProgrammatically(in webView: WKWebView, completion: @escaping ([Double]?) -> Void) {
        let javascript = """
            (function() {
                // Get all text content
                const text = document.body.innerText || document.body.textContent || '';
                const chapterNumbers = new Set();
                
                // Pattern to match chapter numbers like "Chapter 1", "Chapter 1.5", etc.
                const pattern = /chapter\\s+(\\d+(?:\\.\\d+)?)/gi;
                let match;
                
                while ((match = pattern.exec(text)) !== null) {
                    const number = parseFloat(match[1]);
                    if (!isNaN(number)) {
                        chapterNumbers.add(number);
                    }
                }
                
                // Also check for links with chapter numbers
                const links = document.getElementsByTagName('a');
                for (let i = 0; i < links.length; i++) {
                    const linkText = (links[i].textContent || links[i].innerText || '').toLowerCase();
                    const linkMatch = linkText.match(/chapter\\s+(\\d+(?:\\.\\d+)?)/);
                    if (linkMatch) {
                        const number = parseFloat(linkMatch[1]);
                        if (!isNaN(number)) {
                            chapterNumbers.add(number);
                        }
                    }
                }
                
                return Array.from(chapterNumbers).sort((a, b) => a - b);
            })();
            """
        
        webView.evaluateJavaScript(javascript) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error finding chapter numbers: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                if let numbers = result as? [Double] {
                    completion(numbers)
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
    
    // Function to generate expected chapter numbers for validation
    static func generateExpectedChapterNumbers() -> [Double] {
        var chapters: [Double] = []
        
        // Generate numbers from 0.01 to 0.1 with 0.01 increments
        var current: Double = 0.01
        while current <= 0.1 {
            chapters.append(current)
            current += 0.01
            current = round(current * 100) / 100 // Prevent floating point errors
        }
        
        // Generate numbers from 0.2 to 1.0 with 0.1 increments
        current = 0.2
        while current <= 1.0 {
            chapters.append(current)
            current += 0.1
            current = round(current * 10) / 10
        }
        
        // Generate numbers from 2 to 10000 with 1 increments
        current = 2.0
        while current <= 10000.0 {
            chapters.append(current)
            current += 1.0
        }
        
        return chapters
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
    
    // Function to find missing chapters
    static func findMissingChapters(foundChapters: [Double], expectedChapters: [Double]) -> [Double] {
        let foundSet = Set(foundChapters)
        return expectedChapters.filter { !foundSet.contains($0) }
    }
    
    
} // AddMangaJAVA
