//
//  AddMangaJava.swift
//  MangaDen
//
//  Created by Brody Wells on 8/26/25.
//

import SwiftUI
import WebKit

class AddMangaJAVA {
    
// Mobile/Desktop Views

    // Function to set desktop user agent for scraping
        static func setDesktopUserAgent(for webView: WKWebView) {
            let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
            webView.customUserAgent = desktopUserAgent
        }
        
        // Function to set mobile user agent for display
        static func setMobileUserAgent(for webView: WKWebView) {
            let mobileUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
            webView.customUserAgent = mobileUserAgent
        }
    
    // Function to check for chapter word and alternatives
    static func checkForChapterWord(in webView: WKWebView, completion: @escaping (Bool) -> Void) {
        let javascript = """
        (function() {
            if (!document.body || !document.body.innerText) return false;
            
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

// MARK: Find Chapter Number, Title, Date, and URL
    
    // Function to find chapter links with enhanced pattern matching and table date detection
    static func findChapterLinks(in webView: WKWebView, completion: @escaping ([String: [String: String]]?) -> Void) {
        let javascript = """
        (function() {
            const links = document.querySelectorAll('a');
            const chapterLinks = {};
            
            // Enhanced date patterns including M/DD/YYYY format
            const datePatterns = [
                /\\b\\d{1,2}\\/\\d{1,2}\\/\\d{4}\\b/, // M/DD/YYYY or MM/DD/YYYY
                /\\b\\d{1,2}\\/\\d{1,2}\\/\\d{2}\\b/, // M/DD/YY or MM/DD/YY
                /\\b\\d{1,2}[\\-]\\d{1,2}[\\-]\\d{4}\\b/, // MM-DD-YYYY, M-DD-YYYY
                /\\b\\d{4}[\\-]\\d{1,2}[\\-]\\d{1,2}\\b/, // YYYY-MM-DD
                /(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\s+\\d{1,2},?\\s+\\d{4}/i,
                /\\d{1,2}\\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\s+\\d{4}/i,
                /(?:today|yesterday)\\b/i
            ];
            
            // Pattern to exclude titles with numbers in parentheses (e.g., "Iron Man (2016)")
            const excludePattern = /\\(\\s*\\d{4}\\s*\\)|\\(\\s*\\d+\\s*\\)/;
            
            // Get current page URL to filter same-series chapters
            const currentUrl = window.location.href;
            let currentMangaId = null;
            
            // Extract manga ID from current URL (common patterns for manga sites)
            const urlPatterns = [
                /\\/manga\\/([^\\/]+)/,
                /\\/series\\/([^\\/]+)/,
                /\\/comic\\/([^\\/]+)/,
                /\\/title\\/([^\\/]+)/,
                /\\/read\\/([^\\/]+)/,
                /manga=([^&]+)/,
                /series=([^&]+)/,
                /comic=([^&]+)/
            ];
            
            for (const pattern of urlPatterns) {
                const match = currentUrl.match(pattern);
                if (match && match[1]) {
                    currentMangaId = match[1];
                    break;
                }
            }
            
            // If we can't extract a clean ID, use a simpler approach
            if (!currentMangaId) {
                // Use domain and path to create a base pattern
                const urlObj = new URL(currentUrl);
                const pathParts = urlObj.pathname.split('/').filter(part => part.length > 2);
                if (pathParts.length > 0) {
                    currentMangaId = pathParts[pathParts.length - 1];
                }
            }
            
            // First, check if there's a table with chapter/date structure
            const tableDateMap = findDatesInTables();
            
            for (let link of links) {
                const text = (link.textContent || link.innerText || '').trim();
                const href = link.href;
                
                if (!text || !href) continue;
                
                // Skip titles with numbers in parentheses (e.g., "Iron Man (2016)")
                if (excludePattern.test(text)) {
                    continue;
                }
                
                // Filter out links from different manga series
                if (currentMangaId) {
                    let isSameSeries = false;
                    
                    // Check if link href contains the current manga ID
                    if (href.includes(currentMangaId)) {
                        isSameSeries = true;
                    }
                    
                    // Additional checks for common URL patterns
                    if (!isSameSeries) {
                        // Check for similar URL structure
                        const linkUrlObj = new URL(href);
                        const currentUrlObj = new URL(currentUrl);
                        
                        // Same domain and similar path structure
                        if (linkUrlObj.hostname === currentUrlObj.hostname) {
                            const linkPathParts = linkUrlObj.pathname.split('/').filter(part => part.length > 2);
                            const currentPathParts = currentUrlObj.pathname.split('/').filter(part => part.length > 2);
                            
                            if (linkPathParts.length > 0 && currentPathParts.length > 0) {
                                // Check if last path segment is similar (common for chapter pages)
                                const lastLinkPart = linkPathParts[linkPathParts.length - 1];
                                const lastCurrentPart = currentPathParts[currentPathParts.length - 1];
                                
                                if (lastLinkPart && lastCurrentPart) {
                                    // Check for common prefixes or patterns
                                    const linkBase = lastLinkPart.replace(/[^a-z]/gi, '');
                                    const currentBase = lastCurrentPart.replace(/[^a-z]/gi, '');
                                    
                                    if (linkBase.length > 3 && currentBase.length > 3 &&
                                        (linkBase.includes(currentBase) || currentBase.includes(linkBase))) {
                                        isSameSeries = true;
                                    }
                                }
                            }
                        }
                    }
                    
                    if (!isSameSeries) {
                        continue; // Skip links from different series
                    }
                }
                
                // Try to extract chapter number with various patterns
                let chapterNumber = null;
                let cleanTitle = text; // Start with original text
                
                // Pattern 1: Chapter X, Issue X, Volume X, etc.
                const pattern1 = /(chapter|chp|ch|chap|issue|iss|is|volume|vol|v|episode|ep|eps|part|pt)[\\s:]*([\\d\\.]+)/i;
                let match1 = text.match(pattern1);
                if (match1 && match1[2]) {
                    chapterNumber = match1[2];
                    // Don't modify the title - keep the full original text
                }
                
                // Pattern 2: #X, #01, #001, etc.
                if (!chapterNumber) {
                    const pattern2 = /#\\s*([\\d\\.]+)/i;
                    let match2 = text.match(pattern2);
                    if (match2 && match2[1]) {
                        chapterNumber = match2[1];
                        // Don't modify the title - keep the full original text
                    }
                }
                
                // Pattern 3: Number at beginning or end (standalone numbers)
                if (!chapterNumber) {
                    const pattern3 = /^\\s*([\\d\\.]+)\\s*$|\\b([\\d\\.]+)\\s*(?:chapter|chp|ch|chap|issue|iss|is|volume|vol|v|episode|ep|eps|part|pt)\\b/i;
                    let match3 = text.match(pattern3);
                    if (match3 && (match3[1] || match3[2])) {
                        chapterNumber = match3[1] || match3[2];
                        // Don't modify the title - keep the full original text
                    }
                }
                
                // Pattern 4: Look for numbers in the text (fallback)
                if (!chapterNumber) {
                    const numberMatch = text.match(/\\b(\\d+(?:\\.\\d+)?)\\b/);
                    if (numberMatch) {
                        chapterNumber = numberMatch[1];
                        // Don't modify the title - keep the full original text
                    }
                }
                
                if (chapterNumber) {
                    // Extract upload date (but don't remove from title)
                    let uploadDate = null;
                    
                    // Check in the original text for dates (but don't modify title)
                    for (const pattern of datePatterns) {
                        const dateMatch = text.match(pattern);
                        if (dateMatch) {
                            uploadDate = dateMatch[0];
                            break;
                        }
                    }
                    
                    // If no date found, check table date map using link text or href
                    if (!uploadDate) {
                        uploadDate = findDateInTableMap(link, tableDateMap);
                    }
                    
                    // If still no date found, check nearby elements
                    if (!uploadDate) {
                        uploadDate = findDateInNearbyElements(link);
                    }
                    
                    // Clean the title by removing dates if they were accidentally included
                    let finalTitle = cleanTitle;
                    if (uploadDate && finalTitle.includes(uploadDate)) {
                        finalTitle = finalTitle.replace(uploadDate, '').trim();
                        // Clean up any leftover punctuation
                        finalTitle = finalTitle.replace(/^[\\s\\.,;:-]+|[\\s\\.,;:-]+$/g, '').trim();
                    }
                    
                    const chapterData = {
                        "url": href,
                        "title": finalTitle || text // Use the cleaned title or original
                    };
                    
                    if (uploadDate) {
                        chapterData["upload_date"] = uploadDate;
                    }
                    
                    chapterLinks[chapterNumber] = chapterData;
                }
            }
            
            function findDatesInTables() {
                const dateMap = new Map();
                const tables = document.querySelectorAll('table');
                
                for (let table of tables) {
                    const rows = table.querySelectorAll('tr');
                    for (let row of rows) {
                        const cells = row.querySelectorAll('td, th');
                        if (cells.length >= 2) {
                            const leftCell = cells[0];
                            const rightCell = cells[1];
                            
                            // Check if right cell contains a date
                            const rightText = (rightCell.textContent || '').trim();
                            let foundDate = null;
                            
                            for (const pattern of datePatterns) {
                                const dateMatch = rightText.match(pattern);
                                if (dateMatch) {
                                    foundDate = dateMatch[0];
                                    break;
                                }
                            }
                            
                            if (foundDate) {
                                // Check left cell for chapter link or text
                                const leftLinks = leftCell.querySelectorAll('a');
                                if (leftLinks.length > 0) {
                                    for (let link of leftLinks) {
                                        const linkText = (link.textContent || '').trim();
                                        const linkHref = link.href;
                                        if (linkText) {
                                            dateMap.set(linkText, foundDate);
                                            dateMap.set(linkHref, foundDate);
                                        }
                                    }
                                } else {
                                    const leftText = (leftCell.textContent || '').trim();
                                    if (leftText) {
                                        dateMap.set(leftText, foundDate);
                                    }
                                }
                            }
                        }
                    }
                }
                return dateMap;
            }
            
            function findDateInTableMap(link, tableDateMap) {
                const linkText = (link.textContent || '').trim();
                const linkHref = link.href;
                
                // Try exact matches first
                if (tableDateMap.has(linkText)) {
                    return tableDateMap.get(linkText);
                }
                if (tableDateMap.has(linkHref)) {
                    return tableDateMap.get(linkHref);
                }
                
                // Try partial matches for link text
                for (let [key, value] of tableDateMap.entries()) {
                    if (linkText.includes(key) || key.includes(linkText)) {
                        return value;
                    }
                }
                
                return null;
            }
            
            function findDateInNearbyElements(element) {
                // Check parent
                if (element.parentElement) {
                    const parentText = element.parentElement.textContent;
                    for (const pattern of datePatterns) {
                        const match = parentText.match(pattern);
                        if (match) return match[0];
                    }
                }
                
                // Check siblings
                let sibling = element.previousElementSibling;
                while (sibling) {
                    const siblingText = sibling.textContent;
                    for (const pattern of datePatterns) {
                        const match = siblingText.match(pattern);
                        if (match) return match[0];
                    }
                    sibling = sibling.previousElementSibling;
                }
                
                sibling = element.nextElementSibling;
                while (sibling) {
                    const siblingText = sibling.textContent;
                    for (const pattern of datePatterns) {
                        const match = siblingText.match(pattern);
                        if (match) return match[0];
                    }
                    sibling = sibling.nextElementSibling;
                }
                
                // Check parent's siblings (for table-like structures)
                if (element.parentElement) {
                    const parentSibling = element.parentElement.previousElementSibling;
                    if (parentSibling) {
                        const parentSiblingText = parentSibling.textContent;
                        for (const pattern of datePatterns) {
                            const match = parentSiblingText.match(pattern);
                            if (match) return match[0];
                        }
                    }
                    
                    const nextParentSibling = element.parentElement.nextElementSibling;
                    if (nextParentSibling) {
                        const nextParentSiblingText = nextParentSibling.textContent;
                        for (const pattern of datePatterns) {
                            const match = nextParentSiblingText.match(pattern);
                            if (match) return match[0];
                        }
                    }
                }
                
                return null;
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
                    self.processAndSaveChapters(chapterDict, completion: completion)
                } else {
                    completion(nil)
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
    
    
// Image, Author, and Status
    
    
    // Function to force desktop view using JavaScript
    static func forceDesktopView(in webView: WKWebView, completion: @escaping (Bool) -> Void) {
        let javascript = """
        (function() {
            // 1. Remove mobile-specific classes and attributes
            document.querySelector('html').classList.remove('mobile', 'ios', 'android');
            document.querySelector('body').classList.remove('mobile', 'ios', 'android');
            
            // 2. Remove viewport meta tag that forces mobile layout
            const viewportMeta = document.querySelector('meta[name="viewport"][content*="width=device-width"]');
            if (viewportMeta) {
                viewportMeta.remove();
            }
            
            // 3. Set desktop viewport
            const newViewport = document.createElement('meta');
            newViewport.name = 'viewport';
            newViewport.content = 'width=1200';
            document.head.appendChild(newViewport);
            
            // 4. Remove mobile navigation/headers if they exist
            const mobileElements = document.querySelectorAll([
                '.mobile-nav',
                '.mobile-menu',
                '[class*="mobile"]',
                '[id*="mobile"]',
                '.navbar-toggle',
                '.hamburger-menu'
            ].join(','));
            
            mobileElements.forEach(el => el.style.display = 'none');
            
            // 5. Show desktop elements that might be hidden
            const desktopElements = document.querySelectorAll([
                '.desktop-nav',
                '.desktop-menu',
                '[class*="desktop"]',
                '[id*="desktop"]',
                '.full-menu'
            ].join(','));
            
            desktopElements.forEach(el => el.style.display = 'block');
            
            // 6. Force full content expansion (common on mobile sites)
            const expandButtons = document.querySelectorAll([
                '.read-more',
                '.show-more',
                '.expand-content',
                '[onclick*="expand"]',
                '[onclick*="show"]'
            ].join(','));
            
            expandButtons.forEach(btn => {
                if (typeof btn.click === 'function') {
                    btn.click();
                }
            });
            
            return true;
        })();
        """
        
        webView.evaluateJavaScript(javascript) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error forcing desktop view: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                completion(true)
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
    
    
    

    // Updated findMangaMetadata function to include title extraction
    static func findMangaMetadata(in webView: WKWebView, completion: @escaping ([String: Any]?) -> Void) {
        // First get current URL for title extraction
        let currentURL = webView.url?.absoluteString ?? ""
        
        // First force desktop view, then scrape
        forceDesktopView(in: webView) { success in
            guard success else {
                completion(nil)
                return
            }
            
            // Wait a moment for the DOM changes to take effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let javascript = """
                (function() {
                    const metadata = {
                        "title": null,
                        "title_image": null,
                        "author": null,
                        "status": null
                    };
                    
                    // Function to find title in page elements
                    const findTitleInPage = () => {
                        // Try to find title in common elements
                        const titleSelectors = [
                            'h1', 'h2', '.title', '.manga-title', '.comic-title',
                            '.series-title', '.entry-title', '.name', '.heading'
                        ];
                        
                        for (const selector of titleSelectors) {
                            try {
                                const elements = document.querySelectorAll(selector);
                                for (let el of elements) {
                                    const text = (el.textContent || '').trim();
                                    if (text && text.length > 3) {
                                        return text;
                                    }
                                }
                            } catch (e) {
                                // Ignore selector errors
                            }
                        }
                        return null;
                    };
                    
                    // 1. Find title image - more comprehensive search
                    const findTitleImage = () => {
                        const images = document.querySelectorAll('img');
                        let bestImage = null;
                        let maxScore = 0;
                        
                        for (let img of images) {
                            if (img.naturalWidth < 100 || img.naturalHeight < 100) continue;
                            
                            const src = img.src || '';
                            const alt = (img.alt || '').toLowerCase();
                            const className = (img.className || '').toLowerCase();
                            const parentClassName = (img.parentElement?.className || '').toLowerCase();
                            const id = (img.id || '').toLowerCase();
                            
                            // Score based on likelihood of being cover image
                            let score = 0;
                            
                            // Content-based scoring
                            if (src.includes('cover')) score += 30;
                            if (src.includes('title')) score += 25;
                            if (alt.includes('cover')) score += 20;
                            if (alt.includes('title')) score += 15;
                            
                            // Class/ID based scoring
                            if (className.includes('cover')) score += 25;
                            if (className.includes('title')) score += 20;
                            if (id.includes('cover')) score += 20;
                            if (id.includes('title')) score += 15;
                            
                            // Structural scoring
                            if (img.closest('.cover-container, .manga-cover, .comic-cover')) score += 35;
                            if (img.closest('.header, .hero, .banner')) score += 20;
                            
                            // Size scoring
                            const area = img.naturalWidth * img.naturalHeight;
                            score += Math.min(area / 10000, 20); // Max 20 points for size
                            
                            if (score > maxScore) {
                                maxScore = score;
                                bestImage = src;
                            }
                        }
                        
                        return bestImage;
                    };
                    
                    metadata.title_image = findTitleImage();
                    
                    // 2. Enhanced author finding with multiple strategies
                    const findAuthor = () => {
                                const authorPatterns = [
                                    /Author(?:s|\\(s\\))?\\s*:\\s*([^\\n\\r<]+)/i,
                                    /Creator(?:s)?\\s*:\\s*([^\\n\\r<]+)/i,
                                    /Writer(?:s)?\\s*:\\s*([^\\n\\r<]+)/i,
                                    /By\\s*:\\s*([^\\n\\r<]+?(?=\\s*(?:Chapter|Vol|\\d{4}|$)))/i,
                                    /Written by\\s*:\\s*([^\\n\\r<]+)/i,
                                    /Story by\\s*:\\s*([^\\n\\r<]+)/i,
                                    
                                    /Author(?:s|\\(s\\))?\\s+([^\\n\\r<:<]+)/i,
                                    /Creator(?:s)?\\s+([^\\n\\r<:<]+)/i,
                                    /Writer(?:s)?\\s+([^\\n\\r<:<]+)/i,
                                    /By\\s+([^\\n\\r<:<]+?(?=\\s*(?:Chapter|Vol|\\d{4}|$)))/i,
                                    /Written by\\s+([^\\n\\r<:<]+)/i,
                                    /Story by\\s+([^\\n\\r<:<]+)/i,
                                    
                                    /\\bAuthor\\b[^:\\n\\r<]*([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)+)/,
                                    /\\bCreator\\b[^:\\n\\r<]*([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)+)/,
                                    /\\bWriter\\b[^:\\n\\r<]*([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)+)/
                                ];
                                
                                let colonMatches = [];
                                let nonColonMatches = [];
                                
                                const textContent = document.body.innerText || document.body.textContent || '';
                                for (let i = 0; i < authorPatterns.length; i++) {
                                    const pattern = authorPatterns[i];
                                    const match = textContent.match(pattern);
                                    if (match && match[1]) {
                                        let author = match[1].trim()
                                            .replace(/\\([^)]+\\)/g, '')
                                            .replace(/\\s*,\\s*.*$/, '')
                                            .replace(/\\s+and\\s+.*$/i, '')
                                            .replace(/\\s*\\bet al\\b.*$/i, '')
                                            .replace(/^\\s*[,-]\\s*/, '')
                                            .replace(/[,-]\\s*$/, '')
                                            .trim();
                                        
                                        if (author.length > 3) {
                                            if (i < 6) {
                                                colonMatches.push(author);
                                            } else {
                                                nonColonMatches.push(author);
                                            }
                                        }
                                    }
                                }
                                
                                if (colonMatches.length > 0) {
                                    return colonMatches[0];
                                }
                                
                                const authorSelectors = [
                                    'td:contains("Author:")',
                                    'td:contains("Creator:")',
                                    'th:contains("Author:")',
                                    'th:contains("Creator:")',
                                    '[class*="author" i]',
                                    '[id*="author" i]',
                                    '[class*="creator" i]',
                                    '[id*="creator" i]',
                                    '.author-name',
                                    '.creator-name',
                                    '.manga-author',
                                    '.comic-author',
                                    '.writer',
                                    '.artist',
                                    '.credit'
                                ];
                                
                                let colonElementMatches = [];
                                let nonColonElementMatches = [];
                                
                                for (const selector of authorSelectors) {
                                    try {
                                        const elements = document.querySelectorAll(selector);
                                        for (let el of elements) {
                                            const text = (el.textContent || '').trim();
                                            if (text && text.length > 3 && !text.includes('@') && !text.includes('http')) {
                                                const words = text.split(/\\s+/);
                                                if (words.length >= 2 && words.every(word => word.length > 1)) {
                                                    if (selector.includes(':contains(":")') || text.includes(':')) {
                                                        const colonIndex = text.indexOf(':');
                                                        if (colonIndex !== -1) {
                                                            const afterColon = text.substring(colonIndex + 1).trim();
                                                            if (afterColon.length > 3) {
                                                                colonElementMatches.push(afterColon);
                                                            }
                                                        } else {
                                                            colonElementMatches.push(text);
                                                        }
                                                    } else {
                                                        nonColonElementMatches.push(text);
                                                    }
                                                }
                                            }
                                        }
                                    } catch (e) {
                                    }
                                }
                                
                                if (colonElementMatches.length > 0) {
                                    return colonElementMatches[0];
                                }
                                
                                if (nonColonMatches.length > 0) {
                                    return nonColonMatches[0];
                                }
                                
                                if (nonColonElementMatches.length > 0) {
                                    return nonColonElementMatches[0];
                                }
                                
                                const infoTables = document.querySelectorAll('table.info, table.details, .info-table');
                                for (let table of infoTables) {
                                    const rows = table.querySelectorAll('tr');
                                    for (let row of rows) {
                                        const cells = row.querySelectorAll('td, th');
                                        if (cells.length >= 2) {
                                            const label = (cells[0].textContent || '').toLowerCase();
                                            const value = (cells[1].textContent || '').trim();
                                            
                                            if ((label.includes('author') || label.includes('creator')) && value.length > 3) {
                                                if (label.includes(':')) {
                                                    return value;
                                                } else {
                                                    nonColonMatches.push(value);
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                if (nonColonMatches.length > 0) {
                                    return nonColonMatches[0];
                                }
                                
                                return null;
                            };
                    
                    metadata.author = findAuthor();
                    
                    // 3. Enhanced status finding - COMPREHENSIVE search
                    const findStatus = () => {
                        const statusPatterns = [
                            /Status[\\s:]*([^\\n\\r<]+)/i,
                            /\\b(completed|ongoing|releasing|finished|hiatus|dropped|cancelled|discontinued)\\b[^.]*status/i,
                            /status[^.]*\\b(completed|ongoing|releasing|finished|hiatus|dropped|cancelled|discontinued)\\b/i,
                            /Publication[\\s:]*([^\\n\\r<]+)/i,
                            /Release[\\s:]*([^\\n\\r<]+)/i,
                            /Update[\\s:]*([^\\n\\r<]+)/i,
                            /(currently|still)\\s+(ongoing|releasing|publishing)/i,
                            /(has|is)\\s+(completed|finished|dropped|cancelled)/i
                        ];

                        // Get ALL text content from the entire page
                        const textContent = document.body.innerText || document.body.textContent || '';
                        
                        // Strategy 1: Pattern matching in full text
                        for (const pattern of statusPatterns) {
                            const match = textContent.match(pattern);
                            if (match) {
                                let statusText = (match[1] || match[0] || '').toLowerCase().trim();
                                
                                // Clean and normalize the status text
                                statusText = statusText.replace(/[^a-zA-Z\\s]/g, ' ').replace(/\\s+/g, ' ').trim();
                                
                                if (statusText.includes('completed') || statusText.includes('finished') || statusText === 'complete') {
                                    return "completed";
                                } else if (statusText.includes('ongoing') || statusText.includes('releasing') || statusText.includes('publishing') || statusText.includes('continuing')) {
                                    return "releasing";
                                } else if (statusText.includes('hiatus') || statusText.includes('on hold') || statusText.includes('paused')) {
                                    return "hiatus";
                                } else if (statusText.includes('dropped') || statusText.includes('cancelled') || statusText.includes('discontinued') || statusText.includes('axed')) {
                                    return "dropped";
                                }
                            }
                        }

                        // Strategy 2: Search in ALL elements that might contain status
                        const statusSelectors = [
                            // General status elements
                            '[class*="status" i]', '[id*="status" i]', '*[class*="state" i]', '*[id*="state" i]',
                            '.status', '.state', '.progress', '.publication', '.release',
                            
                            // Manga/comic specific
                            '.manga-status', '.comic-status', '.series-status', '.title-status',
                            '.status-label', '.status-badge', '.status-indicator', '.status-tag',
                            '.statustext', '.status-text', '.statusinfo',
                            
                            // Info sections
                            '.info', '.information', '.details', '.meta', '.metadata',
                            '.series-info', '.manga-info', '.comic-info', '.title-info',
                            '.info-item', '.info-row', '.detail-item',
                            
                            // Sidebars and info panels
                            '.sidebar', '.side-bar', '.info-panel', '.details-panel',
                            '.right-column', '.left-column', '.main-info',
                            
                            // Table-based info
                            'table', 'tr', 'td', 'th', '.table', '.row', '.cell',
                            
                            // Headers and footers
                            'header', 'footer', '.header', '.footer',
                            '.page-header', '.page-footer', '.content-header',
                            
                            // Specific content areas
                            '.description', '.synopsis', '.summary', '.overview',
                            '.manga-details', '.comic-details', '.series-details',
                            
                            // Buttons and badges
                            '.badge', '.tag', '.label', '.button', '.btn',
                            
                            // Common containers
                            '.container', '.wrapper', '.content', '.main', '.section',
                            '.box', '.panel', '.card', '.widget'
                        ];

                        // Create a unique selector list
                        const uniqueSelectors = [...new Set(statusSelectors)];
                        
                        for (const selector of uniqueSelectors) {
                            try {
                                const elements = document.querySelectorAll(selector);
                                for (let el of elements) {
                                    const text = (el.textContent || '').toLowerCase().trim();
                                    if (!text || text.length < 3) continue;
                                    
                                    // Clean the text
                                    const cleanText = text.replace(/[^a-zA-Z\\s]/g, ' ').replace(/\\s+/g, ' ').trim();
                                    
                                    // Check for status indicators
                                    if (cleanText.includes('status:')) {
                                        const afterStatus = cleanText.split('status:')[1].trim().split(' ')[0];
                                        if (afterStatus.includes('complete')) return "completed";
                                        if (afterStatus.includes('ongoing')) return "releasing";
                                        if (afterStatus.includes('hiatus')) return "hiatus";
                                        if (afterStatus.includes('drop')) return "dropped";
                                    }
                                    
                                    // Direct keyword matching
                                    if (cleanText.includes('completed') || cleanText.includes('finished') || cleanText === 'complete') {
                                        return "completed";
                                    } else if (cleanText.includes('ongoing') || cleanText.includes('releasing') || cleanText.includes('publishing') || cleanText.includes('continuing')) {
                                        return "releasing";
                                    } else if (cleanText.includes('hiatus') || cleanText.includes('on hold') || cleanText.includes('paused')) {
                                        return "hiatus";
                                    } else if (cleanText.includes('dropped') || cleanText.includes('cancelled') || cleanText.includes('discontinued') || cleanText.includes('axed')) {
                                        return "dropped";
                                    }
                                    
                                    // Check parent elements for context
                                    if (el.parentElement) {
                                        const parentText = (el.parentElement.textContent || '').toLowerCase();
                                        if (parentText.includes('status') && (parentText.includes('complete') || parentText.includes('ongoing'))) {
                                            if (parentText.includes('complete')) return "completed";
                                            if (parentText.includes('ongoing')) return "releasing";
                                        }
                                    }
                                }
                            } catch (e) {
                                // Ignore selector errors
                            }
                        }

                        // Strategy 3: Search in data attributes and hidden meta information
                        const metaStatusSelectors = [
                            'meta[property*="status" i]', 'meta[name*="status" i]',
                            '[data-status]', '[data-state]', '[data-progress]',
                            '*[content*="completed" i]', '*[content*="ongoing" i]',
                            '*[content*="releasing" i]', '*[content*="finished" i]'
                        ];

                        for (const selector of metaStatusSelectors) {
                            try {
                                const elements = document.querySelectorAll(selector);
                                for (let el of elements) {
                                    const content = el.getAttribute('content') || el.getAttribute('data-status') ||
                                                   el.getAttribute('data-state') || el.textContent || '';
                                    const statusContent = content.toLowerCase().trim();
                                    
                                    if (statusContent.includes('completed') || statusContent.includes('finished')) {
                                        return "completed";
                                    } else if (statusContent.includes('ongoing') || statusContent.includes('releasing')) {
                                        return "releasing";
                                    } else if (statusContent.includes('hiatus')) {
                                        return "hiatus";
                                    } else if (statusContent.includes('dropped') || statusContent.includes('cancelled')) {
                                        return "dropped";
                                    }
                                }
                            } catch (e) {
                                // Ignore selector errors
                            }
                        }

                        return null;
                    };

                    metadata.status = findStatus();
                    
                    // Add title extraction from page as fallback
                    metadata.title = findTitleInPage();
                    
                    return Object.keys(metadata).some(key => metadata[key] !== null) ? metadata : null;
                })();
                """
                
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
    
    
    
    
} // AddMangaJAVA
