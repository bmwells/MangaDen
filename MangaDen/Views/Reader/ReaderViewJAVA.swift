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
    
    private let webViewManager = WebViewManager()
    private let extractionCoordinator = ImageExtractionCoordinator()
    
    override init() {
        super.init()
        print("ReaderViewJava: Initializing with navigation delegate")
        // Set self as navigation delegate for webViewManager
        webViewManager.navigationDelegate = self
    }
    
    func loadChapter(url: URL) {
        print("ReaderViewJava: Loading chapter from URL: \(url)")
        isLoading = true
        error = nil
        images = []
        downloadProgress = "" // Reset progress
        
        webViewManager.loadChapter(url: url)
        
        // Set up observation for extraction coordinator images
        Task {
            for await newImages in extractionCoordinator.$images.values {
                print("ReaderViewJava: Received \(newImages.count) images from extraction coordinator")
                self.images = newImages
                
                // If we have images and are still loading, update the state
                if !newImages.isEmpty && self.isLoading {
                    print("ReaderViewJava: Images received, updating loading state to false")
                    self.isLoading = false
                    self.downloadProgress = ""
                }
            }
        }
        
        // Set up observation for web view loading state
        Task {
            for await loadingState in webViewManager.$isLoading.values {
                print("ReaderViewJava: WebView loading state: \(loadingState)")
                // Only update if we don't have images yet
                if self.images.isEmpty {
                    self.isLoading = loadingState
                }
            }
        }
        
        // Set up observation for errors
        Task {
            for await newError in webViewManager.$error.values {
                print("ReaderViewJava: WebView error: \(newError ?? "nil")")
                self.error = newError
                if newError != nil {
                    self.isLoading = false
                }
            }
        }
    }
    
    func clearCache() {
        webViewManager.clearCache()
        extractionCoordinator.images = []
        images = []
    }
}

// MARK: - WKNavigationDelegate Extension

extension ReaderViewJava: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("ReaderViewJava: WebView started loading...")
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("ReaderViewJava: WebView committed navigation")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("ReaderViewJava: Page loaded successfully, starting multi-strategy image extraction...")
        
        // Make sure we have a valid web view
        guard let webView = webViewManager.webView else {
            print("ReaderViewJava: ERROR: WebView is nil in didFinish navigation")
            self.error = "WebView failed to load properly"
            self.isLoading = false
            return
        }
        
        print("ReaderViewJava: Starting extraction strategies on web view")
        
        // Add a small delay to ensure the page is fully rendered
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.extractionCoordinator.attemptImageExtraction(attempt: 1, maxAttempts: 3, webView: webView) { [weak self] success in
                print("ReaderViewJava: Extraction completed with success: \(success)")
                
                Task { @MainActor in
                    if success {
                        print("ReaderViewJava: Extraction successful, updating loading state")
                        self?.isLoading = false
                        self?.downloadProgress = ""
                    } else {
                        self?.error = "Failed to extract images after multiple attempts"
                        self?.isLoading = false
                    }
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("ReaderViewJava: WebView navigation failed: \(error.localizedDescription)")
        Task { @MainActor in
            self.error = "Failed to load page: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("ReaderViewJava: WebView provisional navigation failed: \(error.localizedDescription)")
        Task { @MainActor in
            self.error = "Failed to load page: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
}
