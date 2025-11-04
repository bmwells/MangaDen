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
    
    // Cancellation support
    private var currentExtractionTask: Task<Void, Never>?
    private var isStopping = false
    private var isPaused = false
    private var hasExtractionStarted = false
    private var extractionFallbackTask: Task<Void, Never>?
    
    override init() {
        super.init()
        // Set self as navigation delegate for webViewManager
        webViewManager.navigationDelegate = self
        
        // Set up progress observation from extraction coordinator
        setupProgressObservation()
        
        // Listen for pause/resume notifications
        setupPauseResumeObservers()
    }
    
    private func setupProgressObservation() {
        Task {
            for await progress in extractionCoordinator.$extractionProgress.values {
                if !self.isStopping && !self.isPaused {
                    await MainActor.run {
                        self.downloadProgress = progress
                        print("ReaderViewJava: Progress update - \(progress)")
                    }
                }
            }
        }
    }
    
    private func setupPauseResumeObservers() {
        NotificationCenter.default.addObserver(
            forName: .downloadsPaused,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("ReaderViewJava: Received pause notification - stopping extraction")
            Task { @MainActor in
                self?.pauseExtraction()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .downloadsResumed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("ReaderViewJava: Received resume notification")
            Task { @MainActor in
                self?.isPaused = false
            }
        }
    }
    
    private func pauseExtraction() {
        print("ReaderViewJava: Pausing all extraction operations")
        isPaused = true
        isStopping = true
        
        // Cancel any ongoing extraction task
        currentExtractionTask?.cancel()
        currentExtractionTask = nil
        
        // Cancel fallback timer
        extractionFallbackTask?.cancel()
        extractionFallbackTask = nil
        
        // Cancel the extraction coordinator operations
        extractionCoordinator.cancelAllOperations()
        
        // Stop the WebView
        webViewManager.stopLoading()
        
        // Reset state
        isLoading = false
        error = "Download paused by user"
        downloadProgress = ""
        
        // Clear images to ensure UI updates
        images = []
        
        print("ReaderViewJava: All extraction operations paused")
    }
    
    func loadChapter(url: URL) {
        // Reset pause state when starting new load
        isPaused = false
        isStopping = false
        hasExtractionStarted = false // RESET EXTRACTION FLAG
        
        print("ReaderViewJava: Loading chapter from URL: \(url)")
        isLoading = true
        error = nil
        images = []
        downloadProgress = "Starting chapter load..." // Initial progress
        
        // Reset cancellation state before starting new load
        extractionCoordinator.resetCancellation()
        
        webViewManager.loadChapter(url: url)
        
        // Set up a fallback timer in case extraction doesn't start
        setupExtractionFallbackTimer()
        
        // Set up observation for extraction coordinator images
        Task {
            for await newImages in extractionCoordinator.$images.values {
                // Check if we're paused or in the process of stopping
                if !self.isStopping && !self.isPaused {
                    print("ReaderViewJava: Received \(newImages.count) images from extraction coordinator")
                    self.images = newImages
                    
                    // If we have images and are still loading, update the state
                    if !newImages.isEmpty && self.isLoading {
                        print("ReaderViewJava: Images received, updating loading state to false")
                        self.isLoading = false
                        self.downloadProgress = "Chapter ready!"
                    }
                } else {
                    print("ReaderViewJava: Ignoring images received during pause/stop process")
                }
            }
        }
        
        // Set up observation for web view loading state
        Task {
            for await loadingState in webViewManager.$isLoading.values {
                print("ReaderViewJava: WebView loading state: \(loadingState)")
                // Only update if we don't have images yet and not stopping/paused
                if self.images.isEmpty && !self.isStopping && !self.isPaused {
                    self.isLoading = loadingState
                    if loadingState {
                        self.downloadProgress = "Loading webpage..."
                    } else {
                        // WebView finished loading but extraction hasn't started
                        if !self.hasExtractionStarted && self.images.isEmpty && !self.isStopping {
                            self.downloadProgress = "Webpage loaded, preparing extraction..."
                            // Force extraction start if it hasn't happened
                            self.forceStartExtractionIfNeeded()
                        }
                    }
                }
            }
        }
        
        // Set up observation for errors
        Task {
            for await newError in webViewManager.$error.values {
                print("ReaderViewJava: WebView error: \(newError ?? "nil")")
                if !self.isStopping && !self.isPaused {
                    self.error = newError
                    if newError != nil {
                        self.isLoading = false
                        self.downloadProgress = "Error loading chapter"
                    }
                }
            }
        }
    }

    // ADD THESE NEW METHODS:

    private func setupExtractionFallbackTimer() {
        // Cancel any existing fallback task first
        extractionFallbackTask?.cancel()
        
        // Start a timer that will trigger extraction if it doesn't start within 5 seconds
        extractionFallbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            
            // Check if extraction still hasn't started and we're not stopped/paused
            if let self = self, !self.hasExtractionStarted && !self.isStopping && !self.isPaused && self.images.isEmpty {
                print("ReaderViewJava: Fallback timer triggered - forcing extraction start")
                await MainActor.run {
                    self.downloadProgress = "Starting image extraction..."
                }
                self.forceStartExtractionIfNeeded()
            }
        }
    }

    private func forceStartExtractionIfNeeded() {
        guard let webView = webViewManager.webView else {
            print("ReaderViewJava: Cannot force extraction - WebView is nil")
            return
        }
        
        // Check if we're already in the process of extraction or stopping
        if hasExtractionStarted || isStopping || isPaused {
            return
        }
        
        print("ReaderViewJava: Forcing extraction start")
        startExtractionProcess(webView: webView)
    }
    
    func stopLoading() {
        print("ReaderViewJava: Stopping all loading and extraction")
        isStopping = true // Set stopping flag first
        isPaused = false // Reset pause state when explicitly stopping
        hasExtractionStarted = false // RESET EXTRACTION FLAG
        
        // Cancel fallback timer FIRST
        extractionFallbackTask?.cancel()
        extractionFallbackTask = nil
        
        // Cancel any ongoing extraction task
        currentExtractionTask?.cancel()
        currentExtractionTask = nil
        
        // Cancel the extraction coordinator operations
        extractionCoordinator.cancelAllOperations()
        
        // Stop the WebView and clear its content
        webViewManager.stopLoading()
        webViewManager.clearContent()
        
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
        isPaused = false
        hasExtractionStarted = false
        
        // Cancel fallback timer
        extractionFallbackTask?.cancel()
        extractionFallbackTask = nil
        
        // Stop WebView and clear its content ONLY (temporary web data)
        webViewManager.stopLoading()
        webViewManager.clearContent()
        webViewManager.clearCache()
        
        // Clear extraction coordinator cache (temporary extraction images)
        extractionCoordinator.clearCache()
        extractionCoordinator.cancelAllOperations()
        extractionCoordinator.resetCancellation()
        
        // Clear local temporary state but DON'T clear downloaded chapter data
        images = [] // Clear only the in-memory images from online reading
        currentExtractionTask = nil
        isStopping = false
        
        print("ReaderViewJava: Temporary online reading cache cleared - downloaded chapters preserved")
    }
}

extension ReaderViewJava: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Check if we're paused or in the process of stopping before starting extraction
        if isStopping || isPaused {
            print("ReaderViewJava: Ignoring page load completion - paused or stopping in progress")
            return
        }
        
        print("ReaderViewJava: Page loaded successfully, waiting for content to render before extraction...")
        
        // Make sure we have a valid web view
        guard let webView = webViewManager.webView else {
            print("ReaderViewJava: ERROR: WebView is nil in didFinish navigation")
            self.error = "WebView failed to load properly"
            self.isLoading = false
            return
        }
        
        // Check if operation was cancelled or paused before starting extraction
        if extractionCoordinator.isCancelled || isStopping || isPaused {
            print("ReaderViewJava: Extraction cancelled/paused before starting")
            self.isLoading = false
            self.error = "Download was cancelled or paused"
            return
        }
        
        // Wait a bit longer before starting extraction to ensure DOM is fully populated
        // This gives time for JavaScript to execute and lazy-loaded images to appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            // Double-check cancellation state after delay
            if self.extractionCoordinator.isCancelled || self.isStopping || self.isPaused {
                print("ReaderViewJava: Extraction cancelled/paused after initial delay")
                return
            }
            
            print("ReaderViewJava: Starting multi-strategy image extraction after render delay...")
            self.startExtractionProcess(webView: webView)
        }
    }
    
    private func startExtractionProcess(webView: WKWebView) {
        // Mark extraction as started
        hasExtractionStarted = true
        
        // Cancel fallback timer since extraction is starting
        extractionFallbackTask?.cancel()
        extractionFallbackTask = nil
        
        // Store the extraction task for potential cancellation
        currentExtractionTask = Task { [weak self] in
            // Add a small delay to ensure the page is fully rendered
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 second
            
            // Check for cancellation/pause after delay
            if Task.isCancelled || self?.extractionCoordinator.isCancelled == true || self?.isStopping == true || self?.isPaused == true {
                print("ReaderViewJava: Extraction cancelled/paused during delay")
                await MainActor.run {
                    self?.isLoading = false
                    self?.error = "Download was cancelled or paused"
                }
                return
            }
            
            self?.extractionCoordinator.attemptImageExtraction(attempt: 1, maxAttempts: 3, webView: webView) { [weak self] success in
                print("ReaderViewJava: Extraction completed with success: \(success)")
                
                Task { @MainActor in
                    // Only update state if not cancelled, stopping, or paused
                    if self?.extractionCoordinator.isCancelled != true && self?.isStopping != true && self?.isPaused != true {
                        if success {
                            print("ReaderViewJava: Extraction successful, updating loading state")
                            self?.isLoading = false
                            self?.downloadProgress = ""
                        } else {
                            self?.error = "Failed to extract images after multiple attempts"
                            self?.isLoading = false
                        }
                    } else {
                        print("ReaderViewJava: Extraction was cancelled, paused, or stopping, ignoring results")
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
