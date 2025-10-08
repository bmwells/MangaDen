//
//  ChapterDetectionManager.swift
//  MangaDen
//
//  Created by Brody Wells on 10/7/25.
//

import WebKit

class ChapterDetectionManager {
    
    // MARK: - Chapter Detection
    
    // Function to check for chapter word and alternatives
    static func checkForChapterWord(in webView: WKWebView, completion: @escaping (Bool) -> Void) {
        let javascript = """
        (function() {
            if (!document.body || !document.body.innerText) return false;
            
            // First, check for the specific site structure (div.flex.items-center with x-data)
            const chapterContainers = document.querySelectorAll('div.flex.items-center');
            for (let container of chapterContainers) {
                const xData = container.getAttribute('x-data');
                if (xData && xData.includes('new_chapter') && xData.includes('checkNewChapter')) {
                    const link = container.querySelector('a[href*="/chapters/"]');
                    if (link) {
                        return true;
                    }
                }
            }
            
            // Then check for general chapter patterns in text
            const text = document.body.innerText.toLowerCase();
            const patterns = [
                'chapter', 'chp', 'ch', 'chap',
                'issue', 'iss', 'is',
                'volume', 'vol', 'v',
                'episode', 'ep', 'eps',
                'part', 'pt'
            ];
            
            // Check for text patterns
            for (const pattern of patterns) {
                if (text.includes(pattern)) return true;
            }
            
            // Check for hashtag numbers
            if (/#\\d+/.test(text)) return true;
            
            // Check for links with /chapters/ in URL (specific to this site)
            const chapterLinks = document.querySelectorAll('a[href*="/chapters/"]');
            if (chapterLinks.length > 0) {
                return true;
            }
            
            return false;
        })();
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
    
    // Alternative approach: Find all potential chapter numbers
    static func findChapterNumbersProgrammatically(in webView: WKWebView, completion: @escaping ([Double]?) -> Void) {
        let javascript = """
        (function() {
            const text = document.body.innerText || '';
            const numbers = new Set();
            
            // Pattern to find numbers near chapter-related words
            const pattern = /(?:chapter|chp|ch|chap|issue|iss|is|volume|vol|v|episode|ep|eps|part|pt)[\\s:]*([\\d\\.]+)|#\\s*([\\d\\.]+)/gi;
            
            let match;
            while ((match = pattern.exec(text)) !== null) {
                const num = match[1] || match[2];
                if (num) {
                    numbers.add(parseFloat(num));
                }
            }
            
            return Array.from(numbers).sort((a, b) => a - b);
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
    
    // Function to find missing chapters
    static func findMissingChapters(foundChapters: [Double], expectedChapters: [Double]) -> [Double] {
        let foundSet = Set(foundChapters)
        return expectedChapters.filter { !foundSet.contains($0) }
    }
}
