//
//  WebViewUserAgentManager.swift
//  MangaDen
//
//  Created by Brody Wells on 8/26/25.
//

import WebKit

class WebViewUserAgentManager {
    
    // MARK: - User Agent Configuration
    
    // Function to set desktop user agent for scraping
    static func setDesktopUserAgent(for webView: WKWebView) {
        let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        webView.customUserAgent = desktopUserAgent
    }
    
    // Function to set mobile user agent for display
    static func setMobileUserAgent(for webView: WKWebView) {
        let mobileUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
        webView.customUserAgent = mobileUserAgent
    }
    
    // Function to force desktop view using JavaScript
    static func forceDesktopView(in webView: WKWebView, completion: @escaping (Bool) -> Void) {
        let javascript = """
        (function() {
            // 1. Remove mobile-specific classes and attributes
            document.querySelector('html').classList.remove('mobile', 'ios', 'android');
            document.querySelector('body').classList.remove('mobile', 'ios', 'android');
            
            // 2. Remove viewport meta tag that forces mobile layout
            const viewportMeta = document.querySelector('meta[name="viewport"][content*="width=device-width"]');
            if (viewportMeta) {
                viewportMeta.remove();
            }
            
            // 3. Set desktop viewport
            const newViewport = document.createElement('meta');
            newViewport.name = 'viewport';
            newViewport.content = 'width=1200';
            document.head.appendChild(newViewport);
            
            // 4. Remove mobile navigation/headers if they exist
            const mobileElements = document.querySelectorAll([
                '.mobile-nav',
                '.mobile-menu',
                '[class*="mobile"]',
                '[id*="mobile"]',
                '.navbar-toggle',
                '.hamburger-menu'
            ].join(','));
            
            mobileElements.forEach(el => el.style.display = 'none');
            
            // 5. Show desktop elements that might be hidden
            const desktopElements = document.querySelectorAll([
                '.desktop-nav',
                '.desktop-menu',
                '[class*="desktop"]',
                '[id*="desktop"]',
                '.full-menu'
            ].join(','));
            
            desktopElements.forEach(el => el.style.display = 'block');
            
            // 6. Force full content expansion (common on mobile sites)
            const expandButtons = document.querySelectorAll([
                '.read-more',
                '.show-more',
                '.expand-content',
                '[onclick*="expand"]',
                '[onclick*="show"]'
            ].join(','));
            
            expandButtons.forEach(btn => {
                if (typeof btn.click === 'function') {
                    btn.click();
                }
            });
            
            return true;
        })();
        """
        
        webView.evaluateJavaScript(javascript) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error forcing desktop view: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                completion(true)
            }
        }
    }
}
