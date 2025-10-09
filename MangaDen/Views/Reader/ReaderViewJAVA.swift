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
    
    // Add cancellation support
    private var currentExtractionTask: Task<Void, Never>?
    private var isStopping = false // Add this flag
    
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
        isStopping = false // Reset stopping flag
        
        // Reset cancellation state before starting new load
        extractionCoordinator.resetCancellation()
        
        webViewManager.loadChapter(url: url)
        
        // Set up observation for extraction coordinator images
        Task {
            for await newImages in extractionCoordinator.$images.values {
                // Check if we're in the process of stopping
                if !self.isStopping {
                    print("ReaderViewJava: Received \(newImages.count) images from extraction coordinator")
                    self.images = newImages
                    
                    // If we have images and are still loading, update the state
                    if !newImages.isEmpty && self.isLoading {
                        print("ReaderViewJava: Images received, updating loading state to false")
                        self.isLoading = false
                        self.downloadProgress = ""
                    }
                } else {
                    print("ReaderViewJava: Ignoring images received during stop process")
                }
            }
        }
        
        // Set up observation for web view loading state
        Task {
            for await loadingState in webViewManager.$isLoading.values {
                print("ReaderViewJava: WebView loading state: \(loadingState)")
                // Only update if we don't have images yet and not stopping
                if self.images.isEmpty && !self.isStopping {
                    self.isLoading = loadingState
                }
            }
        }
        
        // Set up observation for errors
        Task {
            for await newError in webViewManager.$error.values {
                print("ReaderViewJava: WebView error: \(newError ?? "nil")")
                if !self.isStopping {
                    self.error = newError
                    if newError != nil {
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    func stopLoading() {
        print("ReaderViewJava: Stopping all loading and extraction")
        isStopping = true // Set stopping flag first
        
        // Cancel any ongoing extraction task FIRST
        currentExtractionTask?.cancel()
        currentExtractionTask = nil
        
        // Cancel the extraction coordinator operations
        extractionCoordinator.cancelAllOperations()
        
        // Stop the WebView
        webViewManager.stopLoading()
        
        // Reset state
        isLoading = false
        error = "Download cancelled by user"
        downloadProgress = ""
        
        // Clear images to ensure UI updates
        images = []
        
        print("ReaderViewJava: All operations stopped")
    }
    
    func clearCache() {
        isStopping = true
        webViewManager.clearCache()
        extractionCoordinator.clearCache()
        extractionCoordinator.resetCancellation()
        images = []
        currentExtractionTask = nil
        isStopping = false
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
        // Check if we're in the process of stopping before starting extraction
        if isStopping {
            print("ReaderViewJava: Ignoring page load completion - stopping in progress")
            return
        }
        
        print("ReaderViewJava: Page loaded successfully, starting multi-strategy image extraction...")
        
        // Make sure we have a valid web view
        guard let webView = webViewManager.webView else {
            print("ReaderViewJava: ERROR: WebView is nil in didFinish navigation")
            self.error = "WebView failed to load properly"
            self.isLoading = false
            return
        }
        
        // Check if operation was cancelled before starting extraction
        if extractionCoordinator.isCancelled || isStopping {
            print("ReaderViewJava: Extraction cancelled before starting")
            self.isLoading = false
            self.error = "Download was cancelled"
            return
        }
        
        print("ReaderViewJava: Starting extraction strategies on web view")
        
        // Store the extraction task for potential cancellation
        currentExtractionTask = Task { [weak self] in
            // Add a small delay to ensure the page is fully rendered
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Check for cancellation after delay
            if Task.isCancelled || self?.extractionCoordinator.isCancelled == true || self?.isStopping == true {
                print("ReaderViewJava: Extraction cancelled during delay")
                await MainActor.run {
                    self?.isLoading = false
                    self?.error = "Download was cancelled"
                }
                return
            }
            
            self?.extractionCoordinator.attemptImageExtraction(attempt: 1, maxAttempts: 3, webView: webView) { [weak self] success in
                print("ReaderViewJava: Extraction completed with success: \(success)")
                
                Task { @MainActor in
                    // Only update state if not cancelled or stopping
                    if self?.extractionCoordinator.isCancelled != true && self?.isStopping != true {
                        if success {
                            print("ReaderViewJava: Extraction successful, updating loading state")
                            self?.isLoading = false
                            self?.downloadProgress = ""
                        } else {
                            self?.error = "Failed to extract images after multiple attempts"
                            self?.isLoading = false
                        }
                    } else {
                        print("ReaderViewJava: Extraction was cancelled or stopping, ignoring results")
                        self?.isLoading = false
                    }
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("ReaderViewJava: WebView navigation failed: \(error.localizedDescription)")
        Task { @MainActor in
            // Only set error if not cancelled or stopping
            if !self.extractionCoordinator.isCancelled && !self.isStopping {
                self.error = "Failed to load page: \(error.localizedDescription)"
            }
            self.isLoading = false
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("ReaderViewJava: WebView provisional navigation failed: \(error.localizedDescription)")
        Task { @MainActor in
            // Only set error if not cancelled or stopping
            if !self.extractionCoordinator.isCancelled && !self.isStopping {
                self.error = "Failed to load page: \(error.localizedDescription)"
            }
            self.isLoading = false
        }
    }
}
