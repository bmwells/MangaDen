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
    
    func loadChapter(url: URL) {
        isLoading = true
        error = nil
        images = []
        currentURL = url
        
        // Configure webview
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = .nonPersistent() // Use non-persistent storage
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        self.webView = webView
        
        // Load the URL
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func clearCache() {
        images = []
        imageCache.removeAll()
        webView?.stopLoading()
        webView = nil
        currentURL = nil
        
        // Clear webview cache
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date.distantPast,
            completionHandler: {}
        )
    }
    
    private func extractImagesFromPage() {
        guard let webView = webView else { return }
        
        // JavaScript to extract all image URLs from the page in DOM order (top to bottom)
        let jsScript = """
        (function() {
            var images = [];
            
            // Function to get element's vertical position in the document
            function getElementTop(element) {
                var rect = element.getBoundingClientRect();
                return rect.top + window.pageYOffset;
            }
            
            // Get all img elements and sort by their vertical position
            var imgElements = Array.from(document.querySelectorAll('img'));
            
            // Filter and collect images with their position
            var imageData = imgElements
                .filter(img => img.src && img.naturalWidth > 100 && img.naturalHeight > 100)
                .map(img => ({
                    src: img.src,
                    width: img.naturalWidth,
                    height: img.naturalHeight,
                    position: getElementTop(img)
                }));
            
            // Also check for images in background styles
            var allElements = Array.from(document.querySelectorAll('*'));
            var backgroundImageData = allElements
                .filter(el => {
                    var style = window.getComputedStyle(el);
                    return style.backgroundImage && style.backgroundImage !== 'none';
                })
                .map(el => {
                    var style = window.getComputedStyle(el);
                    var backgroundImage = style.backgroundImage;
                    var urlMatch = backgroundImage.match(/url\\(["']?(.*?)["']?\\)/);
                    if (urlMatch && urlMatch[1]) {
                        return {
                            src: urlMatch[1],
                            width: el.offsetWidth,
                            height: el.offsetHeight,
                            position: getElementTop(el)
                        };
                    }
                    return null;
                })
                .filter(item => item !== null);
            
            // Combine both arrays
            var allImages = imageData.concat(backgroundImageData);
            
            // Sort by vertical position (top to bottom)
            allImages.sort((a, b) => a.position - b.position);
            
            return JSON.stringify(allImages);
        })();
        """
        
        webView.evaluateJavaScript(jsScript) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                Task { @MainActor in
                    self.error = "Failed to extract images: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            guard let jsonString = result as? String,
                  let jsonData = jsonString.data(using: .utf8) else {
                Task { @MainActor in
                    self.error = "Failed to parse image data"
                    self.isLoading = false
                }
                return
            }
            
            do {
                let imageInfos = try JSONDecoder().decode([PositionedImageInfo].self, from: jsonData)
                self.processImageURLs(imageInfos)
            } catch {
                Task { @MainActor in
                    self.error = "Failed to decode image information"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func processImageURLs(_ imageInfos: [PositionedImageInfo]) {
        // Filter out small images but maintain the order from top to bottom
        let filteredImages = imageInfos
            .filter { $0.width > 200 && $0.height > 200 } // Filter small images
        
        if filteredImages.isEmpty {
            Task { @MainActor in
                self.error = "No suitable images found on the page"
                self.isLoading = false
            }
            return
        }
        
        // Download images in the order they were found (top to bottom)
        downloadImages(from: filteredImages)
    }
    
    private func downloadImages(from imageInfos: [PositionedImageInfo]) {
        Task {
            var downloadedImages: [UIImage] = []
            
            // Download images sequentially to maintain order
            for imageInfo in imageInfos {
                // Check cache first
                if let cachedImage =  getCachedImage(for: imageInfo.src) {
                    downloadedImages.append(cachedImage)
                    continue
                }
                
                // Download image
                guard let url = URL(string: imageInfo.src) else {
                    continue
                }
                
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        cacheImage(image, for: imageInfo.src)
                        downloadedImages.append(image)
                    }
                } catch {
                    print("Failed to download image: \(error)")
                }
            }
            
            // Update UI on main actor
            await MainActor.run {
                if downloadedImages.isEmpty {
                    self.error = "Failed to download any images"
                } else {
                    self.images = downloadedImages
                }
                self.isLoading = false
            }
        }
    }
    
    // Thread-safe cache access
    private func getCachedImage(for key: String) -> UIImage? {
        return imageCache[key]
    }
    
    private func cacheImage(_ image: UIImage, for key: String) {
        imageCache[key] = image
    }
}

extension ReaderViewJava: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait a bit for images to load, then extract them
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.extractImagesFromPage()
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

// Helper struct for image information with position data
struct PositionedImageInfo: Codable {
    let src: String
    let width: Int
    let height: Int
    let position: Double // Vertical position in the document
}
