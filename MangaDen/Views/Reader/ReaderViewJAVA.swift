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
    private let imageProcessor = ImageProcessor()
    private let extractionStrategies = ExtractionStrategies()
    
    // MARK: - Timeout Configuration
    private let totalExtractionTimeout: TimeInterval = 180.0 // 180 seconds total timeout
    private var extractionTimeoutTimer: Timer?
    private var isExtractionTimedOut = false
    
    func loadChapter(url: URL) {
        isLoading = true
        error = nil
        images = []
        currentURL = url
        extractionResults = []
        isExtractionTimedOut = false
        
        // Start the global timeout timer
        startExtractionTimeoutTimer()
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = .nonPersistent()
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        self.webView = webView
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    // MARK: - Timeout Management
    
    private func startExtractionTimeoutTimer() {
        extractionTimeoutTimer?.invalidate()
        isExtractionTimedOut = false
        
        extractionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: totalExtractionTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isExtractionTimedOut = true
                print("EXTRACTION TIMEOUT: 180 seconds elapsed - stopping all extraction processes")
                
                self.error = "Extraction timed out after 180 seconds"
                self.isLoading = false
                self.cleanupExtraction()
            }
        }
    }
    
    private func stopExtractionTimeoutTimer() {
        extractionTimeoutTimer?.invalidate()
        extractionTimeoutTimer = nil
    }
    
    private func cleanupExtraction() {
        stopExtractionTimeoutTimer()
        webView?.stopLoading()
    }
    
    // MARK: - Enhanced Extraction with Strategy 5
    
    private func executeAllExtractionStrategies(webView: WKWebView, onComplete: @escaping (Bool) -> Void) {
        // Check if we've already timed out
        guard !isExtractionTimedOut else {
            print("EXTRACTION: Skipping strategies - already timed out")
            onComplete(false)
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var strategyResults: [ExtractionResult] = []
        var completedStrategies = 0
        
        print("EXTRACTION: Starting all extraction strategies including Strategy 5")
        
        // Execute strategies 1-4 first
        let strategies = [
            extractionStrategies.attemptExtractionStrategy1,
            extractionStrategies.attemptExtractionStrategy2,
            extractionStrategies.attemptExtractionStrategy3,
            extractionStrategies.attemptExtractionStrategy4
        ]
        
        for (index, strategy) in strategies.enumerated() {
            // Check timeout before starting each strategy
            guard !isExtractionTimedOut else {
                print("EXTRACTION: Stopping strategy \(index + 1) - timeout reached")
                break
            }
            
            dispatchGroup.enter()
            print("EXTRACTION: Starting Strategy \(index + 1)")
            
            strategy(webView) { images in
                // Check if we timed out during strategy execution
                if !self.isExtractionTimedOut {
                    strategyResults.append(ExtractionResult(strategy: index + 1, images: images))
                    completedStrategies += 1
                    print("EXTRACTION: Strategy \(index + 1) completed with \(images.count) images (completed: \(completedStrategies)/4)")
                } else {
                    print("EXTRACTION: Strategy \(index + 1) result ignored - timeout reached")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else {
                onComplete(false)
                return
            }
            
            // Check timeout before proceeding
            guard !self.isExtractionTimedOut else {
                print("EXTRACTION: Stopping after strategies 1-4 - timeout reached")
                onComplete(false)
                return
            }
            
            print("EXTRACTION: ALL STRATEGIES 1-4 COMPLETED")
            let totalImages = strategyResults.reduce(0) { $0 + $1.images.count }
            let maxImagesFromSingleStrategy = strategyResults.map { $0.images.count }.max() ?? 0
            
            print("EXTRACTION: Strategies 1-4 found \(totalImages) total images")
            for result in strategyResults {
                print("EXTRACTION: Strategy \(result.strategy) found \(result.images.count) images")
            }
            
            self.extractionResults = strategyResults
            
            // Decision logic for Strategy 5
            let shouldTryStrategy5 = maxImagesFromSingleStrategy <= 10
            
            if shouldTryStrategy5 {
                print("EXTRACTION: STRATEGY 5 TRIGGERED - No strategy found more than 10 images (max: \(maxImagesFromSingleStrategy))")
                print("EXTRACTION: STARTING STRATEGY 5 - Page Menu Extraction")
                
                // Stop timeout timer during Strategy 5 since it has its own early stopping
                self.stopExtractionTimeoutTimer()
                
                self.extractionStrategies.attemptExtractionStrategy5(webView: webView) { [weak self] strategy5Images in
                    guard let self = self else {
                        onComplete(false)
                        return
                    }
                    
                    // Restart timeout timer for the download phase
                    self.startExtractionTimeoutTimer()
                    
                    print("EXTRACTION: STRATEGY 5 COMPLETED - Found \(strategy5Images.count) images")
                    strategyResults.append(ExtractionResult(strategy: 5, images: strategy5Images))
                    self.extractionResults = strategyResults
                    
                    let bestOrder = self.findBestImageOrder(from: strategyResults)
                    print("EXTRACTION: Final best order has \(bestOrder.count) images")
                    
                    if bestOrder.isEmpty {
                        print("EXTRACTION: No images found after all strategies including Strategy 5")
                        self.stopExtractionTimeoutTimer()
                        onComplete(false)
                    } else {
                        self.processAndDownloadImages(bestOrder, onComplete: onComplete)
                    }
                }
            } else {
                let bestOrder = self.findBestImageOrder(from: strategyResults)
                print("EXTRACTION: Sufficient images found (max: \(maxImagesFromSingleStrategy) per strategy), skipping Strategy 5")
                print("EXTRACTION: Best order has \(bestOrder.count) images")
                
                if bestOrder.isEmpty {
                    self.stopExtractionTimeoutTimer()
                    onComplete(false)
                } else {
                    self.processAndDownloadImages(bestOrder, onComplete: onComplete)
                }
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
        
        // Strategy selection logic:
        // 1. Prefer strategies that found more images
        // 2. If Strategy 5 found images, consider using it
        // 3. Remove duplicates across strategies
        
        var allImages: [EnhancedImageInfo] = []
        var seenURLs = Set<String>()
        
        // Process strategies in order of preference
        let preferredOrder = [5, 2, 1, 4, 3] // Strategy 5 first if available, then 2, etc.
        
        for strategyNum in preferredOrder {
            if let result = nonEmptyResults.first(where: { $0.strategy == strategyNum }) {
                for image in result.images {
                    if !seenURLs.contains(image.src) {
                        seenURLs.insert(image.src)
                        allImages.append(image)
                    }
                }
            }
        }
        
        // If we still don't have images, use the strategy with the most images
        if allImages.isEmpty, let bestResult = nonEmptyResults.max(by: { $0.images.count < $1.images.count }) {
            print("Using strategy \(bestResult.strategy) with \(bestResult.images.count) images (most found)")
            return bestResult.images
        }
        
        print("Final combined image count: \(allImages.count)")
        return allImages
    }
    
    // MARK: - Improved Processing
    
    private func processAndDownloadImages(_ imageInfos: [EnhancedImageInfo], onComplete: ((Bool) -> Void)? = nil) {
        print("Processing \(imageInfos.count) images...")
        
        // Enhanced filtering - remove problematic URLs
        let filteredImages = imageInfos.filter { image in
            // Remove images with obviously invalid URLs
            guard !image.src.isEmpty,
                  image.src.hasPrefix("http"),
                  !image.src.contains("+Math.random()"),
                  !image.src.contains("javascript:"),
                  !image.src.contains("data:text/html") else {
                return false
            }
            
            // Remove known problematic domains or paths
            let problematicPatterns = [
                "logo-sm.png",
                "assets/sites/mangafire/logo",
                "avatar",
                "icon",
                "banner",
                "ads"
            ]
            
            for pattern in problematicPatterns {
                if image.src.contains(pattern) {
                    return false
                }
            }
            
            // Keep images that look like actual manga pages
            return image.src.contains("/h/p.jpg") ||
                   image.src.contains("mangafox") ||
                   image.src.contains("mfcdn")
        }
        
        print("After filtering: \(filteredImages.count) images (removed \(imageInfos.count - filteredImages.count) problematic URLs)")
        
        if filteredImages.isEmpty {
            print("No valid manga images found after filtering")
            onComplete?(false)
            return
        }
        
        let sortedImages = imageProcessor.intelligentImageSorting(filteredImages)
        print("Final order: \(sortedImages.count) images")
        
        downloadImages(from: sortedImages, onComplete: onComplete)
    }
    
    // MARK: - Download and Cache
    private func downloadImages(from imageInfos: [EnhancedImageInfo], onComplete: ((Bool) -> Void)? = nil) {
        Task {
            var downloadedImages: [UIImage] = []
            
            // Further reduce limit for memory safety
            let maxImagesToDownload = min(50, imageInfos.count) // Max images to download is 50
            let imagesToDownload = Array(imageInfos.prefix(maxImagesToDownload))
            
            print("Downloading \(imagesToDownload.count) images (limited from \(imageInfos.count))")
            
            for (index, imageInfo) in imagesToDownload.enumerated() {
                // Check if we've been cancelled or timed out
                if self.isExtractionTimedOut {
                    print("Download cancelled - extraction timed out")
                    break
                }
                
                print("Downloading \(index + 1)/\(imagesToDownload.count): \(imageInfo.src)")
                
                if let cachedImage = getCachedImage(for: imageInfo.src) {
                    downloadedImages.append(cachedImage)
                    continue
                }
                
                guard let url = URL(string: imageInfo.src) else {
                    print("Invalid URL: \(imageInfo.src)")
                    continue
                }
                
                do {
                    // Try normal download first
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 30
                    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                    
                    let (data, _) = try await URLSession.shared.data(for: request)
                    if let image = UIImage(data: data) {
                        // CHANGED: More aggressive scaling for memory safety
                        let scaledImage = scaleImageForMemorySafety(image)
                        cacheImage(scaledImage, for: imageInfo.src)
                        downloadedImages.append(scaledImage)
                        print("Downloaded image \(index + 1)")
                        
                        // CHANGED: Add small delay between downloads to reduce memory pressure
                        if index < imagesToDownload.count - 1 {
                            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                        }
                    }
                } catch {
                    print("Download failed for \(imageInfo.src): \(error)")
                }
            }
            
            await MainActor.run {
                // Only consider it successful if we got more than just the logo
                let hasMeaningfulImages = downloadedImages.count > 1
                
                if !hasMeaningfulImages {
                    self.error = "Failed to download manga images"
                    onComplete?(false)
                } else {
                    self.images = downloadedImages
                    print("Successfully downloaded \(downloadedImages.count) images")
                    onComplete?(true)
                }
                self.isLoading = false
                self.stopExtractionTimeoutTimer()
            }
        }
    }

    // More aggressive image scaling for memory safety
    private func scaleImageForMemorySafety(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1600 // Max dimension of 1600 px for panel images
        
        let size = image.size
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        let scaleFactor = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        
        // CHANGED: Use lower quality for significant memory savings
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.8)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage ?? image
    }
    
    private func downloadWithAlternativeApproach(url: URL) async -> UIImage? {
        // Try different approaches for problematic domains
        do {
            // Approach 1: Try with ephemeral session (no caching)
            let ephemeralConfig = URLSessionConfiguration.ephemeral
            ephemeralConfig.timeoutIntervalForRequest = 30
            let ephemeralSession = URLSession(configuration: ephemeralConfig)
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            // Add some headers that might help
            request.setValue("image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            
            let (data, _) = try await ephemeralSession.data(for: request)
            return UIImage(data: data)
        } catch {
            print("Alternative download also failed: \(error)")
            
            // Approach 2: Try converting http to https or vice versa
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if components.scheme == "https" {
                    components.scheme = "http"
                } else if components.scheme == "http" {
                    components.scheme = "https"
                }
                
                if let modifiedURL = components.url {
                    print("Trying modified URL: \(modifiedURL.absoluteString)")
                    do {
                        let (data, _) = try await URLSession.shared.data(from: modifiedURL)
                        return UIImage(data: data)
                    } catch {
                        print("Modified URL also failed: \(error)")
                    }
                }
            }
        }
        
        return nil
    }
    
    private func scaleImageIfNeeded(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 2000 // Limit image size to prevent memory issues
        
        let size = image.size
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        let scaleFactor = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage ?? image
    }
    
    private func isLogoImage(_ image: UIImage?) -> Bool {
        guard let image = image else { return true }
        // Simple heuristic: logo images are usually small
        return image.size.width < 200 && image.size.height < 200
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
        stopExtractionTimeoutTimer()
        
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date.distantPast,
            completionHandler: {}
        )
    }
    
    // MARK: - Retry Logic with Strategy 5
    
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
    
    // MARK: - Debug Information
    
    func getExtractionDebugInfo() -> String {
        var debugInfo = "Extraction Results:\n"
        debugInfo += "Total Strategies: \(extractionResults.count)\n"
        
        for result in extractionResults {
            debugInfo += "Strategy \(result.strategy): \(result.images.count) images\n"
        }
        
        debugInfo += "Final Images: \(images.count)\n"
        debugInfo += "Cache Size: \(imageCache.count)"
        
        return debugInfo
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
            self.cleanupExtraction()
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.error = "Failed to load page: \(error.localizedDescription)"
            self.isLoading = false
            self.cleanupExtraction()
        }
    }
}
