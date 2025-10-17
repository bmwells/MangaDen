//
//  WebViewManager.swift
//  MangaDen
//
//  Created by Brody Wells on 10/7/25.
//

import SwiftUI
import WebKit

@MainActor
class WebViewManager: NSObject, ObservableObject {
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var downloadProgress: String = ""
    
    var webView: WKWebView?
    var currentURL: URL?
    
    // MARK: - Navigation Delegate
    weak var navigationDelegate: WKNavigationDelegate? {
        didSet {
            webView?.navigationDelegate = navigationDelegate
        }
    }
    
    func loadChapter(url: URL) {
        isLoading = true
        error = nil
        currentURL = url
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = .nonPersistent()
        
        // Create web view and set delegate BEFORE loading
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self.navigationDelegate // Set delegate first
        self.webView = webView
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func stopLoading() {
        webView?.stopLoading()
        isLoading = false
        error = "Download cancelled by user"
    }
    
    func clearContent() {
        print("WebViewManager: Clearing WebView content")
        
        // Stop any ongoing loading
        webView?.stopLoading()
        
        // Clear the WebView content by loading a blank page
        webView?.load(URLRequest(url: URL(string: "about:blank")!))
        
        // Clear navigation delegate to prevent callbacks
        webView?.navigationDelegate = nil
        
        // Clear current URL
        currentURL = nil
        
        // Update state
        isLoading = false
        error = nil
        downloadProgress = ""
        
        print("WebViewManager: WebView content cleared")
    }
    
    func clearCache() {
        webView?.stopLoading()
        webView = nil
        currentURL = nil
        isLoading = false
        
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date.distantPast,
            completionHandler: {}
        )
    }
}
