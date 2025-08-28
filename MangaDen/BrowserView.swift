//
//  BrowserView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/26/25.
//

import SwiftUI
import WebKit

struct BrowserView: View {
    @State private var urlString: String = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var lastLoadTime = Date.distantPast
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isURLFieldFocused: Bool

    private let webView = WKWebView()
    private let coordinator: WebViewCoordinator

    init() {
        let coord = WebViewCoordinator()
        self.coordinator = coord
        webView.navigationDelegate = coord
        coord.attachObservers(to: webView)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Navigation Bar
            HStack {
                // Back Button
                Button(action: { webView.goBack() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20))
                        .foregroundColor(canGoBack ? .blue : .gray)
                }
                .disabled(!canGoBack)

                // Refresh Button
                Button(action: { webView.reload() }) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }

                // Forward Button
                Button(action: { webView.goForward() }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20))
                        .foregroundColor(canGoForward ? .blue : .gray)
                }
                .disabled(!canGoForward)

                // URL Bar
                TextField("Enter URL or search terms", text: $urlString, onCommit: {
                    loadURL()
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($isURLFieldFocused)
                .submitLabel(.go)

                // Go Button
                Button(action: {
                    loadURL()
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))

            // Error message
            if showError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
            }

            Divider()

            // MARK: WebView
            WebViewWrapper(webView: webView)
                .edgesIgnoringSafeArea(.bottom)
        }
        .onAppear {
            // Load a default page if no URL is specified
            if urlString.isEmpty {
                urlString = "https://www.google.com"
                loadURL()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateWebViewNav)) { notification in
            if let info = notification.userInfo as? [String: Any] {
                canGoBack = info["canGoBack"] as? Bool ?? false
                canGoForward = info["canGoForward"] as? Bool ?? false
                
                if let currentURL = info["currentURL"] as? URL, !isURLFieldFocused {
                    urlString = currentURL.absoluteString
                }
                
                isLoading = info["isLoading"] as? Bool ?? false
                
                // Only show errors that aren't the cancelled error (-999)
                if let error = info["error"] as? String {
                    // Check if it's the cancelled error (we don't want to show this to users)
                    if !error.contains("cancelled") && !error.contains("-999") {
                        errorMessage = error
                        showError = true
                    } else {
                        showError = false
                    }
                } else {
                    showError = false
                }
            }
        }
    }

    private func loadURL() {
        // Prevent rapid successive loads (debounce)
            let now = Date()
            if now.timeIntervalSince(lastLoadTime) < 0.5 { // 500ms debounce
                return
            }
            lastLoadTime = now
            
            showError = false
            let input = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Handle empty input
            if input.isEmpty {
                errorMessage = "Please enter a URL or search terms"
                showError = true
                return
            }
        
        // Check if it's a valid URL
        if let url = URL(string: input), UIApplication.shared.canOpenURL(url) {
            // It's a valid URL with scheme
            webView.load(URLRequest(url: url))
        } else if let url = URL(string: "https://" + input), UIApplication.shared.canOpenURL(url) {
            // Try adding https:// prefix
            urlString = "https://" + input
            webView.load(URLRequest(url: url))
        } else {
            // Treat as search query - use Google search
            let searchQuery = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
            if let searchURL = URL(string: "https://www.google.com/search?q=\(searchQuery)") {
                urlString = searchURL.absoluteString
                webView.load(URLRequest(url: searchURL))
            } else {
                errorMessage = "Invalid URL or search terms"
                showError = true
            }
        }
        
        isURLFieldFocused = false
    }
}

// MARK: WebView Wrapper
struct WebViewWrapper: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No need to reload on update
    }
}

// MARK: Coordinator
class WebViewCoordinator: NSObject, WKNavigationDelegate {
    private var backObserver: NSKeyValueObservation?
    private var forwardObserver: NSKeyValueObservation?
    private var loadingObserver: NSKeyValueObservation?

    func attachObservers(to webView: WKWebView) {
        // Observe navigation state
        backObserver = webView.observe(\.canGoBack, options: [.new]) { webView, _ in
            self.postNavigationUpdate(webView: webView)
        }
        
        forwardObserver = webView.observe(\.canGoForward, options: [.new]) { webView, _ in
            self.postNavigationUpdate(webView: webView)
        }
        
        loadingObserver = webView.observe(\.isLoading, options: [.new]) { webView, _ in
            self.postNavigationUpdate(webView: webView)
        }
    }

    private func postNavigationUpdate(webView: WKWebView, error: String? = nil) {
        var userInfo: [String: Any] = [
            "canGoBack": webView.canGoBack,
            "canGoForward": webView.canGoForward,
            "currentURL": webView.url as Any,
            "isLoading": webView.isLoading
        ]
        
        if let error = error {
            userInfo["error"] = error
        }
        
        NotificationCenter.default.post(
            name: .didUpdateWebViewNav,
            object: nil,
            userInfo: userInfo
        )
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        postNavigationUpdate(webView: webView)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        postNavigationUpdate(webView: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Handle error -999 (cancelled navigation) gracefully
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == -999 {
            // This is a cancelled request, not a real error - just update navigation state
            postNavigationUpdate(webView: webView)
        } else {
            // This is a real error that should be shown to the user
            postNavigationUpdate(webView: webView, error: error.localizedDescription)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Handle error -999 (cancelled navigation) gracefully
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == -999 {
            // This is a cancelled request, not a real error
            postNavigationUpdate(webView: webView)
        } else {
            // This is a real error that should be shown to the user
            postNavigationUpdate(webView: webView, error: error.localizedDescription)
        }
    }
    
    // Optional: Handle navigation decisions to prevent some cancellations
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Allow all navigation by default
        decisionHandler(.allow)
    }
}

extension Notification.Name {
    static let didUpdateWebViewNav = Notification.Name("didUpdateWebViewNav")
}
