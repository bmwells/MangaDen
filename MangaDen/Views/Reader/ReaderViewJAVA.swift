//
//  ReaderViewJAVA.swift
//  MangaDen
//
//  Created by Brody Wells on 9/2/25.
//

import SwiftUI
import WebKit

@MainActor
class ReaderViewJava: NSObject, ObservableObject {
    @Published var images: [UIImage] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private var webView: WKWebView?
    private var currentURL: URL?
    private var imageCache: [String: UIImage] = [:]
    private var extractionResults: [ExtractionResult] = []
    
    func loadChapter(url: URL) {
        isLoading = true
        error = nil
        images = []
        currentURL = url
        extractionResults = []
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = .nonPersistent()
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        self.webView = webView
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    // MARK: - Enhanced Extraction with Comparison
    
    private func executeAllExtractionStrategies(webView: WKWebView, onComplete: @escaping (Bool) -> Void) {
        let dispatchGroup = DispatchGroup()
        var strategyResults: [ExtractionResult] = []
        
        // Strategy 1: Direct DOM inspection
        dispatchGroup.enter()
        attemptExtractionStrategy1(webView: webView) { images in
            strategyResults.append(ExtractionResult(strategy: 1, images: images))
            dispatchGroup.leave()
        }
        
        // Strategy 2: Scroll-triggered loading
        dispatchGroup.enter()
        attemptExtractionStrategy2(webView: webView) { images in
            strategyResults.append(ExtractionResult(strategy: 2, images: images))
            dispatchGroup.leave()
        }
        
        // Strategy 3: HTML source regex
        dispatchGroup.enter()
        attemptExtractionStrategy3(webView: webView) { images in
            strategyResults.append(ExtractionResult(strategy: 3, images: images))
            dispatchGroup.leave()
        }
        
        // Strategy 4: Position-based DOM
        dispatchGroup.enter()
        attemptExtractionStrategy4(webView: webView) { images in
            strategyResults.append(ExtractionResult(strategy: 4, images: images))
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else {
                onComplete(false)
                return
            }
            
            self.extractionResults = strategyResults
            let bestOrder = self.findBestImageOrder(from: strategyResults)
            
            if bestOrder.isEmpty {
                print("No images found after all strategies")
                onComplete(false)
            } else {
                print("Best order found with \(bestOrder.count) images")
                self.processAndDownloadImages(bestOrder, onComplete: onComplete)
            }
        }
    }
    
    private func findBestImageOrder(from results: [ExtractionResult]) -> [EnhancedImageInfo] {
        print("Analyzing results from \(results.count) strategies...")
        
        let nonEmptyResults = results.filter { !$0.images.isEmpty }
        
        if nonEmptyResults.isEmpty {
            print("No strategies found any images")
            return []
        }
        
        for result in nonEmptyResults {
            print("Strategy \(result.strategy) found \(result.images.count) images")
        }
        
        // Instead of grouping by count, use the strategy that found the most images
        if let bestResult = nonEmptyResults.max(by: { $0.images.count < $1.images.count }) {
            print("Using strategy \(bestResult.strategy) with \(bestResult.images.count) images (most found)")
            return bestResult.images
        }
        
        return []
    }
    
    // MARK: - Fixed Extraction Strategies
    
    private func attemptExtractionStrategy1(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
        let jsScript = """
        (function() {
            var images = [];
            var imgElements = document.querySelectorAll('img');
            
            for (var i = 0; i < imgElements.length; i++) {
                var img = imgElements[i];
                if (img.src && isImageUrl(img.src)) {
                    var rect = img.getBoundingClientRect();
                    images.push({
                        src: img.src,
                        width: rect.width,
                        height: rect.height,
                        position: i,
                        naturalWidth: img.naturalWidth,
                        naturalHeight: img.naturalHeight
                    });
                }
            }
            
            var lazyImages = document.querySelectorAll('img[data-src]');
            for (var i = 0; i < lazyImages.length; i++) {
                var img = lazyImages[i];
                if (img.dataset.src && isImageUrl(img.dataset.src)) {
                    var rect = img.getBoundingClientRect();
                    images.push({
                        src: img.dataset.src,
                        width: rect.width,
                        height: rect.height,
                        position: imgElements.length + i,
                        isLazy: true
                    });
                }
            }
            
            function isImageUrl(url) {
                // More permissive URL matching
                return url.match(/\\.(jpg|jpeg|png|gif|webp|bmp)(?:\\?|$)/i) &&
                       (url.includes('bp.blogspot.com') ||
                        url.includes('blogspot') ||
                        url.includes('mangafox') ||
                        url.includes('lowee.us') ||
                        url.includes('/chapter/') ||
                        url.includes('/Chapter/') ||
                        url.includes('page') ||
                        url.includes('Page') ||
                        url.match(/\\d/)); // Any URL containing numbers
            }
            
            return images;
        })();
        """
        
        webView.evaluateJavaScript(jsScript) { result, error in
            if let error = error {
                print("Strategy 1 failed: \(error)")
                completion([])
                return
            }
            
            guard let imageDicts = result as? [[String: Any]] else {
                completion([])
                return
            }
            
            let imageInfos = self.parseImageDicts(imageDicts)
            print("Strategy 1 parsed \(imageInfos.count) images")
            completion(imageInfos)
        }
    }
    
    private func attemptExtractionStrategy2(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
        let jsScript = """
        (function() {
            // Scroll multiple times to trigger all lazy loading
            var scrollHeight = document.body.scrollHeight;
            var scrollStep = scrollHeight / 3;
            
            for (var i = 0; i <= scrollHeight; i += scrollStep) {
                window.scrollTo(0, i);
            }
            
            // Final scroll to bottom
            window.scrollTo(0, scrollHeight);
            
            // Wait for images to load
            var startTime = Date.now();
            while (Date.now() - startTime < 2000) {
                // Busy wait for 2 seconds
            }
            
            var images = [];
            var imgElements = document.querySelectorAll('img');
            
            for (var i = 0; i < imgElements.length; i++) {
                var img = imgElements[i];
                var src = img.currentSrc || img.src;
                if (src && isImageUrl(src)) {
                    var rect = img.getBoundingClientRect();
                    images.push({
                        src: src,
                        width: rect.width,
                        height: rect.height,
                        position: i,
                        naturalWidth: img.naturalWidth,
                        naturalHeight: img.naturalHeight
                    });
                }
            }
            
            // Check various data attributes
            var dataAttrs = ['data-src', 'data-url', 'data-image', 'data-original', 'data-lazy-src', 'data-lazyload'];
            for (var i = 0; i < dataAttrs.length; i++) {
                var attr = dataAttrs[i];
                var elements = document.querySelectorAll('[' + attr + ']');
                for (var j = 0; j < elements.length; j++) {
                    var el = elements[j];
                    var value = el.getAttribute(attr);
                    if (value && isImageUrl(value)) {
                        images.push({
                            src: value,
                            width: el.offsetWidth,
                            height: el.offsetHeight,
                            position: imgElements.length + j,
                            fromAttribute: attr
                        });
                    }
                }
            }
            
            function isImageUrl(url) {
                // More permissive URL matching
                return url.match(/\\.(jpg|jpeg|png|gif|webp|bmp)(?:\\?|$)/i) &&
                       (url.includes('bp.blogspot.com') ||
                        url.includes('blogspot') ||
                        url.includes('mangafox') ||
                        url.includes('lowee.us') ||
                        url.includes('/chapter/') ||
                        url.includes('/Chapter/') ||
                        url.includes('page') ||
                        url.includes('Page') ||
                        url.match(/\\d/)); // Any URL containing numbers
            }
            
            return images;
        })();
        """
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            webView.evaluateJavaScript(jsScript) { result, error in
                if let error = error {
                    print("Strategy 2 failed: \(error)")
                    completion([])
                    return
                }
                
                guard let imageDicts = result as? [[String: Any]] else {
                    completion([])
                    return
                }
                
                let imageInfos = self.parseImageDicts(imageDicts)
                print("Strategy 2 parsed \(imageInfos.count) images")
                completion(imageInfos)
            }
        }
    }
    
    private func attemptExtractionStrategy3(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
        let jsScript = """
        (function() {
            var html = document.documentElement.outerHTML;
            var imageUrls = [];
            
            // Multiple regex patterns to catch different URL formats
            var patterns = [
                /https?:[^"']*\\.(?:jpg|jpeg|png|gif|webp|bmp)(?:\\?[^"']*)?/gi,
                /"([^"]*\\.(?:jpg|jpeg|png|gif|webp|bmp)[^"]*)"/gi,
                /'([^']*\\.(?:jpg|jpeg|png|gif|webp|bmp)[^']*)'/gi
            ];
            
            var allMatches = [];
            patterns.forEach(function(pattern) {
                var matches = html.match(pattern);
                if (matches) {
                    allMatches = allMatches.concat(matches);
                }
            });
            
            if (allMatches.length > 0) {
                var uniqueUrls = [...new Set(allMatches)];
                uniqueUrls.forEach(function(url, index) {
                    // Clean up URLs from quotes
                    var cleanUrl = url.replace(/^["']|["']$/g, '');
                    if (isRelevantImage(cleanUrl)) {
                        imageUrls.push({
                            src: cleanUrl,
                            width: 0,
                            height: 0,
                            position: index,
                            fromHtml: true
                        });
                    }
                });
            }
            
            function isRelevantImage(url) {
                // Less aggressive filtering
                if (url.includes('avatar') || url.includes('icon') || url.includes('logo') ||
                    url.includes('ads') || url.includes('banner') || url.length < 10) {
                    return false;
                }
                
                return url.includes('bp.blogspot.com') ||
                       url.includes('blogspot') ||
                       url.includes('mangafox') ||
                       url.includes('lowee.us') ||
                       url.includes('/chapter/') ||
                       url.includes('/Chapter/') ||
                       url.includes('page') ||
                       url.includes('Page') ||
                       /\\d/.test(url);
            }
            
            return imageUrls;
        })();
        """
        
        webView.evaluateJavaScript(jsScript) { result, error in
            if let error = error {
                print("Strategy 3 failed: \(error)")
                completion([])
                return
            }
            
            guard let imageDicts = result as? [[String: Any]] else {
                completion([])
                return
            }
            
            let imageInfos = self.parseImageDicts(imageDicts)
            print("Strategy 3 parsed \(imageInfos.count) images")
            completion(imageInfos)
        }
    }
    
    private func attemptExtractionStrategy4(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
        let jsScript = """
        (function() {
            function getElementTop(element) {
                var rect = element.getBoundingClientRect();
                return rect.top + window.pageYOffset;
            }
            
            var images = [];
            var imgElements = Array.from(document.querySelectorAll('img'));
            
            // Much less restrictive filtering - only filter very small images
            var visibleImages = imgElements
                .filter(img => img.src && isRelevantImage(img.src) && img.naturalWidth > 50)
                .map(img => ({
                    src: img.src,
                    width: img.naturalWidth,
                    height: img.naturalHeight,
                    position: getElementTop(img)
                }));
            
            function isRelevantImage(url) {
                return url.includes('bp.blogspot.com') ||
                       url.includes('blogspot') ||
                       url.includes('mangafox') ||
                       url.includes('lowee.us') ||
                       url.includes('/chapter/') ||
                       url.includes('/Chapter/') ||
                       url.includes('page') ||
                       url.includes('Page') ||
                       /\\d/.test(url);
            }
            
            visibleImages.sort((a, b) => a.position - b.position);
            return JSON.stringify(visibleImages);
        })();
        """
        
        webView.evaluateJavaScript(jsScript) { result, error in
            if let error = error {
                print("Strategy 4 failed: \(error)")
                completion([])
                return
            }
            
            if let jsonString = result as? String,
               let jsonData = jsonString.data(using: .utf8) {
                do {
                    let positionedImages = try JSONDecoder().decode([PositionedImageInfo].self, from: jsonData)
                    let enhancedImages = positionedImages.map { positionedImage in
                        EnhancedImageInfo(
                            src: positionedImage.src,
                            width: positionedImage.width,
                            height: positionedImage.height,
                            position: positionedImage.position,
                            alt: "",
                            className: "",
                            id: ""
                        )
                    }
                    print("Strategy 4 parsed \(enhancedImages.count) images")
                    completion(enhancedImages)
                } catch {
                    print("Strategy 4 JSON decode failed: \(error)")
                    completion([])
                }
            } else {
                completion([])
            }
        }
    }
    
    // MARK: - Improved Processing
    
    private func processAndDownloadImages(_ imageInfos: [EnhancedImageInfo], onComplete: ((Bool) -> Void)? = nil) {
        print("Processing \(imageInfos.count) images...")
        
        // MINIMAL FILTERING - only remove obviously broken images
        let filteredImages = imageInfos.filter { image in
            // Remove images with obviously invalid URLs
            guard !image.src.isEmpty,
                  image.src.hasPrefix("http"),
                  !image.src.contains("+Math.random()"),
                  !image.src.contains("javascript:"),
                  !image.src.contains("data:text/html") else {
                return false
            }
            
            // Keep ALL images that pass basic URL validation
            return true
        }
        
        print("After filtering: \(filteredImages.count) images")
        
        if filteredImages.isEmpty {
            print("No images passed filtering, trying with all images...")
            // If filtering removes everything, use the original images
            downloadImages(from: imageInfos, onComplete: onComplete)
            return
        }
        
        let sortedImages = intelligentImageSorting(filteredImages)
        print("Final order: \(sortedImages.count) images")
        
        downloadImages(from: sortedImages, onComplete: onComplete)
    }
    
    private func intelligentImageSorting(_ images: [EnhancedImageInfo]) -> [EnhancedImageInfo] {
        var sortedImages = images
        
        // More specific patterns that target actual page numbers, not random file hashes
        let patterns = [
            // Specific patterns for common manga sites
            try? NSRegularExpression(pattern: "/(l\\d+)\\.(jpg|jpeg|png|gif|webp)", options: []), // /l003.jpg
            try? NSRegularExpression(pattern: "l(\\d+)\\.(jpg|jpeg|png|gif|webp)", options: []), // l003.jpg
            try? NSRegularExpression(pattern: "/(\\d+)\\.(jpg|jpeg|png|gif|webp)", options: []), // /003.jpg
            try? NSRegularExpression(pattern: "_(\\d+)\\.(jpg|jpeg|png|gif|webp)", options: []), // _003.jpg
            try? NSRegularExpression(pattern: "page[_-]?(\\d+)", options: [.caseInsensitive]), // page003, page_003
            try? NSRegularExpression(pattern: "/(\\d+)/[^/]+\\.(jpg|jpeg|png|gif|webp)", options: []), // /003/image.jpg
            try? NSRegularExpression(pattern: "chapter[_-]?\\d+[_-]?(\\d+)", options: [.caseInsensitive]), // chapter1_003
            
            // NEW: Pattern for blogspot URLs ending with /XX.webp (like /09.webp, /10.webp)
            try? NSRegularExpression(pattern: "/(\\d+)\\.(webp|jpg|jpeg|png|gif)$", options: []),
            try? NSRegularExpression(pattern: "/(\\d+)\\.(webp|jpg|jpeg|png|gif)\\?", options: [])
        ]
        
        print("=== Sorting \(sortedImages.count) images ===")
        
        // First, identify which images have meaningful page numbers vs random numbers
        var imageClassifications: [(image: EnhancedImageInfo, pageNumber: Int?, isMeaningful: Bool)] = []
        
        for image in sortedImages {
            let pageNumber = extractPageNumber(from: image.src, using: patterns)
            let isMeaningful = isMeaningfulPageNumber(in: image.src, pageNumber: pageNumber)
            
            imageClassifications.append((image, pageNumber, isMeaningful))
            
            if let pageNumber = pageNumber, isMeaningful {
                print("Image: \(pageNumber) - MEANINGFUL - \(image.src)")
            } else if let pageNumber = pageNumber {
                print("Image: \(pageNumber) - RANDOM - \(image.src)")
            } else {
                print("Image: NO NUMBER - \(image.src)")
            }
        }
        
        // Sort with priority: meaningful page numbers > DOM position > random numbers
        let sortedClassifications = imageClassifications.sorted { item1, item2 in
            let (image1, num1, meaningful1) = item1
            let (image2, num2, meaningful2) = item2
            
            // Both have meaningful page numbers
            if meaningful1 && meaningful2, let num1 = num1, let num2 = num2 {
                return num1 < num2
            }
            // Only image1 has meaningful page number
            else if meaningful1 {
                return true
            }
            // Only image2 has meaningful page number
            else if meaningful2 {
                return false
            }
            // Neither has meaningful page numbers, use DOM position
            else {
                return image1.position < image2.position
            }
        }
        
        // Extract just the images from the sorted classifications
        sortedImages = sortedClassifications.map { $0.image }
        
        print("=== Final order ===")
        for (index, classification) in sortedClassifications.enumerated() {
            if let pageNumber = classification.pageNumber, classification.isMeaningful {
                print("Sorted \(index): \(pageNumber) - MEANINGFUL - \(classification.image.src)")
            } else if let pageNumber = classification.pageNumber {
                print("Sorted \(index): \(pageNumber) - RANDOM - \(classification.image.src)")
            } else {
                print("Sorted \(index): NO NUMBER - \(classification.image.src)")
            }
        }
        
        return removeDuplicates(sortedImages)
    }

    private func isMeaningfulPageNumber(in url: String, pageNumber: Int?) -> Bool {
        guard let pageNumber = pageNumber else { return false }
        
        // Check if this looks like a meaningful page number (not a random hash)
        let meaningfulIndicators = [
            "/l\(pageNumber).", "/\(pageNumber).", "_\(pageNumber).",
            "page\(pageNumber)", "page_\(pageNumber)", "Page\(pageNumber)",
            "/\(pageNumber)/", "chapter.*\(pageNumber)"
        ]
        
        // If URL contains any of these patterns with the page number, it's meaningful
        for indicator in meaningfulIndicators {
            if url.contains(indicator) {
                return true
            }
        }
        
        // NEW: Check for blogspot URLs ending with /XX.webp pattern
        if url.contains("blogger.googleusercontent.com") {
            let blogspotPatterns = [
                "/\(String(format: "%02d", pageNumber)).webp",
                "/\(String(format: "%02d", pageNumber)).jpg",
                "/\(String(format: "%02d", pageNumber)).png"
            ]
            for pattern in blogspotPatterns {
                if url.contains(pattern) {
                    return true
                }
            }
        }
        
        // For your specific case - if it's from mangafox with l000 format
        if url.contains("mangafox") && url.contains("/l\(pageNumber).") {
            return true
        }
        
        // If it's from blogspot with numbered pages
        if url.contains("bp.blogspot.com") && url.contains("/\(pageNumber).jpg") {
            return true
        }
        
        // NEW: Generic check - if the number appears at the end of the URL path before extension
        if let lastPathComponent = URL(string: url)?.lastPathComponent {
            let numberPatterns = [
                "\(String(format: "%02d", pageNumber)).webp",
                "\(String(format: "%02d", pageNumber)).jpg",
                "\(String(format: "%02d", pageNumber)).png",
                "\(pageNumber).webp",
                "\(pageNumber).jpg",
                "\(pageNumber).png"
            ]
            for pattern in numberPatterns {
                if lastPathComponent == pattern || lastPathComponent.hasSuffix(pattern) {
                    return true
                }
            }
        }
        
        // Otherwise, it's probably a random number from a file hash
        return false
    }

    private func extractPageNumber(from url: String, using patterns: [NSRegularExpression?]) -> Int? {
        for pattern in patterns.compactMap({ $0 }) {
            let matches = pattern.matches(in: url, options: [], range: NSRange(location: 0, length: url.count))
            if let match = matches.last {
                let range = Range(match.range(at: 1), in: url)!
                let numberString = String(url[range])
                // Handle "l003" format by removing the 'l' prefix if present
                let cleanNumberString = numberString.replacingOccurrences(of: "^l", with: "", options: .regularExpression)
                if let number = Int(cleanNumberString) {
                    return number
                }
            }
        }
        return nil
    }
    
    private func removeDuplicates(_ images: [EnhancedImageInfo]) -> [EnhancedImageInfo] {
        var seen = Set<String>()
        var result: [EnhancedImageInfo] = []
        
        for image in images {
            if !seen.contains(image.src) {
                seen.insert(image.src)
                result.append(image)
            }
        }
        
        return result
    }
    
    // MARK: - Download and Cache
    
    private func downloadImages(from imageInfos: [EnhancedImageInfo], onComplete: ((Bool) -> Void)? = nil) {
        Task {
            var downloadedImages: [UIImage] = []
            
            for (index, imageInfo) in imageInfos.enumerated() {
                print("Downloading \(index + 1)/\(imageInfos.count): \(imageInfo.src)")
                
                if let cachedImage = getCachedImage(for: imageInfo.src) {
                    downloadedImages.append(cachedImage)
                    continue
                }
                
                guard let url = URL(string: imageInfo.src) else {
                    print("Invalid URL: \(imageInfo.src)")
                    continue
                }
                
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        cacheImage(image, for: imageInfo.src)
                        downloadedImages.append(image)
                        print("Downloaded image \(index + 1)")
                    }
                } catch {
                    print("Download failed for \(imageInfo.src): \(error)")
                }
            }
            
            await MainActor.run {
                if downloadedImages.isEmpty {
                    self.error = "Failed to download any images"
                    onComplete?(false)
                } else {
                    self.images = downloadedImages
                    print("Successfully downloaded \(downloadedImages.count) images")
                    onComplete?(true)
                }
                self.isLoading = false
            }
        }
    }
    
    private func getCachedImage(for key: String) -> UIImage? {
        return imageCache[key]
    }
    
    private func cacheImage(_ image: UIImage, for key: String) {
        imageCache[key] = image
    }
    
    func clearCache() {
        images = []
        imageCache.removeAll()
        webView?.stopLoading()
        webView = nil
        currentURL = nil
        
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date.distantPast,
            completionHandler: {}
        )
    }
    
    // MARK: - Retry Logic
    
    private func attemptImageExtraction(attempt: Int, maxAttempts: Int, onComplete: ((Bool) -> Void)? = nil) {
        let delay = Double(attempt) * 2.0
        
        print("Attempt \(attempt) of \(maxAttempts) - waiting \(delay) seconds")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, let webView = self.webView else {
                onComplete?(false)
                return
            }
            
            self.executeAllExtractionStrategies(webView: webView) { [weak self] success in
                if success || attempt >= maxAttempts {
                    if !success && attempt >= maxAttempts {
                        Task { @MainActor in
                            self?.error = "No suitable images found after \(maxAttempts) attempts"
                            self?.isLoading = false
                        }
                    }
                    onComplete?(success)
                } else {
                    self?.attemptImageExtraction(attempt: attempt + 1, maxAttempts: maxAttempts, onComplete: onComplete)
                }
            }
        }
    }
    
    // MARK: - Image Dict Parsing
    
    private func parseImageDicts(_ dicts: [[String: Any]]) -> [EnhancedImageInfo] {
        var imageInfos: [EnhancedImageInfo] = []
        
        for dict in dicts {
            if let src = dict["src"] as? String {
                let width = (dict["width"] as? NSNumber)?.intValue ?? (dict["width"] as? Int) ?? (dict["naturalWidth"] as? Int) ?? 0
                let height = (dict["height"] as? NSNumber)?.intValue ?? (dict["height"] as? Int) ?? (dict["naturalHeight"] as? Int) ?? 0
                let position = (dict["position"] as? NSNumber)?.doubleValue ?? (dict["position"] as? Double) ?? 0
                
                imageInfos.append(EnhancedImageInfo(
                    src: src,
                    width: width,
                    height: height,
                    position: position,
                    alt: "",
                    className: "",
                    id: ""
                ))
            }
        }
        
        return imageInfos
    }
}

// MARK: - Data Structures

struct EnhancedImageInfo {
    let src: String
    let width: Int
    let height: Int
    let position: Double
    let alt: String
    let className: String
    let id: String
}

struct PositionedImageInfo: Codable {
    let src: String
    let width: Int
    let height: Int
    let position: Double
}

struct ExtractionResult {
    let strategy: Int
    let images: [EnhancedImageInfo]
}

// MARK: - WKNavigationDelegate

extension ReaderViewJava: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Page loaded, starting multi-strategy image extraction...")
        attemptImageExtraction(attempt: 1, maxAttempts: 3) { [weak self] success in
            if !success {
                Task { @MainActor in
                    self?.error = "Failed to extract images after multiple attempts"
                    self?.isLoading = false
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.error = "Failed to load page: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.error = "Failed to load page: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
}
