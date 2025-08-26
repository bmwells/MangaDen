//
//  BrowserView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/26/25.
//

import SwiftUI
import WebKit

struct BrowserView: View {
    @State private var urlString: String = "https://www.google.com"
    @State private var canGoBack = false
    @State private var canGoForward = false
    @FocusState private var isURLFieldFocused: Bool

    private let webView = WKWebView()
    private let coordinator: WebViewCoordinator

    init() {
        let coord = WebViewCoordinator()
        self.coordinator = coord
        webView.navigationDelegate = coord
        coord.attachObservers(to: webView) // observe nav state
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
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }

                // Forward Button
                Button(action: { webView.goForward() }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20))
                        .foregroundColor(canGoForward ? .blue : .gray)
                }
                .disabled(!canGoForward)

                // URL Bar
                TextField("Enter URL", text: $urlString, onCommit: {
                    loadURL()
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($isURLFieldFocused)

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
            
            // Add Title
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 40)
                .overlay(
                    Text("Add Title")
                        .foregroundColor(.red)
                        .font(.system(size: 16, weight: .semibold))
                )

            Divider()

            // MARK: WebView
            WebViewWrapper(webView: webView)
                .edgesIgnoringSafeArea(.bottom)
        }
        .onAppear { loadURL() }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateWebViewNav)) { notification in
            if let info = notification.userInfo as? [String: Any] {
                canGoBack = info["canGoBack"] as? Bool ?? false
                canGoForward = info["canGoForward"] as? Bool ?? false
                // don’t overwrite urlString every time — let google.com forms work
            }
        }
    }

    private func loadURL() {
        var formatted = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.hasPrefix("http://") && !formatted.hasPrefix("https://") {
            formatted = "https://" + formatted
        }
        urlString = formatted
        if let url = URL(string: formatted) {
            webView.load(URLRequest(url: url))
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
        // nothing — don’t reload every SwiftUI update
    }
}

// MARK: Coordinator
class WebViewCoordinator: NSObject, WKNavigationDelegate {
    private var backObserver: NSKeyValueObservation?
    private var forwardObserver: NSKeyValueObservation?

    func attachObservers(to webView: WKWebView) {
        backObserver = webView.observe(\.canGoBack, options: [.new]) { webView, _ in
            NotificationCenter.default.post(
                name: .didUpdateWebViewNav,
                object: nil,
                userInfo: [
                    "canGoBack": webView.canGoBack,
                    "canGoForward": webView.canGoForward,
                    "currentURL": webView.url as Any
                ]
            )
        }
        forwardObserver = webView.observe(\.canGoForward, options: [.new]) { webView, _ in
            NotificationCenter.default.post(
                name: .didUpdateWebViewNav,
                object: nil,
                userInfo: [
                    "canGoBack": webView.canGoBack,
                    "canGoForward": webView.canGoForward,
                    "currentURL": webView.url as Any
                ]
            )
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NotificationCenter.default.post(
            name: .didUpdateWebViewNav,
            object: nil,
            userInfo: [
                "canGoBack": webView.canGoBack,
                "canGoForward": webView.canGoForward,
                "currentURL": webView.url as Any
            ]
        )
    }
}

extension Notification.Name {
    static let didUpdateWebViewNav = Notification.Name("didUpdateWebViewNav")
}
