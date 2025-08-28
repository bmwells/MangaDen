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
    @State private var containsChapter = false // New boolean for chapter detection
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

            // Chapter indicator
            HStack {
                Text("chapter")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(containsChapter ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .foregroundColor(containsChapter ? .green : .red)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(containsChapter ? Color.green : Color.red, lineWidth: 1)
                    )
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

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
        .onReceive(NotificationCenter.default.publisher(for: .didFindChapterWord)) { notification in
            if let containsChapter = notification.userInfo?["containsChapter"] as? Bool {
                self.containsChapter = containsChapter
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
        containsChapter = false // Reset chapter detection when loading new URL
        
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

// MARK: Coordinator with Chapter Detection
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
        // Check for chapter word when page finishes loading
        checkForChapterWord(in: webView)
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
    
    // Function to check for chapter word
    private func checkForChapterWord(in webView: WKWebView) {
        let javascript = """
        // Check if document body exists and has content
        if (document.body && document.body.innerText) {
            document.body.innerText.toLowerCase().includes('chapter');
        } else {
            false;
        }
        """
        
        webView.evaluateJavaScript(javascript) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error checking for chapter: \(error.localizedDescription)")
                    // Send notification that no chapter was found
                    NotificationCenter.default.post(
                        name: .didFindChapterWord,
                        object: nil,
                        userInfo: ["containsChapter": false]
                    )
                    return
                }
                
                if let containsChapter = result as? Bool {
                    // Send notification with the result
                    NotificationCenter.default.post(
                        name: .didFindChapterWord,
                        object: nil,
                        userInfo: ["containsChapter": containsChapter]
                    )
                } else {
                    // Send notification that no chapter was found
                    NotificationCenter.default.post(
                        name: .didFindChapterWord,
                        object: nil,
                        userInfo: ["containsChapter": false]
                    )
                }
            }
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
    static let didFindChapterWord = Notification.Name("didFindChapterWord")
}
