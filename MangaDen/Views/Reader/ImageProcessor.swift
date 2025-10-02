//
//  ImageProcessor.swift
//  MangaDen
//
//  Created by Brody Wells on 10/1/25.
//

import SwiftUI

class ImageProcessor {
    
    func intelligentImageSorting(_ images: [EnhancedImageInfo]) -> [EnhancedImageInfo] {
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

    func isMeaningfulPageNumber(in url: String, pageNumber: Int?) -> Bool {
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
}
