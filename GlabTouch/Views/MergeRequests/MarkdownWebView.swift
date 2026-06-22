import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WebKit)
import WebKit
#endif

enum MarkdownHTMLDocument {
    static func render(html: String, baseURL: URL?, authToken: String, stylesheet: String) -> String {
        let authenticatedHTML = authenticateImageSources(in: html, baseURL: baseURL, authToken: authToken)

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>\(stylesheet)</style>
        </head>
        <body>
        \(authenticatedHTML)
        </body>
        </html>
        """
    }

    private static func authenticateImageSources(in html: String, baseURL: URL?, authToken: String) -> String {
        guard !authToken.isEmpty,
              let regex = try? NSRegularExpression(pattern: #"(?i)<img\b[^>]*\bsrc\s*=\s*(['"])([^'"]*)\1"#)
        else { return html }

        var result = html
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        for match in matches.reversed() {
            guard match.numberOfRanges >= 3,
                  let sourceRange = Range(match.range(at: 2), in: result)
            else { continue }

            let source = String(result[sourceRange])
            guard let replacement = authenticatedImageSource(source, baseURL: baseURL, authToken: authToken) else { continue }
            result.replaceSubrange(sourceRange, with: htmlAttributeEscaped(replacement))
        }

        return result
    }

    private static func authenticatedImageSource(_ source: String, baseURL: URL?, authToken: String) -> String? {
        let unescapedSource = htmlUnescaped(source).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let imageURL = resolvedURL(for: unescapedSource, baseURL: baseURL),
              pointsToInstance(imageURL, baseURL: baseURL),
              let authenticatedURL = urlByAddingPrivateToken(to: imageURL, authToken: authToken)
        else { return nil }

        return authenticatedURL.absoluteString
    }

    private static func resolvedURL(for source: String, baseURL: URL?) -> URL? {
        if source.hasPrefix("//"),
           let scheme = baseURL?.scheme,
           let url = URL(string: "\(scheme):\(source)")
        {
            return url
        }

        if let url = URL(string: source), url.scheme != nil {
            return url
        }

        guard let baseURL else { return nil }
        return URL(string: source, relativeTo: baseURL)?.absoluteURL
    }

    private static func pointsToInstance(_ url: URL, baseURL: URL?) -> Bool {
        guard let baseURL,
              url.scheme?.lowercased() == baseURL.scheme?.lowercased(),
              url.host?.lowercased() == baseURL.host?.lowercased()
        else { return false }

        return normalizedPort(for: url) == normalizedPort(for: baseURL)
    }

    private static func normalizedPort(for url: URL) -> Int? {
        if let port = url.port {
            return port
        }

        switch url.scheme?.lowercased() {
        case "http":
            return 80
        case "https":
            return 443
        default:
            return nil
        }
    }

    private static func urlByAddingPrivateToken(to url: URL, authToken: String) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var queryItems = components.queryItems ?? []

        if queryItems.contains(where: { $0.name == "private_token" }) {
            return url
        }

        queryItems.append(URLQueryItem(name: "private_token", value: authToken))
        components.queryItems = queryItems
        return components.url
    }

    private static func htmlUnescaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private static func htmlAttributeEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

#if canImport(UIKit) && canImport(WebKit) && canImport(SwiftUI)
struct MarkdownWebView: UIViewRepresentable {
    let html: String
    let baseURL: URL?
    let authToken: String
    @Binding var contentHeight: CGFloat

    init(html: String, baseURL: URL?, authToken: String, contentHeight: Binding<CGFloat>) {
        self.html = html
        self.baseURL = baseURL
        self.authToken = authToken
        self._contentHeight = contentHeight
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.contentHeight = $contentHeight

        let document = MarkdownHTMLDocument.render(
            html: html,
            baseURL: baseURL,
            authToken: authToken,
            stylesheet: Self.markdownStylesheet()
        )

        guard context.coordinator.loadedDocument != document else { return }

        context.coordinator.loadedDocument = document
        webView.loadHTMLString(document, baseURL: baseURL)
    }

    private static func markdownStylesheet() -> String {
        guard let url = Bundle.main.url(forResource: "markdown-style", withExtension: "css"),
              let stylesheet = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }

        return stylesheet
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var contentHeight: Binding<CGFloat>
        var loadedDocument: String?

        init(contentHeight: Binding<CGFloat>) {
            self.contentHeight = contentHeight
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateContentHeight(for: webView)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak webView] in
                guard let webView else { return }
                self?.updateContentHeight(for: webView)
            }
        }

        @MainActor
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url
            else {
                decisionHandler(.allow)
                return
            }

            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }

        private func updateContentHeight(for webView: WKWebView) {
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] value, _ in
                let height: CGFloat

                if let number = value as? NSNumber {
                    height = CGFloat(truncating: number)
                } else if let double = value as? Double {
                    height = CGFloat(double)
                } else {
                    height = 0
                }

                DispatchQueue.main.async {
                    self?.contentHeight.wrappedValue = max(height, 1)
                }
            }
        }
    }
}
#endif
