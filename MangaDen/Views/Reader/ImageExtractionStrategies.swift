//
//  ImageExtractionStrategies.swift
//  MangaDen
//
//  Created by Brody Wells on 10/7/25.
//

import WebKit

class ImageExtractionStrategies {
    
    // MARK: - Strategy 1 (Direct DOM inspection)
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
    func attemptExtractionStrategy2(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
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
    
    // MARK: - Strategy 3 (Position-based DOM)
    func attemptExtractionStrategy3(webView: WKWebView, completion: @escaping ([EnhancedImageInfo]) -> Void) {
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
    
    // MARK: - Strategy 0 (Page Navigation)
    func attemptExtractionStrategy0(webView: WKWebView, isCancelled: @escaping () -> Bool = { false }, completion: @escaping ([EnhancedImageInfo]) -> Void) {
        print("Strategy 0: Starting simplified page menu extraction")
        
        // Check for cancellation before starting
        if isCancelled() {
            print("Strategy 0: Cancellation detected before starting")
            completion([])
            return
        }
        
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
            // Check for cancellation after detection
            if isCancelled() {
                print("Strategy 0: Cancellation detected after detection")
                completion([])
                return
            }
            
            if let error = error {
                print("Strategy 0 - Detection failed: \(error)")
                completion([])
                return
            }
            
            print("Strategy 0 - Detection completed")
            
            guard let detectionData = result as? [String: Any],
                  let pageLinks = detectionData["pageLinks"] as? [[String: Any]] else {
                print("Strategy 0 - No page navigation detected")
                completion([])
                return
            }
            
            let linkCount = pageLinks.count
            print("Strategy 0 - Found \(linkCount) page links")
            
            if linkCount > 0 {
                // Instead of complex navigation, just extract from current page
                // and simulate multiple page loads by modifying the URL
                self?.extractWithSimulatedPagination(webView: webView,
                                                   pageLinks: pageLinks,
                                                   isCancelled: isCancelled,
                                                   completion: completion)
            } else {
                completion([])
            }
        }
    }

    private func extractWithSimulatedPagination(webView: WKWebView,
                                              pageLinks: [[String: Any]],
                                              isCancelled: @escaping () -> Bool,
                                              completion: @escaping ([EnhancedImageInfo]) -> Void) {
        print("Strategy 0 - Using simulated pagination with \(pageLinks.count) links")
        
        var allImages: [EnhancedImageInfo] = []
        let maxPagesToExtract = min(30, pageLinks.count) // Max 30 pages to click
        var consecutiveSameImageCount = 0
        var lastImageCount = 0
        
        func extractPage(_ pageIndex: Int) {
            // Check for cancellation at the start of each page extraction
            if isCancelled() {
                print("Strategy 0: Cancellation detected during page extraction at page \(pageIndex)")
                let uniqueImages = self.removeDuplicateImages(allImages)
                
                // FILTER OUT IMAGES WITH THE EXACT LOGO SIZE (79x97) IN Strategy 0
                let filteredImages = uniqueImages.filter { image in
                    if image.width == 79 && image.height == 97 {
                        print("Strategy 0 - Filtering out logo-sized image: \(image.src) - size: \(image.width)×\(image.height)")
                        return false
                    }
                    return true
                }
                
                print("Strategy 0 - Cancelled during extraction, found \(filteredImages.count) unique images so far")
                completion(filteredImages)
                return
            }
            
            guard pageIndex < maxPagesToExtract else {
                // All pages processed
                let uniqueImages = self.removeDuplicateImages(allImages)
                
                // FILTER OUT IMAGES WITH THE EXACT LOGO SIZE (79x97) IN Strategy 0
                let filteredImages = uniqueImages.filter { image in
                    if image.width == 79 && image.height == 97 {
                        print("Strategy 0 - Filtering out logo-sized image: \(image.src) - size: \(image.width)×\(image.height)")
                        return false
                    }
                    return true
                }
                
                print("Strategy 0 - Completed extracting pages, found \(filteredImages.count) unique images after filtering")
                completion(filteredImages)
                return
            }
            
            print("Strategy 0 - Extracting page \(pageIndex + 1)/\(maxPagesToExtract)")
            
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
                // Check for cancellation after click
                if isCancelled() {
                    print("Strategy 0: Cancellation detected after page click at page \(pageIndex)")
                    let uniqueImages = self.removeDuplicateImages(allImages)
                    
                    // FILTER OUT IMAGES WITH THE EXACT LOGO SIZE (79x97) IN Strategy 0
                    let filteredImages = uniqueImages.filter { image in
                        if image.width == 79 && image.height == 97 {
                            print("Strategy 0 - Filtering out logo-sized image: \(image.src) - size: \(image.width)×\(image.height)")
                            return false
                        }
                        return true
                    }
                    
                    print("Strategy 0 - Cancelled after click, found \(filteredImages.count) unique images so far")
                    completion(filteredImages)
                    return
                }
                
                if let error = error {
                    print("Strategy 0 - Page \(pageIndex) click failed: \(error)")
                }
                
                // Wait for navigation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Wait 1 seconds between page change
                    // Check for cancellation after delay
                    if isCancelled() {
                        print("Strategy 0: Cancellation detected after delay at page \(pageIndex)")
                        let uniqueImages = self.removeDuplicateImages(allImages)
                        
                        // FILTER OUT IMAGES WITH THE EXACT LOGO SIZE (79x97) IN Strategy 0
                        let filteredImages = uniqueImages.filter { image in
                            if image.width == 79 && image.height == 97 {
                                print("Strategy 0 - Filtering out logo-sized image: \(image.src) - size: \(image.width)×\(image.height)")
                                return false
                            }
                            return true
                        }
                        
                        print("Strategy 0 - Cancelled after delay, found \(filteredImages.count) unique images so far")
                        completion(filteredImages)
                        return
                    }
                    
                    self.extractCurrentPageImages(webView: webView) { images in
                        // Check for cancellation after image extraction
                        if isCancelled() {
                            print("Strategy 0: Cancellation detected after image extraction at page \(pageIndex)")
                            let uniqueImages = self.removeDuplicateImages(allImages)
                            
                            // FILTER OUT IMAGES WITH THE EXACT LOGO SIZE (79x97) IN Strategy 0
                            let filteredImages = uniqueImages.filter { image in
                                if image.width == 79 && image.height == 97 {
                                    print("Strategy 0 - Filtering out logo-sized image: \(image.src) - size: \(image.width)×\(image.height)")
                                    return false
                                }
                                return true
                            }
                            
                            print("Strategy 0 - Cancelled after extraction, found \(filteredImages.count) unique images so far")
                            completion(filteredImages)
                            return
                        }
                        
                        let currentImageCount = images.count
                        print("Strategy 0 - Page \(pageIndex + 1) yielded \(currentImageCount) images")
                        
                        // Check if we're getting the same number of images consecutively
                        if currentImageCount == lastImageCount {
                            consecutiveSameImageCount += 1
                            print("Strategy 0 - Consecutive same image count: \(consecutiveSameImageCount)")
                        } else {
                            consecutiveSameImageCount = 0
                        }
                        
                        lastImageCount = currentImageCount
                        allImages.append(contentsOf: images)
                        
                        // Stop early if last two pages had same image count
                        if consecutiveSameImageCount >= 2 {
                            print("Strategy 0 - Stopping early: last 2 pages yielded same number of images (\(currentImageCount))")
                            let uniqueImages = self.removeDuplicateImages(allImages)
                            print("Strategy 0 - Completed extracting pages early, found \(uniqueImages.count) unique images")
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
