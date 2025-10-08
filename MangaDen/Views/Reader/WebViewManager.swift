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
        
        print("WebViewManager: Loading URL: \(url)")
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func clearCache() {
        webView?.stopLoading()
        webView = nil
        currentURL = nil
        
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date.distantPast,
            completionHandler: {}
        )
    }
}
