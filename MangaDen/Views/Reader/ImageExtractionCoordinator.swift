//
//  ImageExtractionCoordinator.swift
//  MangaDen
//
//  Created by Brody Wells on 10/7/25.
//


//
//  ImageExtractionCoordinator.swift
//  MangaDen
//
//  Created by Brody Wells on 9/2/25.
//

import WebKit
import UIKit

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


@MainActor
class ImageExtractionCoordinator: ObservableObject {
    @Published var images: [UIImage] = []
    
    private var extractionResults: [ExtractionResult] = []
    private let extractionStrategies = ImageExtractionStrategies()
    
    // MARK: - Image Cache (merged from ImageCacheManager)
    private var imageCache: [String: UIImage] = [:]
    
    private func getCachedImage(for key: String) -> UIImage? {
        return imageCache[key]
    }
    
    private func cacheImage(_ image: UIImage, for key: String) {
        imageCache[key] = image
    }
    
    func clearCache() {
        imageCache.removeAll()
    }
    
    // MARK: - Execute All Strategies
        
    func executeAllExtractionStrategies(webView: WKWebView, onComplete: @escaping (Bool) -> Void) {
        let dispatchGroup = DispatchGroup()
        var strategyResults: [ExtractionResult] = []
        var completedStrategies = 0
        
        print("EXTRACTION: Starting all extraction strategies")
        
        // Execute strategies 1-3 first
        let strategies = [
            extractionStrategies.attemptExtractionStrategy1,
            extractionStrategies.attemptExtractionStrategy2,
            extractionStrategies.attemptExtractionStrategy3
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
                self.extractionStrategies.attemptExtractionStrategy4(webView: webView) { strategy4Images in
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
    
    // MARK: - Image Processing
    
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
    
    // MARK: - Retry Logic
    
    func attemptImageExtraction(attempt: Int, maxAttempts: Int, webView: WKWebView, onComplete: ((Bool) -> Void)? = nil) {
        let delay = Double(attempt) * 2.0
        
        print("RETRY: Attempt \(attempt) of \(maxAttempts) - waiting \(delay) seconds")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else {
                print("RETRY: Coordinator no longer available, stopping")
                onComplete?(false)
                return
            }
            
            print("RETRY: Starting extraction attempt \(attempt)")
            self.executeAllExtractionStrategies(webView: webView) { success in
                if success {
                    print("RETRY: SUCCESS on attempt \(attempt) - stopping retries")
                    onComplete?(true)
                } else if attempt >= maxAttempts {
                    print("RETRY: MAX ATTEMPTS REACHED (\(maxAttempts)) - giving up")
                    onComplete?(false)
                } else {
                    print("RETRY: Attempt \(attempt) failed, will retry")
                    self.attemptImageExtraction(attempt: attempt + 1, maxAttempts: maxAttempts, webView: webView, onComplete: onComplete)
                }
            }
        }
    }
    
    // MARK: - Download and Cache
    
    private func downloadImages(from imageInfos: [EnhancedImageInfo], onComplete: ((Bool) -> Void)? = nil) {
        Task {
            var downloadedImages: [UIImage] = []
            let totalImages = imageInfos.count
            var successfulDownloads = 0
            
            print("DOWNLOAD: Starting download of \(totalImages) images")
            
            for (index, imageInfo) in imageInfos.enumerated() {
                // Update download progress would be handled by the main coordinator
                
                print("DOWNLOAD: [\(index + 1)/\(totalImages)] Attempting: \(imageInfo.src)")
                
                // Check cache first using merged cache functionality
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
                            // Cache the downloaded image using merged cache functionality
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
                print("DOWNLOAD: Completed - \(successfulDownloads)/\(totalImages) successful downloads")
                
                if downloadedImages.isEmpty {
                    print("DOWNLOAD: CRITICAL - No images were successfully downloaded")
                    onComplete?(false)
                } else {
                    print("DOWNLOAD: SUCCESS - Setting \(downloadedImages.count) images to display")
                    // Set images
                    self.images = downloadedImages
                    onComplete?(true) 
                }
            }
        }
    }
}
