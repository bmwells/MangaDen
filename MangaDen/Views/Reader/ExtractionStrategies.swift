//
//  ExtractionStrategies.swift
//  MangaDen
//
//  Created by Brody Wells on 10/1/25.
//

import WebKit

class ExtractionStrategies {
    
    // MARK: - Strategy 1
    func attemptExtractionStrategy1(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
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
                return url.match(/\\.(jpg|jpeg|png|gif|webp|bmp)(?:\\?|$)/i) &&
                       (url.includes('bp.blogspot.com') ||
                        url.includes('blogspot') ||
                        url.includes('mangafox') ||
                        url.includes('lowee.us') ||
                        url.includes('/chapter/') ||
                        url.includes('/Chapter/') ||
                        url.includes('page') ||
                        url.includes('Page') ||
                        url.match(/\\d/));
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
    
    // MARK: - Strategy 2: Async scrolling and loading
    func attemptExtractionStrategy2(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
        print("STRATEGY 2: Starting enhanced extraction with scrolling")
        
        // Step 1: Scroll to trigger lazy loading
        let scrollScript = """
        (function() {
            return new Promise((resolve) => {
                var scrollHeight = document.body.scrollHeight;
                var currentScroll = 0;
                var scrollStep = Math.max(scrollHeight / 4, 500);
                
                function scrollStepByStep() {
                    if (currentScroll < scrollHeight) {
                        window.scrollTo(0, currentScroll);
                        currentScroll += scrollStep;
                        setTimeout(scrollStepByStep, 300);
                    } else {
                        // Final scroll to bottom
                        window.scrollTo(0, scrollHeight);
                        setTimeout(resolve, 1000);
                    }
                }
                
                scrollStepByStep();
            });
        })();
        """
        
        // Step 2: After scrolling, extract images
        let extractScript = """
        (function() {
            var images = [];
            
            // Get all images after scrolling
            var imgElements = document.querySelectorAll('img');
            for (var i = 0; i < imgElements.length; i++) {
                var img = imgElements[i];
                var src = img.currentSrc || img.src || '';
                
                if (src && isImageUrl(src)) {
                    var rect = img.getBoundingClientRect();
                    images.push({
                        src: src,
                        width: rect.width,
                        height: rect.height,
                        position: i,
                        naturalWidth: img.naturalWidth,
                        naturalHeight: img.naturalHeight,
                        visible: rect.width > 0 && rect.height > 0
                    });
                }
            }
            
            // Check various data attributes for lazy loaded images
            var dataAttrs = ['data-src', 'data-url', 'data-image', 'data-original', 'data-lazy-src', 'data-lazyload'];
            for (var i = 0; i < dataAttrs.length; i++) {
                var attr = dataAttrs[i];
                var elements = document.querySelectorAll('[' + attr + ']');
                for (var j = 0; j < elements.length; j++) {
                    var el = elements[j];
                    var value = el.getAttribute(attr);
                    if (value && isImageUrl(value)) {
                        var rect = el.getBoundingClientRect();
                        images.push({
                            src: value,
                            width: rect.width,
                            height: rect.height,
                            position: imgElements.length + j,
                            fromAttribute: attr,
                            visible: rect.width > 0 && rect.height > 0
                        });
                    }
                }
            }
            
            function isImageUrl(url) {
                return url.match(/\\.(jpg|jpeg|png|gif|webp|bmp)(?:\\?|$)/i) &&
                       (url.includes('bp.blogspot.com') ||
                        url.includes('blogspot') ||
                        url.includes('mangafox') ||
                        url.includes('lowee.us') ||
                        url.includes('/chapter/') ||
                        url.includes('/Chapter/') ||
                        url.includes('page') ||
                        url.includes('Page') ||
                        url.match(/\\d/));
            }
            
            return images;
        })();
        """
        
        // Execute scrolling first, then extraction
        webView.evaluateJavaScript(scrollScript) { [weak self] _, error in
            if let error = error {
                print("Strategy 2 scrolling failed: \(error)")
            }
            
            // Wait a bit more for images to load after scrolling
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                webView.evaluateJavaScript(extractScript) { result, error in
                    if let error = error {
                        print("Strategy 2 extraction failed: \(error)")
                        completion([])
                        return
                    }
                    
                    guard let imageDicts = result as? [[String: Any]] else {
                        completion([])
                        return
                    }
                    
                    let imageInfos = self?.parseImageDicts(imageDicts) ?? []
                    print("Strategy 2 parsed \(imageInfos.count) images")
                    completion(imageInfos)
                }
            }
        }
    }
    
    // MARK: - Strategy 3
    func attemptExtractionStrategy3(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
        let jsScript = """
        (function() {
            var html = document.documentElement.outerHTML;
            var imageUrls = [];
            
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
    
    // MARK: - Strategy 4
    func attemptExtractionStrategy4(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
        let jsScript = """
        (function() {
            function getElementTop(element) {
                var rect = element.getBoundingClientRect();
                return rect.top + window.pageYOffset;
            }
            
            var images = [];
            var imgElements = Array.from(document.querySelectorAll('img'));
            
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
    
    // MARK: - Strategy 5: Page Navigation
    func attemptExtractionStrategy5(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
        print("STRATEGY 5: Starting simplified page menu extraction")
        
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
                print("Strategy 5 - Detection failed: \(error)")
                completion([])
                return
            }
            
            print("Strategy 5 - Detection completed")
            
            guard let detectionData = result as? [String: Any],
                  let pageLinks = detectionData["pageLinks"] as? [[String: Any]] else {
                print("Strategy 5 - No page navigation detected")
                completion([])
                return
            }
            
            let linkCount = pageLinks.count
            print("Strategy 5 - Found \(linkCount) page links")
            
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
        print("Strategy 5 - Using simulated pagination with \(pageLinks.count) links")
        
        var allImages: [EnhancedImageInfo] = []
        let maxPagesToExtract = min(30, pageLinks.count) // Max 30 pages to click
        var consecutiveSameImageCount = 0
        var lastImageCount = 0
        
        func extractPage(_ pageIndex: Int) {
            guard pageIndex < maxPagesToExtract else {
                // All pages processed
                let uniqueImages = self.removeDuplicateImages(allImages)
                print("Strategy 5 - Completed extracting pages, found \(uniqueImages.count) unique images")
                completion(uniqueImages)
                return
            }
            
            print("Strategy 5 - Extracting page \(pageIndex + 1)/\(maxPagesToExtract)")
            
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
                    print("Strategy 5 - Page \(pageIndex) click failed: \(error)")
                }
                
                // Wait for navigation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Wait 1 seconds between page change
                    self.extractCurrentPageImages(webView: webView) { images in
                        let currentImageCount = images.count
                        print("Strategy 5 - Page \(pageIndex + 1) yielded \(currentImageCount) images")
                        
                        // Check if we're getting the same number of images consecutively
                        if currentImageCount == lastImageCount {
                            consecutiveSameImageCount += 1
                            print("Strategy 5 - Consecutive same image count: \(consecutiveSameImageCount)")
                        } else {
                            consecutiveSameImageCount = 0
                        }
                        
                        lastImageCount = currentImageCount
                        allImages.append(contentsOf: images)
                        
                        // Stop early if last two pages had same image count
                        if consecutiveSameImageCount >= 2 {
                            print("Strategy 5 - Stopping early: last 2 pages yielded same number of images (\(currentImageCount))")
                            let uniqueImages = self.removeDuplicateImages(allImages)
                            print("Strategy 5 - Completed extracting pages early, found \(uniqueImages.count) unique images")
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
    
    private func removeDuplicateImages(_ images: [EnhancedImageInfo]) -> [EnhancedImageInfo] {
        var seenSrcs = Set<String>()
        var uniqueImages: [EnhancedImageInfo] = []
        
        for image in images {
            if !seenSrcs.contains(image.src) {
                seenSrcs.insert(image.src)
                uniqueImages.append(image)
            }
        }
        
        return uniqueImages
    }
    
    // MARK: - Helper Methods (unchanged)
    private func extractCurrentPageImages(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
        let imageScript = """
        (function() {
            var images = [];
            var imgElements = document.querySelectorAll('img');
            
            for (var i = 0; i < imgElements.length; i++) {
                var img = imgElements[i];
                var src = img.currentSrc || img.src;
                if (src && src.match(/\\.(jpg|jpeg|png|gif|webp|bmp)(?:\\?|$)/i)) {
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
            
            return images;
        })();
        """
        
        webView.evaluateJavaScript(imageScript) { result, error in
            if let error = error {
                print("Strategy 5 - Failed to extract images from current page: \(error)")
                completion([])
                return
            }
            
            guard let imageDicts = result as? [[String: Any]] else {
                completion([])
                return
            }
            
            let imageInfos = self.parseImageDicts(imageDicts)
            completion(imageInfos)
        }
    }
    
    private func convertToJSONString(_ object: Any) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: object, options: [])
            return String(data: jsonData, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
    
    // MARK: - Updated executeAllExtractionStrategies method
    func executeAllExtractionStrategies(webView: WKWebView, onComplete: @escaping ([EnhancedImageInfo]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var strategyResults: [ExtractionResult] = []
        var completedStrategies = 0
        
        print("EXTRACTION: Starting all extraction strategies")
        
        // Execute strategies 1-4 first
        let strategies = [
            self.attemptExtractionStrategy1,
            self.attemptExtractionStrategy2,
            self.attemptExtractionStrategy3,
            self.attemptExtractionStrategy4
        ]
        
        for (index, strategy) in strategies.enumerated() {
            dispatchGroup.enter()
            print("EXTRACTION: Starting Strategy \(index + 1)")
            
            strategy(webView) { images in
                strategyResults.append(ExtractionResult(strategy: index + 1, images: images))
                completedStrategies += 1
                print("EXTRACTION: Strategy \(index + 1) completed with \(images.count) images (completed: \(completedStrategies)/4)")
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else {
                onComplete([])
                return
            }
            
            print("EXTRACTION: ALL STRATEGIES 1-4 COMPLETED")
            let totalImages = strategyResults.reduce(0) { $0 + $1.images.count }
            let maxImagesFromSingleStrategy = strategyResults.map { $0.images.count }.max() ?? 0
            
            print("EXTRACTION: Strategies 1-4 found \(totalImages) total images")
            for result in strategyResults {
                print("EXTRACTION: Strategy \(result.strategy) found \(result.images.count) images")
            }
            
            // Only try Strategy 5 if no single strategy found more than 10 images
            let shouldTryStrategy5 = maxImagesFromSingleStrategy <= 10
            
            if shouldTryStrategy5 {
                print("EXTRACTION: STRATEGY 5 TRIGGERED - No strategy found more than 10 images (max: \(maxImagesFromSingleStrategy))")
                print("EXTRACTION: STARTING STRATEGY 5 - Page Menu Extraction")
                self.attemptExtractionStrategy5(webView: webView) { strategy5Images in
                    print("EXTRACTION: STRATEGY 5 COMPLETED - Found \(strategy5Images.count) images")
                    strategyResults.append(ExtractionResult(strategy: 5, images: strategy5Images))
                    let allImages = strategyResults.flatMap { $0.images }
                    print("EXTRACTION: FINAL RESULTS - \(allImages.count) total images after Strategy 5")
                    onComplete(allImages)
                }
            } else {
                let allImages = strategyResults.flatMap { $0.images }
                print("EXTRACTION: Sufficient images found (max: \(maxImagesFromSingleStrategy) per strategy), skipping Strategy 5")
                onComplete(allImages)
            }
        }
    }
    
    // MARK: - Image Dict Parsing (unchanged)
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
