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
    @Published var downloadProgress: String = ""
    
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
    
    // MARK: - Execute All Strategies
        
    private func executeAllExtractionStrategies(webView: WKWebView, onComplete: @escaping (Bool) -> Void) {
        let dispatchGroup = DispatchGroup()
        var strategyResults: [ExtractionResult] = []
        var completedStrategies = 0
        
        print("EXTRACTION: Starting all extraction strategies")
        
        // Execute strategies 1-3 first
        let strategies = [
            self.attemptExtractionStrategy1,
            self.attemptExtractionStrategy2,
            self.attemptExtractionStrategy3
        ]
        
        for (index, strategy) in strategies.enumerated() {
            dispatchGroup.enter()
            print("EXTRACTION: Starting Strategy \(index + 1)")
            
            strategy(webView) { images in
                strategyResults.append(ExtractionResult(strategy: index + 1, images: images))
                completedStrategies += 1
                print("EXTRACTION: Strategy \(index + 1) completed with \(images.count) images (completed: \(completedStrategies)/3)")
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else {
                onComplete(false)
                return
            }
            
            print("EXTRACTION: ALL STRATEGIES 1-3 COMPLETED")
            let totalImages = strategyResults.reduce(0) { $0 + $1.images.count }
            let maxImagesFromSingleStrategy = strategyResults.map { $0.images.count }.max() ?? 0
            
            print("EXTRACTION: Strategies 1-3 found \(totalImages) total images")
            for result in strategyResults {
                print("EXTRACTION: Strategy \(result.strategy) found \(result.images.count) images")
            }
            
            // Only try Strategy 4 if no single strategy found more than 10 images
            let shouldTryStrategy4 = maxImagesFromSingleStrategy <= 10
            
            if shouldTryStrategy4 {
                print("EXTRACTION: STRATEGY 4 TRIGGERED - No strategy found more than 10 images (max: \(maxImagesFromSingleStrategy))")
                print("EXTRACTION: STARTING STRATEGY 4 - Page Menu Extraction")
                self.attemptExtractionStrategy4(webView: webView) { strategy4Images in
                    print("EXTRACTION: STRATEGY 4 COMPLETED - Found \(strategy4Images.count) images")
                    strategyResults.append(ExtractionResult(strategy: 4, images: strategy4Images))
                    
                    let allImages = strategyResults.flatMap { $0.images }
                    print("EXTRACTION: FINAL RESULTS - \(allImages.count) total images after Strategy 4")
                    
                    if allImages.isEmpty {
                        print("EXTRACTION: No images found after all strategies")
                        onComplete(false)
                    } else {
                        print("EXTRACTION: Processing and downloading \(allImages.count) images")
                        self.processAndDownloadImages(allImages, onComplete: onComplete)
                    }
                }
            } else {
                let allImages = strategyResults.flatMap { $0.images }
                print("EXTRACTION: Sufficient images found (max: \(maxImagesFromSingleStrategy) per strategy), skipping Strategy 4")
                
                if allImages.isEmpty {
                    print("EXTRACTION: No images found in strategies 1-3")
                    onComplete(false)
                } else {
                    print("EXTRACTION: Processing and downloading \(allImages.count) images from strategies 1-3")
                    self.processAndDownloadImages(allImages, onComplete: onComplete)
                }
            }
        }
    }
    
    
    // MARK: - Image Order
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
    
    // MARK: - Extraction Strategies
    
    // MARK: - Strategy 1 (Direct DOM inspection)
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
    
    // MARK: - Strategy 2 (HTML source regex)
    private func attemptExtractionStrategy2(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
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
    
    // MARK: - Strategy 3 (Position-based DOM)
    private func attemptExtractionStrategy3(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
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
                print("Strategy 3 failed: \(error)")
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
                    print("Strategy 3 parsed \(enhancedImages.count) images")
                    completion(enhancedImages)
                } catch {
                    print("Strategy 3 JSON decode failed: \(error)")
                    completion([])
                }
            } else {
                completion([])
            }
        }
    }
    
    // MARK: - Strategy 4 (Page Navigation)
        private func attemptExtractionStrategy4(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
            print("STRATEGY 4: Starting simplified page menu extraction")
            
            // Simplified detection script
            let detectionScript = """
            (function() {
                // Look for obvious page navigation elements
                var pageElements = [];
                
                // Check for pagination containers
                var paginationSelectors = [
                    '.pagination',
                    '.page-nav',
                    '.pages',
                    '.page-numbers',
                    '.pager',
                    '[class*="page"]',
                    '[id*="page"]'
                ];
                
                for (var i = 0; i < paginationSelectors.length; i++) {
                    var elements = document.querySelectorAll(paginationSelectors[i]);
                    elements.forEach(function(el) {
                        if (el.textContent && el.textContent.match(/\\d/)) {
                            pageElements.push({
                                type: 'container',
                                element: el.outerHTML.substring(0, 200),
                                text: el.textContent.trim().substring(0, 100)
                            });
                        }
                    });
                }
                
                // Look for page links/buttons
                var allClickables = document.querySelectorAll('a, button, [onclick]');
                var pageLinks = [];
                
                for (var i = 0; i < allClickables.length; i++) {
                    var el = allClickables[i];
                    var text = (el.textContent || el.innerText || '').trim();
                    
                    if (text.match(/Page\\s*\\d+/i) ||
                        text.match(/\\d+\\s*\\/\\s*\\d+/) ||
                        text.match(/^\\d+$/) && text.length < 4) {
                        
                        pageLinks.push({
                            index: i,
                            text: text,
                            tag: el.tagName
                        });
                    }
                }
                
                return {
                    pageContainers: pageElements,
                    pageLinks: pageLinks,
                    summary: {
                        containers: pageElements.length,
                        links: pageLinks.length
                    }
                };
            })();
            """
            
            webView.evaluateJavaScript(detectionScript) { [weak self] result, error in
                if let error = error {
                    print("Strategy 4 - Detection failed: \(error)")
                    completion([])
                    return
                }
                
                print("Strategy 4 - Detection completed")
                
                guard let detectionData = result as? [String: Any],
                      let pageLinks = detectionData["pageLinks"] as? [[String: Any]] else {
                    print("Strategy 4 - No page navigation detected")
                    completion([])
                    return
                }
                
                let linkCount = pageLinks.count
                print("Strategy 4 - Found \(linkCount) page links")
                
                if linkCount > 0 {
                    // Instead of complex navigation, just extract from current page
                    // and simulate multiple page loads by modifying the URL
                    self?.extractWithSimulatedPagination(webView: webView,
                                                       pageLinks: pageLinks,
                                                       completion: completion)
                } else {
                    completion([])
                }
            }
        }
        
    private func extractWithSimulatedPagination(webView: WKWebView,
                                              pageLinks: [[String: Any]],
                                              completion: @escaping ([EnhancedImageInfo]) -> Void) {
        print("Strategy 4 - Using simulated pagination with \(pageLinks.count) links")
        
        var allImages: [EnhancedImageInfo] = []
        let maxPagesToExtract = min(30, pageLinks.count) // Max 30 pages to click
        var consecutiveSameImageCount = 0
        var lastImageCount = 0
        
        func extractPage(_ pageIndex: Int) {
            guard pageIndex < maxPagesToExtract else {
                // All pages processed
                let uniqueImages = self.removeDuplicateImages(allImages)
                
                // FILTER OUT IMAGES WITH THE EXACT LOGO SIZE (79x97) IN STRATEGY 4
                let filteredImages = uniqueImages.filter { image in
                    if image.width == 79 && image.height == 97 {
                        print("Strategy 4 - Filtering out logo-sized image: \(image.src) - size: \(image.width)×\(image.height)")
                        return false
                    }
                    return true
                }
                
                print("Strategy 4 - Completed extracting pages, found \(filteredImages.count) unique images after filtering")
                completion(filteredImages)
                return
            }
            
            print("Strategy 4 - Extracting page \(pageIndex + 1)/\(maxPagesToExtract)")
            
            let clickScript = """
            (function() {
                var pageLinks = \(self.convertToJSONString(pageLinks));
                if (pageLinks.length > \(pageIndex)) {
                    var linkInfo = pageLinks[\(pageIndex)];
                    var elements = document.querySelectorAll('a, button, [onclick]');
                    if (elements.length > linkInfo.index) {
                        elements[linkInfo.index].click();
                        return { success: true, page: \(pageIndex + 1) };
                    }
                }
                return { success: false };
            })();
            """
            
            webView.evaluateJavaScript(clickScript) { clickResult, error in
                if let error = error {
                    print("Strategy 4 - Page \(pageIndex) click failed: \(error)")
                }
                
                // Wait for navigation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Wait 1 seconds between page change
                    self.extractCurrentPageImages(webView: webView) { images in
                        let currentImageCount = images.count
                        print("Strategy 4 - Page \(pageIndex + 1) yielded \(currentImageCount) images")
                        
                        // Check if we're getting the same number of images consecutively
                        if currentImageCount == lastImageCount {
                            consecutiveSameImageCount += 1
                            print("Strategy 4 - Consecutive same image count: \(consecutiveSameImageCount)")
                        } else {
                            consecutiveSameImageCount = 0
                        }
                        
                        lastImageCount = currentImageCount
                        allImages.append(contentsOf: images)
                        
                        // Stop early if last two pages had same image count
                        if consecutiveSameImageCount >= 2 {
                            print("Strategy 4 - Stopping early: last 2 pages yielded same number of images (\(currentImageCount))")
                            let uniqueImages = self.removeDuplicateImages(allImages)
                            print("Strategy 4 - Completed extracting pages early, found \(uniqueImages.count) unique images")
                            completion(uniqueImages)
                        } else {
                            // Continue to next page
                            extractPage(pageIndex + 1)
                        }
                    }
                }
            }
        }
        
        // Start extraction
        extractPage(0)
    }
    
    private func extractCurrentPageImages(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
            // Use Strategy 1 for current page extraction as it's the most reliable
            attemptExtractionStrategy1(webView: webView, completion: completion)
        }
        
        private func removeDuplicateImages(_ images: [EnhancedImageInfo]) -> [EnhancedImageInfo] {
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
        
        private func convertToJSONString(_ object: Any) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: object, options: []),
                  let jsonString = String(data: data, encoding: .utf8) else {
                return "[]"
            }
            return jsonString
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
        
        // First, group by base image (remove size variants)
        let groupedImages = groupByBaseImage(images)
        
        // Use the highest quality version from each group
        let deduplicatedImages = selectBestQualityFromGroups(groupedImages)
        
        print("=== After deduplication: \(deduplicatedImages.count) unique images ===")
        
        // Patterns for extracting meaningful page numbers
        let patterns = [
            // Blogspot patterns - match the number before .jpg
            try? NSRegularExpression(pattern: "/(\\d+)\\.(jpg|jpeg|png|gif|webp)$", options: []),
            try? NSRegularExpression(pattern: "/(\\d+)\\.(jpg|jpeg|png|gif|webp)\\?", options: []),
            try? NSRegularExpression(pattern: "/(\\d+)\\.(jpg|jpeg|png|gif|webp)", options: []),
            
            // Other common patterns
            try? NSRegularExpression(pattern: "/(l\\d+)\\.(jpg|jpeg|png|gif|webp)", options: []),
            try? NSRegularExpression(pattern: "l(\\d+)\\.(jpg|jpeg|png|gif|webp)", options: []),
            try? NSRegularExpression(pattern: "_(\\d+)\\.(jpg|jpeg|png|gif|webp)", options: []),
            try? NSRegularExpression(pattern: "page[_-]?(\\d+)", options: [.caseInsensitive]),
        ]
        
        var imageClassifications: [(image: EnhancedImageInfo, pageNumber: Int?, isMeaningful: Bool)] = []
        
        for image in deduplicatedImages {
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
        
        // Sort with priority: meaningful page numbers > DOM position
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
                print("Sorted \(index): \(pageNumber) - \(classification.image.src)")
            } else {
                print("Sorted \(index): NO MEANINGFUL NUMBER - \(classification.image.src)")
            }
        }
        
        return sortedImages
    }

    private func isMeaningfulPageNumber(in url: String, pageNumber: Int?) -> Bool {
        guard let pageNumber = pageNumber else { return false }
        
        // For blogspot URLs, check if the number appears right before the extension
        if url.contains("blogger.googleusercontent.com") {
            let patterns = [
                "/\(pageNumber)\\.jpg",
                "/\(pageNumber)\\.webp",
                "/\(pageNumber)\\.png",
                "/\(String(format: "%02d", pageNumber))\\.jpg",
                "/\(String(format: "%02d", pageNumber))\\.webp",
                "/\(String(format: "%02d", pageNumber))\\.png"
            ]
            
            for pattern in patterns {
                if url.contains(pattern) {
                    return true
                }
            }
            
            // Also check if it's in the final path component
            if let lastPath = URL(string: url)?.lastPathComponent {
                let numberFormats = [
                    "\(pageNumber).jpg", "\(pageNumber).webp", "\(pageNumber).png",
                    "\(String(format: "%02d", pageNumber)).jpg", "\(String(format: "%02d", pageNumber)).webp", "\(String(format: "%02d", pageNumber)).png"
                ]
                for format in numberFormats {
                    if lastPath == format || lastPath.hasSuffix(format) {
                        return true
                    }
                }
            }
        }
        
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
    
    private func groupByBaseImage(_ images: [EnhancedImageInfo]) -> [String: [EnhancedImageInfo]] {
        var groups: [String: [EnhancedImageInfo]] = [:]
        
        for image in images {
            let baseUrl = getBaseImageUrl(image.src)
            if groups[baseUrl] == nil {
                groups[baseUrl] = []
            }
            groups[baseUrl]?.append(image)
        }
        
        return groups
    }

    private func getBaseImageUrl(_ url: String) -> String {
        // Remove size parameters from blogspot URLs
        // Example: /s1600/03.jpg -> /03.jpg, /s1190/03.jpg -> /03.jpg
        let pattern = "/s\\d+/"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(location: 0, length: url.count)
            return regex.stringByReplacingMatches(in: url, options: [], range: range, withTemplate: "/")
        }
        return url
    }

    private func selectBestQualityFromGroups(_ groups: [String: [EnhancedImageInfo]]) -> [EnhancedImageInfo] {
        var bestImages: [EnhancedImageInfo] = []
        
        for (_, images) in groups {
            // Prefer larger images (s1600 > s1190 > s1200)
            if let bestImage = selectBestQualityImage(images) {
                bestImages.append(bestImage)
            }
        }
        
        return bestImages
    }

    private func selectBestQualityImage(_ images: [EnhancedImageInfo]) -> EnhancedImageInfo? {
        // Priority order: s1600 (largest) > s1200 > s1190 > others
        let qualityOrder = ["s1600", "s1200", "s1190"]
        
        for quality in qualityOrder {
            if let image = images.first(where: { $0.src.contains("/\(quality)/") }) {
                return image
            }
        }
        
        // If no size found, return the first one
        return images.first
    }
    
    
    // MARK: - Download and Cache
    
    private func downloadImages(from imageInfos: [EnhancedImageInfo], onComplete: ((Bool) -> Void)? = nil) {
        Task {
            var downloadedImages: [UIImage] = []
            let totalImages = imageInfos.count
            var successfulDownloads = 0
            
            print("DOWNLOAD: Starting download of \(totalImages) images")
            
            for (index, imageInfo) in imageInfos.enumerated() {
                // Update download progress
                let progress = "\(index + 1) / \(totalImages)"
                await MainActor.run {
                    self.downloadProgress = progress
                }
                
                print("DOWNLOAD: [\(index + 1)/\(totalImages)] Attempting: \(imageInfo.src)")
                
                // Check cache first
                if let cachedImage = getCachedImage(for: imageInfo.src) {
                    print("DOWNLOAD: [\(index + 1)] Using cached image")
                    downloadedImages.append(cachedImage)
                    successfulDownloads += 1
                    continue
                }
                
                // Validate and create URL
                guard let url = URL(string: imageInfo.src) else {
                    print("DOWNLOAD: [\(index + 1)] Invalid URL: \(imageInfo.src)")
                    continue
                }
                
                print("DOWNLOAD: [\(index + 1)] Downloading from: \(url)")
                
                do {
                    // Create a proper URLRequest with timeout
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 30.0
                    request.cachePolicy = .reloadIgnoringLocalCacheData
                    
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    // Check if we got a valid response
                    if let httpResponse = response as? HTTPURLResponse {
                        print("DOWNLOAD: [\(index + 1)] HTTP Status: \(httpResponse.statusCode)")
                        
                        if httpResponse.statusCode == 200, let image = UIImage(data: data) {
                            // FINAL SIZE FILTER - check actual downloaded image size
                            if image.size.width <= 100.0 && image.size.height <= 100.0 {
                                print("DOWNLOAD: [\(index + 1)] FILTERED OUT - Logo sized image: \(image.size)")
                                continue // Skip this image
                            }
                            cacheImage(image, for: imageInfo.src)
                            downloadedImages.append(image)
                            successfulDownloads += 1
                            print("DOWNLOAD: [\(index + 1)] SUCCESS - Image size: \(image.size)")
                        } else {
                            print("DOWNLOAD: [\(index + 1)] FAILED - Invalid status code or image data")
                        }
                    } else {
                        print("DOWNLOAD: [\(index + 1)] FAILED - No HTTP response")
                    }
                } catch {
                    print("DOWNLOAD: [\(index + 1)] ERROR: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                // Clear progress when done
                self.downloadProgress = ""
                
                print("DOWNLOAD: Completed - \(successfulDownloads)/\(totalImages) successful downloads")
                
                if downloadedImages.isEmpty {
                    print("DOWNLOAD: CRITICAL - No images were successfully downloaded")
                    self.error = "Failed to download any images. Please check your connection."
                    self.isLoading = false
                    onComplete?(false)
                } else {
                    print("DOWNLOAD: SUCCESS - Setting \(downloadedImages.count) images to display")
                    // Set images and update loading state
                    self.images = downloadedImages
                    self.isLoading = false
                    onComplete?(true)
                }
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
        
        print("RETRY: Attempt \(attempt) of \(maxAttempts) - waiting \(delay) seconds")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, let webView = self.webView else {
                print("RETRY: WebView no longer available, stopping")
                onComplete?(false)
                return
            }
            
            print("RETRY: Starting extraction attempt \(attempt)")
            self.executeAllExtractionStrategies(webView: webView) { [weak self] success in
                guard let self = self else {
                    onComplete?(false)
                    return
                }
                
                if success {
                    print("RETRY: SUCCESS on attempt \(attempt) - stopping retries")
                    onComplete?(true)
                } else if attempt >= maxAttempts {
                    print("RETRY: MAX ATTEMPTS REACHED (\(maxAttempts)) - giving up")
                    Task { @MainActor in
                        self.error = "No suitable images found after \(maxAttempts) attempts"
                        self.isLoading = false
                    }
                    onComplete?(false)
                } else {
                    print("RETRY: Attempt \(attempt) failed, will retry")
                    self.attemptImageExtraction(attempt: attempt + 1, maxAttempts: maxAttempts, onComplete: onComplete)
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
