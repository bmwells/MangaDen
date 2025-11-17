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
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        
        // FORCE iPHONE USER AGENT ON iPAD
        if UIDevice.current.userInterfaceIdiom == .pad {
            let iPhoneUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
            webView.customUserAgent = iPhoneUserAgent
        }
        
        webView.navigationDelegate = self.navigationDelegate
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
    }
    
    func clearCache() {
        webView?.stopLoading()
        webView = nil
        currentURL = nil
        isLoading = false
        
        // Clear website data store
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date.distantPast,
            completionHandler: {}
        )
    }
}
