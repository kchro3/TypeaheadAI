//
//  SafariView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/12/23.
//

import SwiftUI
import WebKit

struct SafariNSView: NSViewRepresentable {
    let request: URLRequest
    let onRedirect: (() -> Void)

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.load(request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onRedirect: onRedirect)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var onRedirect: () -> Void

        init(onRedirect: @escaping () -> Void) {
            self.onRedirect = onRedirect
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               url.host == "login-callback" {
                onRedirect()
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}

struct SafariView: View {
    let request: URLRequest
    let onRedirect: (() -> Void)

    var body: some View {
        SafariNSView(request: request, onRedirect: onRedirect)
    }
}

#Preview {
    SafariView(
        request: URLRequest(url: URL(string: "https://www.google.com")!),
        onRedirect: {}
    )
}
