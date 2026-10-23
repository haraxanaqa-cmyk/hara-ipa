import UIKit
import WebKit

/// Full-screen WKWebView shell around Dylib Lens.
///
/// The scanner itself runs in a Web Worker, so the page must be served over
/// http(s) — a file:// bundle would give the worker an opaque origin and the
/// scan would die on the first chunk. The hosted build (and its service-worker
/// cache) keeps the whole UI local after the first launch, and file bytes never
/// leave the device because all parsing happens in the web view.
final class LensWebViewController: UIViewController {

    /// Change this single line to point the shell at another deployment.
    static let appURL = URL(string: "https://dylib-lens.web.zaka.live/")!

    private let progressBar = UIProgressView(progressViewStyle: .bar)
    private var progressObservation: NSKeyValueObservation?
    private var webView: WKWebView!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.043, green: 0.063, blue: 0.094, alpha: 1)
        configureWebView()
        configureProgressBar()
        configureRefreshControl()
        loadApp()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .default }

    // MARK: - Setup

    private func configureWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.bounces = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = view.backgroundColor
        webView.scrollView.backgroundColor = view.backgroundColor
        webView.customUserAgent = "DylibLens/1.0 (iOS)"

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        self.webView = webView

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            guard let self else { return }
            let progress = Float(webView.estimatedProgress)
            self.progressBar.setProgress(progress, animated: progress < 1)
            self.progressBar.isHidden = progress >= 1
        }
    }

    private func configureProgressBar() {
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = UIColor(red: 0.33, green: 0.87, blue: 0.74, alpha: 1)
        progressBar.trackTintColor = .clear
        progressBar.isHidden = true
        view.addSubview(progressBar)
        NSLayoutConstraint.activate([
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    private func configureRefreshControl() {
        let refresh = UIRefreshControl()
        refresh.tintColor = UIColor(red: 0.33, green: 0.87, blue: 0.74, alpha: 1)
        refresh.addTarget(self, action: #selector(reload), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
    }

    // MARK: - Loading

    private func loadApp() {
        var request = URLRequest(url: Self.appURL)
        request.cachePolicy = .useProtocolCachePolicy
        request.timeoutInterval = 30
        webView.load(request)
    }

    @objc private func reload() {
        removeErrorView()
        if webView.url == nil {
            loadApp()
        } else {
            webView.reload()
        }
        webView.scrollView.refreshControl?.endRefreshing()
    }

    // MARK: - Offline / error state

    private func showErrorView(message: String) {
        removeErrorView()

        let container = UIView()
        container.tag = 9_001
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = view.backgroundColor

        let title = UILabel()
        title.text = "Can't reach Dylib Lens"
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.textColor = .white
        title.textAlignment = .center

        let detail = UILabel()
        detail.text = message
        detail.font = .systemFont(ofSize: 14)
        detail.textColor = UIColor(white: 0.65, alpha: 1)
        detail.numberOfLines = 0
        detail.textAlignment = .center

        let retry = UIButton(type: .system)
        retry.setTitle("Try again", for: .normal)
        retry.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        retry.setTitleColor(UIColor(red: 0.33, green: 0.87, blue: 0.74, alpha: 1), for: .normal)
        retry.addTarget(self, action: #selector(reload), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, detail, retry])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32)
        ])
    }

    private func removeErrorView() {
        view.viewWithTag(9_001)?.removeFromSuperview()
    }
}

// MARK: - WKNavigationDelegate

extension LensWebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        removeErrorView()
        webView.scrollView.refreshControl?.endRefreshing()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webView.scrollView.refreshControl?.endRefreshing()
        if (error as NSError).code == NSURLErrorCancelled { return }
        showErrorView(message: error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webView.scrollView.refreshControl?.endRefreshing()
        if (error as NSError).code == NSURLErrorCancelled { return }
        showErrorView(message: error.localizedDescription)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Keep the shell in-app; anything outside the deployment opens in Safari.
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        let internalHost = Self.appURL.host
        let isHTTP = url.scheme == "http" || url.scheme == "https"
        let isSameHost = isHTTP && url.host == internalHost

        if isSameHost {
            decisionHandler(.allow)
            return
        }
        if isHTTP {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        // blob:, data:, about: and friends are used by the exporter.
        decisionHandler(url.scheme == "about" || url.scheme == "blob" || url.scheme == "data" ? .allow : .cancel)
    }
}

// MARK: - WKUIDelegate

extension LensWebViewController: WKUIDelegate {

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.prompt)
    }
}
