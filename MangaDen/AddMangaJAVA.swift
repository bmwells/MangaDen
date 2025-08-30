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
    
// Retrieve Chapter Information

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
    
    
    // Function to find chapter title, link URL and upload date with specific numbering patterns
    static func findChapterLinks(in webView: WKWebView, completion: @escaping ([String: [String: String]]?) -> Void) {
        let javascript = """
            (function() {
                // Get all anchor tags on the page
                const links = document.getElementsByTagName('a');
                const chapterLinks = {};
                const chapterPattern = /chapter\\s*[\\d\\.]+/i;
                
                // Common date patterns
                const datePatterns = [
                    /(\\d{1,2}[\\/\\-]\\d{1,2}[\\/\\-]\\d{2,4})/, // MM/DD/YYYY, MM-DD-YYYY
                    /(\\d{4}[\\/\\-]\\d{1,2}[\\/\\-]\\d{1,2})/, // YYYY/MM/DD, YYYY-MM-DD
                    /(\\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\s+\\d{1,2},?\\s+\\d{4}\\b)/i, // Month DD, YYYY
                    /(\\b\\d{1,2}\\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\s+\\d{4}\\b)/i, // DD Month YYYY
                    /(\\d{1,2}[\\/\\-]\\d{1,2}[\\/\\-]\\d{2})/, // MM/DD/YY, MM-DD-YY
                    /(\\d{2}:\\d{2}(?::\\d{2})?)/, // Time patterns
                    /(\\b(?:today|yesterday)\\b)/i // Relative dates
                ];
                
                for (let i = 0; i < links.length; i++) {
                    const link = links[i];
                    const text = link.textContent || link.innerText;
                    const href = link.href;
                    
                    if (text && chapterPattern.test(text.toLowerCase())) {
                        // Extract the chapter number
                        const match = text.match(/(\\d+(?:\\.\\d+)?)/);
                        if (match && match[1]) {
                            // Store the original full text as title
                            let fullTitle = text.trim().replace(/\\s+/g, ' ');
                            let uploadDate = null;
                            
                            // Try to find and extract date from the text
                            for (const pattern of datePatterns) {
                                const dateMatch = fullTitle.match(pattern);
                                if (dateMatch) {
                                    uploadDate = dateMatch[0].trim();
                                    // Remove the date from the title
                                    fullTitle = fullTitle.replace(pattern, '').trim();
                                    // Clean up any leftover punctuation or extra spaces
                                    fullTitle = fullTitle.replace(/^[\\s\\.,;:-]+|[\\s\\.,;:-]+$/g, '').trim();
                                    break;
                                }
                            }
                            
                            // If no date found, check parent elements or sibling elements for dates
                            if (!uploadDate) {
                                uploadDate = findDateInNearbyElements(link);
                            }
                            
                            const chapterData = {
                                "url": href,
                                "title": fullTitle  // Keep the full title including "Chapter X"
                            };
                            
                            if (uploadDate) {
                                chapterData["upload_date"] = uploadDate;
                            }
                            
                            // Use just the number as the key (e.g., "4" instead of "Chapter 4")
                            chapterLinks[match[1]] = chapterData;
                        }
                    }
                }
                
                // Helper function to find dates in nearby elements
                function findDateInNearbyElements(element) {
                    // Check parent element
                    if (element.parentElement) {
                        const parentText = element.parentElement.textContent || element.parentElement.innerText;
                        for (const pattern of datePatterns) {
                            const dateMatch = parentText.match(pattern);
                            if (dateMatch && !parentText.includes(element.textContent)) {
                                return dateMatch[0].trim();
                            }
                        }
                    }
                    
                    // Check previous and next siblings
                    let sibling = element.previousElementSibling;
                    while (sibling) {
                        const siblingText = sibling.textContent || sibling.innerText;
                        for (const pattern of datePatterns) {
                            const dateMatch = siblingText.match(pattern);
                            if (dateMatch) {
                                return dateMatch[0].trim();
                            }
                        }
                        sibling = sibling.previousElementSibling;
                    }
                    
                    sibling = element.nextElementSibling;
                    while (sibling) {
                        const siblingText = sibling.textContent || sibling.innerText;
                        for (const pattern of datePatterns) {
                            const dateMatch = siblingText.match(pattern);
                            if (dateMatch) {
                                return dateMatch[0].trim();
                            }
                        }
                        sibling = sibling.nextElementSibling;
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

    // Enhanced metadata finding function with desktop forcing
    static func findMangaMetadata(in webView: WKWebView, completion: @escaping ([String: Any]?) -> Void) {
        
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
                        "title_image": null,
                        "author": null,
                        "status": null
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
                            /Author(?:s|\\(s\\))?[\\s:]*([^\\n\\r<]+)/i,
                            /Creator(?:s)?[\\s:]*([^\\n\\r<]+)/i,
                            /By[\\s]+([^\\n\\r<]+?(?=\\s*(?:Chapter|Vol|\\d{4}|$)))/i,
                            /Written by[\\s]+([^\\n\\r<]+)/i,
                            /Story by[\\s]+([^\\n\\r<]+)/i,
                            /\\bAuthor\\b[^:\\n\\r<]*([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)+)/,
                            /\\bCreator\\b[^:\\n\\r<]*([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)+)/
                        ];
                        
                        // Strategy 1: Text content search
                        const textContent = document.body.innerText || document.body.textContent || '';
                        for (const pattern of authorPatterns) {
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
                                    return author;
                                }
                            }
                        }
                        
                        // Strategy 2: HTML element search
                        const authorSelectors = [
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
                            '.credit',
                            '.info-item:contains("Author")',
                            '.info-item:contains("Creator")',
                            'td:contains("Author") + td',
                            'td:contains("Creator") + td',
                            'th:contains("Author") + td',
                            'th:contains("Creator") + td'
                        ];
                        
                        for (const selector of authorSelectors) {
                            try {
                                const elements = document.querySelectorAll(selector);
                                for (let el of elements) {
                                    const text = (el.textContent || '').trim();
                                    if (text && text.length > 3 && !text.includes('@') && !text.includes('http')) {
                                        // Check if this looks like an author name
                                        const words = text.split(/\\s+/);
                                        if (words.length >= 2 && words.every(word => word.length > 1)) {
                                            return text;
                                        }
                                    }
                                }
                            } catch (e) {
                                // Ignore selector errors
                            }
                        }
                        
                        // Strategy 3: Table-based info (common on manga sites)
                        const infoTables = document.querySelectorAll('table.info, table.details, .info-table');
                        for (let table of infoTables) {
                            const rows = table.querySelectorAll('tr');
                            for (let row of rows) {
                                const cells = row.querySelectorAll('td, th');
                                if (cells.length >= 2) {
                                    const label = (cells[0].textContent || '').toLowerCase();
                                    const value = (cells[1].textContent || '').trim();
                                    
                                    if ((label.includes('author') || label.includes('creator')) && value.length > 3) {
                                        return value;
                                    }
                                }
                            }
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
                        
                        if let metadata = result as? [String: Any] {
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
