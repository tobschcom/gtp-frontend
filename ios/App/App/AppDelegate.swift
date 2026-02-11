import UIKit
import Capacitor
import WebKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidBecomeActive(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}

private enum GTPNativeTab: Int, CaseIterable {
    case overview
    case search
    case ecosystem
    case apps
    case chains

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .search: return "Search"
        case .ecosystem: return "Ecosystem"
        case .apps: return "Apps"
        case .chains: return "Chains"
        }
    }

    var route: String {
        switch self {
        case .overview: return "/"
        case .search: return "/?search=true"
        case .ecosystem: return "/ethereum-ecosystem/metrics"
        case .apps: return "/applications"
        case .chains: return "/chains"
        }
    }

}

class AppBridgeViewController: CAPBridgeViewController {
    private let nativeBottomBar = NativeBottomBarView(tabs: GTPNativeTab.allCases)
    private var webURLObservation: NSKeyValueObservation?
    private var didInstallNativeWebIntegrations = false
    private var didInstallNativeOverlayChrome = false

    override open func viewDidLoad() {
        super.viewDidLoad()
        installNativeOverlayChromeIfNeeded()
        installNativeWebIntegrationsIfPossible()
        observeWebURLChanges()
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installNativeWebIntegrationsIfPossible()
    }

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure native controls stay above the webview.
        view.bringSubviewToFront(nativeBottomBar)
        nativeBottomBar.layer.zPosition = 9999
        installNativeWebIntegrationsIfPossible()
        updateNativeSafeAreaCSSVars()
    }

    deinit {
        webURLObservation?.invalidate()
    }

    private func installNativeOverlayChromeIfNeeded() {
        guard !didInstallNativeOverlayChrome else {
            return
        }
        didInstallNativeOverlayChrome = true

        nativeBottomBar.translatesAutoresizingMaskIntoConstraints = false
        nativeBottomBar.layer.zPosition = 9999
        view.addSubview(nativeBottomBar)

        NSLayoutConstraint.activate([
            nativeBottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            nativeBottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            nativeBottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])

        nativeBottomBar.onTabSelected = { [weak self] tab in
            if tab == .search {
                self?.openSearchOverlayInPlace()
                return
            }
            self?.open(route: tab.route)
        }

    }

    private func installNativeWebIntegrationsIfPossible() {
        guard !didInstallNativeWebIntegrations, bridge?.webView != nil else {
            return
        }
        didInstallNativeWebIntegrations = true
        installNativeLogoHiding()
        installNativeWebTopBarHiding()
        installNativeBottomInsetPadding()
    }

    private func observeWebURLChanges() {
        guard let webView = bridge?.webView else {
            return
        }

        webURLObservation = webView.observe(\.url, options: [.new, .initial]) { [weak self] observedWebView, change in
            guard let self else { return }
            let tab = self.tabForCurrentURL(change.newValue ?? observedWebView.url)
            self.nativeBottomBar.setSelected(tab: tab)
        }
    }

    private func tabForCurrentURL(_ url: URL?) -> GTPNativeTab? {
        guard let url else {
            return nil
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           components.queryItems?.contains(where: { $0.name == "search" && $0.value == "true" }) == true {
            return .search
        }

        let path = url.path.lowercased()
        if path.hasPrefix("/ethereum-ecosystem") {
            return .ecosystem
        }
        if path.hasPrefix("/applications") {
            return .apps
        }
        if path.hasPrefix("/chains") {
            return .chains
        }
        if path == "/" || path.isEmpty {
            return .overview
        }
        return .overview
    }

    private func open(route: String) {
        guard let webView = bridge?.webView,
              let destination = makeRouteURL(from: route) else {
            return
        }

        if webView.url?.absoluteString == destination.absoluteString {
            return
        }

        webView.load(URLRequest(url: destination))
    }

    private func makeRouteURL(from route: String) -> URL? {
        if route.hasPrefix("http://") || route.hasPrefix("https://") {
            return URL(string: route)
        }

        let currentURL = bridge?.webView?.url
        let baseURL = currentURL ?? bridge?.config.serverURL ?? URL(string: "https://growthepie.com")
        guard let baseURL,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let split = route.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let rawPath = split.first.map(String.init) ?? "/"
        components.path = rawPath.hasPrefix("/") ? rawPath : "/" + rawPath
        components.percentEncodedQuery = split.count > 1 ? String(split[1]) : nil
        return components.url
    }

    private func presentNavigationMenu() {
        let alert = UIAlertController(title: nil, message: "Navigate", preferredStyle: .actionSheet)
        let entries: [(String, String)] = [
            ("Home", "/"),
            ("Search", GTPNativeTab.search.route),
            ("Ecosystem", GTPNativeTab.ecosystem.route),
            ("Apps", GTPNativeTab.apps.route),
            ("Chains", GTPNativeTab.chains.route)
        ]

        entries.forEach { title, route in
            alert.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
                if route == GTPNativeTab.search.route {
                    self?.openSearchOverlayInPlace()
                    return
                }
                self?.open(route: route)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = nativeBottomBar
            popover.sourceRect = nativeBottomBar.bounds
        }

        present(alert, animated: true)
    }

    private func jsStringLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
              let jsonArray = String(data: data, encoding: .utf8),
              jsonArray.count >= 2 else {
            return "\"\""
        }
        return String(jsonArray.dropFirst().dropLast())
    }

    private func openSearchOverlayInPlace(query: String = "") {
        guard let webView = bridge?.webView else {
            return
        }

        let queryLiteral = jsStringLiteral(query.trimmingCharacters(in: .whitespacesAndNewlines))
        let openSearchScript = """
        (function() {
          try {
            var url = new URL(window.location.href);
            url.searchParams.set("search", "true");

            var query = \(queryLiteral);
            if (query && query.length > 0) {
              url.searchParams.set("query", query);
            }

            var next = url.pathname + "?" + decodeURIComponent(url.searchParams.toString()) + url.hash;
            window.history.replaceState(null, "", next);
            window.dispatchEvent(new PopStateEvent("popstate"));

            var attempts = 0;
            var focusInput = function() {
              var input = document.getElementById("global-search-input");
              if (!input) return false;
              input.focus();
              input.click();
              try {
                var end = (input.value || "").length;
                input.setSelectionRange(end, end);
              } catch (e) {}
              return true;
            };

            if (!focusInput()) {
              var timer = setInterval(function() {
                attempts += 1;
                if (focusInput() || attempts > 16) {
                  clearInterval(timer);
                }
              }, 80);
            }
          } catch (e) {}
        })();
        """

        webView.evaluateJavaScript(openSearchScript, completionHandler: nil)
        nativeBottomBar.setSelected(tab: .search)
    }

    private func installNativeBottomInsetPadding() {
        guard let webView = bridge?.webView else {
            return
        }

        let insetScript = """
        (function() {
          if (window.__gtpNativeInsetInstalled) return;
          window.__gtpNativeInsetInstalled = true;

          var style = document.createElement("style");
          style.id = "gtp-native-ios-inset-style";
          style.textContent = ":root{--gtp-native-safe-top-content:max(56px, calc(env(safe-area-inset-top) + 34px));--gtp-native-safe-top-search:max(146px, calc(env(safe-area-inset-top) + 86px));--gtp-native-safe-bottom-content:max(112px, env(safe-area-inset-bottom));}body{padding-top:var(--gtp-native-safe-top-content) !important;padding-bottom:var(--gtp-native-safe-bottom-content) !important;}main{padding-top:var(--gtp-native-safe-top-content) !important;}";
          document.head.appendChild(style);
        })();
        """

        let userScript = WKUserScript(
            source: insetScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        webView.configuration.userContentController.addUserScript(userScript)
        webView.evaluateJavaScript(insetScript, completionHandler: nil)
        updateNativeSafeAreaCSSVars()
    }

    private func updateNativeSafeAreaCSSVars() {
        guard let webView = bridge?.webView else {
            return
        }

        let contentTopInset = max(56.0, view.safeAreaInsets.top + 34.0)
        let searchTopInset = max(146.0, view.safeAreaInsets.top + 86.0)
        let bottomInset = max(112.0, view.safeAreaInsets.bottom + 92.0)

        let safeAreaScript = """
        (function() {
          var root = document.documentElement;
          if (!root) return;
          root.style.setProperty("--gtp-native-safe-top-content", "\(Int(contentTopInset))px");
          root.style.setProperty("--gtp-native-safe-top-search", "\(Int(searchTopInset))px");
          root.style.setProperty("--gtp-native-safe-bottom-content", "\(Int(bottomInset))px");
        })();
        """

        webView.evaluateJavaScript(safeAreaScript, completionHandler: nil)
    }

    private func installNativeWebTopBarHiding() {
        guard let webView = bridge?.webView else {
            return
        }

        let hideTopBarScript = """
        (function() {
          if (window.__gtpHideTopBarInstalled) return;
          window.__gtpHideTopBarInstalled = true;

          var logoSelectors = [
            "a[title='Link to growthepie']",
            "a[aria-label='Link to growthepie']",
            "a.gtp-native-hide-logo",
            "img[src*='logo_fees_full']",
            "img[src*='logo_labels_full']",
            "img[src*='logo_icons_full']",
            "svg[viewBox='0 0 194 46']",
            "svg[viewBox='0 0 155 36']"
          ];

          var hideNode = function(node) {
            if (!node || node.dataset.gtpNativeHidden === "1") return;
            node.dataset.gtpNativeHidden = "1";
            node.style.setProperty("display", "none", "important");
            node.style.setProperty("visibility", "hidden", "important");
            node.style.setProperty("pointer-events", "none", "important");
          };

          var hideTopBars = function() {
            logoSelectors.forEach(function(selector) {
              document.querySelectorAll(selector).forEach(function(node) {
                var header = node.closest("header");
                if (header) {
                  var fixedContainer = header.closest("div.fixed, div[class*='fixed']");
                  if (fixedContainer) {
                    hideNode(fixedContainer);
                  } else {
                    hideNode(header);
                  }
                }
              });
            });

            document.querySelectorAll(".gtp-native-hide-logo").forEach(function(node) {
              hideNode(node);
              var header = node.closest("header");
              if (header) {
                hideNode(header);
              }
              var fixedWrapper = node.closest("div.fixed, div[class*='fixed']");
              if (fixedWrapper) {
                hideNode(fixedWrapper);
              }
            });

            document.querySelectorAll("header").forEach(function(header) {
              var rect = header.getBoundingClientRect();
              var style;
              try {
                style = window.getComputedStyle(header);
              } catch (e) {
                return;
              }

              if ((style.position === "fixed" || style.position === "sticky" || rect.top <= 20) && rect.height <= 240) {
                hideNode(header);
              }
            });
          };

          var hideBottomWebChrome = function() {
            document.querySelectorAll("nav,div,footer").forEach(function(node) {
              if (!node) return;
              var classList = node.classList;
              var containsNativeSearchContainer = classList && classList.contains("gtp-native-search-container");
              var hasNativeSearchChild = !!node.querySelector(".gtp-native-search-container");
              var isGlobalSearchInput = node.id === "global-search-input";
              var hasGlobalSearchInputChild = !!node.querySelector("#global-search-input");
              if (
                containsNativeSearchContainer ||
                hasNativeSearchChild ||
                isGlobalSearchInput ||
                hasGlobalSearchInputChild
              ) {
                return;
              }

              var style;
              try {
                style = window.getComputedStyle(node);
              } catch (e) {
                return;
              }
              if (!style || (style.position !== "fixed" && style.position !== "sticky")) return;

              var rect;
              try {
                rect = node.getBoundingClientRect();
              } catch (e) {
                return;
              }
              if (!rect || rect.height <= 0) return;
              if (rect.bottom < window.innerHeight - 12) return;
              if (rect.height > 220) return;

              var text = (node.innerText || node.textContent || "").toLowerCase();
              var looksLikeWebBottomNav =
                text.includes("search") &&
                text.includes("ecosystem") &&
                text.includes("apps") &&
                text.includes("chains");

              if (looksLikeWebBottomNav) {
                hideNode(node);
              }

              var hasSearchInput = !!node.querySelector("input[placeholder*='Search'], input[aria-label*='Search']");
              var hasManyNavLinks = node.querySelectorAll("a,button").length >= 4;
              if ((hasSearchInput && hasManyNavLinks) || (hasManyNavLinks && text.includes("search"))) {
                hideNode(node);
              }

              var looksLikeCookieBanner =
                text.includes("cookie") &&
                text.includes("allow") &&
                text.includes("decline");
              if (looksLikeCookieBanner) {
                hideNode(node);
              }
            });
          };

          var hideNativeWrapperChrome = function() {
            document.querySelectorAll(".gtp-native-hide-global-floatingbar, .z-global-search, .z-global-search-backdrop").forEach(function(node) {
              hideNode(node);
            });
          };

          hideTopBars();
          hideBottomWebChrome();
          hideNativeWrapperChrome();

          var observer = new MutationObserver(function() {
            hideTopBars();
            hideBottomWebChrome();
            hideNativeWrapperChrome();
          });

          observer.observe(document.documentElement || document.body, {
            childList: true,
            subtree: true
          });
        })();
        """

        let userScript = WKUserScript(
            source: hideTopBarScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        webView.configuration.userContentController.addUserScript(userScript)
        webView.evaluateJavaScript(hideTopBarScript, completionHandler: nil)
    }

    private func installNativeLogoHiding() {
        guard let webView = bridge?.webView else {
            return
        }

        let hideLogoScript = """
        (function() {
          if (window.__gtpHideLogoInstalled) return;
          window.__gtpHideLogoInstalled = true;

          var selectors = [
            ".gtp-native-hide-logo",
            "a[title='Link to growthepie']",
            "a[aria-label='Link to growthepie']",
            "img[src*='logo_fees_full']",
            "img[src*='logo_labels_full']",
            "img[src*='logo_icons_full']",
            "img[src*='logo-full']",
            "img[src*='grow_the_pie_full']",
            "img[src*='gtp_logo']",
            "svg[viewBox='0 0 194 46']",
            "svg[viewBox='0 0 155 36']",
            "svg[viewBox='0 0 43 46']"
          ];

          var shouldHideLink = function(link) {
            if (!link) return false;
            var href = (link.getAttribute("href") || "").trim();
            return href === "/" || href === "https://www.growthepie.com/" || href === "https://growthepie.com/";
          };

          var hideElement = function(el) {
            if (!el) return;

            var target = el;
            var nearestLink = el.closest("a");
            if (shouldHideLink(nearestLink)) {
              target = nearestLink;
            }

            target.style.display = "none";
            target.style.visibility = "hidden";
            target.style.pointerEvents = "none";
          };

          var hideKnownLogos = function() {
            selectors.forEach(function(selector) {
              document.querySelectorAll(selector).forEach(hideElement);
            });
          };

          hideKnownLogos();

          var observer = new MutationObserver(function() {
            hideKnownLogos();
          });

          observer.observe(document.documentElement || document.body, {
            childList: true,
            subtree: true
          });
        })();
        """

        let userScript = WKUserScript(
            source: hideLogoScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )

        webView.configuration.userContentController.addUserScript(userScript)
        webView.evaluateJavaScript(hideLogoScript, completionHandler: nil)
    }
}

private final class NativeBottomBarView: UIView, UITabBarDelegate {
    var onTabSelected: ((GTPNativeTab) -> Void)?

    private let tabBar = UITabBar()
    private var selectedTab: GTPNativeTab?

    init(tabs: [GTPNativeTab]) {
        super.init(frame: .zero)
        setup(tabs: tabs)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup(tabs: GTPNativeTab.allCases)
    }

    private func setup(tabs: [GTPNativeTab]) {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        isUserInteractionEnabled = true

        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.delegate = self
        tabBar.isTranslucent = true
        tabBar.layer.cornerRadius = 30
        tabBar.layer.cornerCurve = .continuous
        tabBar.layer.masksToBounds = true
        tabBar.layer.borderWidth = 0.5
        tabBar.layer.borderColor = UIColor.separator.withAlphaComponent(0.4).cgColor
        tabBar.tintColor = UIColor.label

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
            appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.5)
            appearance.shadowColor = .clear

            let normal = appearance.stackedLayoutAppearance.normal
            normal.titleTextAttributes = [
                .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
                .foregroundColor: UIColor.secondaryLabel
            ]
            normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 4)
            normal.iconColor = UIColor.secondaryLabel

            let selected = appearance.stackedLayoutAppearance.selected
            selected.titleTextAttributes = [
                .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 4)
            selected.iconColor = UIColor.label

            appearance.inlineLayoutAppearance = appearance.stackedLayoutAppearance
            appearance.compactInlineLayoutAppearance = appearance.stackedLayoutAppearance
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }

        tabBar.layer.shadowColor = UIColor.black.cgColor
        tabBar.layer.shadowOpacity = 0.14
        tabBar.layer.shadowRadius = 20
        tabBar.layer.shadowOffset = CGSize(width: 0, height: 12)
        addSubview(tabBar)

        let items = tabs.map(makeItem(for:))
        items.forEach { item in
            item.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 4)
            item.imageInsets = UIEdgeInsets(top: -4, left: 0, bottom: 4, right: 0)
        }
        tabBar.items = items

        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: topAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 84),
            tabBar.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func iconImage(named name: String) -> UIImage? {
        UIImage(named: name)?.withRenderingMode(.alwaysOriginal)
    }

    private func makeItem(for tab: GTPNativeTab) -> UITabBarItem {
        let imageName: String
        switch tab {
        case .overview:
            imageName = "NativeTabOverview"
        case .search:
            imageName = "NativeTabSearch"
        case .ecosystem:
            imageName = "NativeTabEcosystem"
        case .apps:
            imageName = "NativeTabApps"
        case .chains:
            imageName = "NativeTabChains"
        }
        let item = UITabBarItem(title: tab.title, image: iconImage(named: imageName), selectedImage: iconImage(named: imageName))
        item.tag = tab.rawValue
        return item
    }

    func setSelected(tab: GTPNativeTab?) {
        selectedTab = tab
        guard let tab else {
            tabBar.selectedItem = nil
            return
        }
        tabBar.selectedItem = tabBar.items?.first(where: { $0.tag == tab.rawValue })
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let tab = GTPNativeTab(rawValue: item.tag) else {
            return
        }

        if tab == .search {
            setSelected(tab: .search)
            onTabSelected?(.search)
            return
        }

        setSelected(tab: tab)
        onTabSelected?(tab)
    }
}

private final class NativeBottomTabButton: UIControl {
    private let iconView: GTPSVGIconView
    private let titleLabelView: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10.5, weight: .semibold)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.textColor = UIColor.secondaryLabel
        return label
    }()

    override var isSelected: Bool {
        didSet {
            updateStyle()
        }
    }

    init(title: String, iconSVG: String) {
        self.iconView = GTPSVGIconView(svgMarkup: iconSVG, iconSize: 20)
        super.init(frame: .zero)
        titleLabelView.text = title
        setup()
    }

    required init?(coder: NSCoder) {
        self.iconView = GTPSVGIconView(svgMarkup: GTPNativeIconSVG.search, iconSize: 20)
        super.init(coder: coder)
        titleLabelView.text = ""
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView(arrangedSubviews: [iconView, titleLabelView])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20)
        ])

        updateStyle()
    }

    private func updateStyle() {
        iconView.alpha = isSelected ? 1 : 0.72
        titleLabelView.textColor = isSelected ? UIColor.label : UIColor.secondaryLabel
    }
}

private final class GTPSVGIconView: UIView {
    private let webView: WKWebView

    init(svgMarkup: String, iconSize: CGFloat) {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false

        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init(frame: .zero)
        setup(svgMarkup: svgMarkup, iconSize: iconSize)
    }

    required init?(coder: NSCoder) {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init(coder: coder)
        setup(svgMarkup: GTPNativeIconSVG.search, iconSize: 20)
    }

    private func setup(svgMarkup: String, iconSize: CGFloat) {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false

        addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let html = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0" />
          <style>
            html, body {
              margin: 0;
              padding: 0;
              width: 100%;
              height: 100%;
              display: flex;
              align-items: center;
              justify-content: center;
              background: transparent;
              overflow: hidden;
            }
            svg {
              width: \(iconSize)px;
              height: \(iconSize)px;
              display: block;
            }
          </style>
        </head>
        <body>
          \(svgMarkup)
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }
}

private enum GTPNativeIconSVG {
    static let search = """
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <g clip-path="url(#clip0_3218_88156)">
    <path fill-rule="evenodd" clip-rule="evenodd" d="M23.561 23.6952C23.1546 24.1016 22.4956 24.1016 22.0892 23.6952L14.5002 16.1062C14.0937 15.6997 14.0937 15.0408 14.5002 14.6343L14.6344 14.5002C15.0408 14.0937 15.6998 14.0937 16.1062 14.5002L23.6952 22.0892C24.1016 22.4956 24.1016 23.1545 23.6952 23.561L23.561 23.6952Z" fill="url(#paint0_linear_3218_88156)"/>
    <path fill-rule="evenodd" clip-rule="evenodd" d="M19 9.5C19 14.7467 14.7467 19 9.5 19C4.25329 19 0 14.7467 0 9.5C0 4.25329 4.25329 0 9.5 0C14.7467 0 19 4.25329 19 9.5ZM9.5 16.4091C13.3158 16.4091 16.4091 13.3158 16.4091 9.5C16.4091 5.68421 13.3158 2.59091 9.5 2.59091C5.68421 2.59091 2.59091 5.68421 2.59091 9.5C2.59091 13.3158 5.68421 16.4091 9.5 16.4091Z" fill="url(#paint1_linear_3218_88156)"/>
    <path d="M7.33496 6.20898C7.43625 5.98559 7.91544 5.05957 9.91309 5.05957C12.2915 5.05968 14.1904 6.94354 14.1904 9.23144C14.1904 10.4546 13.8511 10.9646 13.6201 11.1787C13.3918 11.3903 13.1386 11.4329 13.0254 11.4385C12.9662 11.312 12.916 11.0927 12.8437 10.6748C12.7114 9.90858 12.5329 8.63839 11.5723 7.67773C10.5969 6.70237 9.17051 6.53877 8.30469 6.41211C7.8131 6.34019 7.5173 6.28694 7.33496 6.20898Z" fill="url(#paint2_linear_3218_88156)" stroke="url(#paint3_linear_3218_88156)" stroke-width="1.61932"/>
    </g>
    <defs>
    <linearGradient id="paint0_linear_3218_88156" x1="19.0978" y1="14.1955" x2="19.0978" y2="24" gradientUnits="userSpaceOnUse">
    <stop stop-color="#FE5468"/>
    <stop offset="1" stop-color="#FFDF27"/>
    </linearGradient>
    <linearGradient id="paint1_linear_3218_88156" x1="9.5" y1="0" x2="9.5" y2="19" gradientUnits="userSpaceOnUse">
    <stop stop-color="#FE5468"/>
    <stop offset="1" stop-color="#FFDF27"/>
    </linearGradient>
    <linearGradient id="paint2_linear_3218_88156" x1="6.5" y1="8.25" x2="15" y2="8.25" gradientUnits="userSpaceOnUse">
    <stop stop-color="#10808C"/>
    <stop offset="1" stop-color="#1DF7EF"/>
    </linearGradient>
    <linearGradient id="paint3_linear_3218_88156" x1="6.5" y1="8.25" x2="15" y2="8.25" gradientUnits="userSpaceOnUse">
    <stop stop-color="#10808C"/>
    <stop offset="1" stop-color="#1DF7EF"/>
    </linearGradient>
    <clipPath id="clip0_3218_88156">
    <rect width="24" height="24" fill="white"/>
    </clipPath>
    </defs>
    </svg>
    """

    static let ecosystem = """
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <g clip-path="url(#clip0_3218_86633)">
    <path d="M2.24562 17.7384C4.49046 18.9728 7.92779 19.9713 12 20.0705C16.0722 19.9713 19.5095 18.9728 21.7544 17.7384C22.7578 17.1866 23.5229 16.5878 24 16.001C23.6974 16.8968 23.2263 17.8528 22.7378 18.7127C21.9575 20.0865 21.1332 21.215 20.8816 21.4608C19.6396 22.6857 15.971 23.7204 12.6667 23.9524C12.4425 23.9681 12.22 23.9802 12 23.9883C11.78 23.9802 11.5575 23.9681 11.3333 23.9524C8.02903 23.7204 4.36041 22.6857 3.11838 21.4608C2.86683 21.215 2.04246 20.0865 1.26216 18.7127C0.773739 17.8528 0.302586 16.8968 0 16.001C0.477094 16.5878 1.24223 17.1866 2.24562 17.7384Z" fill="url(#paint0_linear_3218_86633)"/>
    <path d="M15.1924 10.122C14.6642 10.07 14.0988 10.038 13.5325 10.02L12.0423 10.8973L10.5479 10.0176C9.98302 10.0342 9.41738 10.0645 8.88682 10.1144L12.0423 14.5369L15.1924 10.122Z" fill="url(#paint1_linear_3218_86633)"/>
    <path fill-rule="evenodd" clip-rule="evenodd" d="M0 14.3166C0 12.5345 2.96315 11.0013 7.19736 10.3291L12.0423 17.1195L16.8786 10.3413C21.0723 11.0197 24 12.5452 24 14.3166C24 16.7176 18.6235 18.6669 12 18.6675C5.37649 18.6669 0 16.7176 0 14.3166Z" fill="url(#paint2_linear_3218_86633)"/>
    <path d="M12.042 10.8975L7.56445 8.26172L12.042 14.5372L16.5195 8.26172L12.042 10.8975Z" fill="url(#paint3_linear_3218_86633)"/>
    <path d="M12.042 0L16.5194 7.41242L12.042 10.0555L7.56445 7.41277L12.042 0Z" fill="url(#paint4_linear_3218_86633)"/>
    </g>
    <defs>
    <linearGradient id="paint0_linear_3218_86633" x1="12" y1="16.001" x2="12" y2="23.9883" gradientUnits="userSpaceOnUse">
    <stop stop-color="#10808C"/>
    <stop offset="1" stop-color="#1DF7EF"/>
    </linearGradient>
    <linearGradient id="paint1_linear_3218_86633" x1="12" y1="10.0176" x2="12" y2="18.6675" gradientUnits="userSpaceOnUse">
    <stop stop-color="#FE5468"/>
    <stop offset="1" stop-color="#FFDF27"/>
    </linearGradient>
    <linearGradient id="paint2_linear_3218_86633" x1="12" y1="10.0176" x2="12" y2="18.6675" gradientUnits="userSpaceOnUse">
    <stop stop-color="#FE5468"/>
    <stop offset="1" stop-color="#FFDF27"/>
    </linearGradient>
    <linearGradient id="paint3_linear_3218_86633" x1="12.042" y1="8.26172" x2="12.042" y2="14.5372" gradientUnits="userSpaceOnUse">
    <stop stop-color="#10808C"/>
    <stop offset="1" stop-color="#1DF7EF"/>
    </linearGradient>
    <linearGradient id="paint4_linear_3218_86633" x1="12.0419" y1="0" x2="12.0419" y2="10.0555" gradientUnits="userSpaceOnUse">
    <stop stop-color="#FE5468"/>
    <stop offset="1" stop-color="#FFDF27"/>
    </linearGradient>
    <clipPath id="clip0_3218_86633">
    <rect width="24" height="24" fill="white"/>
    </clipPath>
    </defs>
    </svg>
    """

    static let apps = """
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <g clip-path="url(#clip0_3218_86537)">
    <path fill-rule="evenodd" clip-rule="evenodd" d="M5.6 0C2.53957 0.000405855 0.0527212 2.45582 0.0015625 5.50415L0 5.50625V20C0 21.6 1.6 24 4 24H24V4.8H6.4V0H5.6C5.60025 0 5.59975 0 5.6 0ZM4.8 1.68017C4.52203 1.73665 4.25453 1.82196 4.00076 1.93283C2.58803 2.55008 1.60076 3.95974 1.60076 5.6L1.6 16.0816C2.44015 15.2239 3.55388 14.6352 4.8 14.4568V1.68017ZM5.60076 16C5.03188 16 4.49073 16.1188 4.00076 16.3328C2.58803 16.9501 1.60076 18.3597 1.60076 20C1.60076 20.3357 1.80375 20.9745 2.30412 21.5464C2.77801 22.088 3.36756 22.4 4 22.4H22.4V6.4H6.4V16H5.60076Z" fill="url(#paint0_linear_3218_86537)"/>
    <path fill-rule="evenodd" clip-rule="evenodd" d="M9.66667 9C8.74619 9 8 9.74619 8 10.6667V17.3333C8 18.2538 8.74619 19 9.66667 19H16.3333C17.2538 19 18 18.2538 18 17.3333V10.6667C18 9.74619 17.2538 9 16.3333 9H9.66667ZM13.6808 11.1189C13.4123 10.5159 12.5877 10.5159 12.3192 11.1189L11.9032 12.053C11.7939 12.2985 11.5701 12.4675 11.3117 12.4997L10.3285 12.6222C9.69377 12.7013 9.43894 13.5165 9.90771 13.9682L10.6339 14.668C10.8247 14.8519 10.9102 15.1255 10.8598 15.3908L10.6681 16.4006C10.5443 17.0525 11.2115 17.5563 11.7697 17.2325L12.6344 16.7309C12.8616 16.5991 13.1384 16.5991 13.3656 16.7309L14.2303 17.2325C14.7885 17.5563 15.4557 17.0525 15.3319 16.4006L15.1402 15.3908C15.0898 15.1255 15.1753 14.8519 15.3661 14.668L16.0923 13.9682C16.5611 13.5165 16.3062 12.7013 15.6715 12.6222L14.6883 12.4997C14.4299 12.4675 14.2061 12.2985 14.0968 12.053L13.6808 11.1189Z" fill="url(#paint1_linear_3218_86537)"/>
    </g>
    <defs>
    <linearGradient id="paint0_linear_3218_86537" x1="12" y1="0" x2="12" y2="24" gradientUnits="userSpaceOnUse">
    <stop stop-color="#10808C"/>
    <stop offset="1" stop-color="#1DF7EF"/>
    </linearGradient>
    <linearGradient id="paint1_linear_3218_86537" x1="13" y1="9" x2="13" y2="19" gradientUnits="userSpaceOnUse">
    <stop stop-color="#FE5468"/>
    <stop offset="1" stop-color="#FFDF27"/>
    </linearGradient>
    <clipPath id="clip0_3218_86537">
    <rect width="24" height="24" fill="white"/>
    </clipPath>
    </defs>
    </svg>
    """

    static let chains = """
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path fill-rule="evenodd" clip-rule="evenodd" d="M13.0614 1.80393C14.2787 0.633334 15.9092 -0.0143988 17.6015 0.00024293C19.2939 0.0148847 20.9128 0.690729 22.1095 1.88221C23.3062 3.0737 23.9851 4.68549 23.9998 6.37044C24.0145 8.05538 23.3639 9.67868 22.1881 10.8907L22.175 10.904L18.9479 14.117C18.2935 14.7687 17.5061 15.2727 16.6389 15.5947C15.7717 15.9168 14.8451 16.0494 13.9219 15.9836C12.9987 15.9178 12.1005 15.655 11.2883 15.2132C10.4761 14.7714 9.76878 14.1608 9.21439 13.4229C8.85852 12.9493 8.95571 12.278 9.43147 11.9237C9.90722 11.5694 10.5814 11.6662 10.9373 12.1399C11.3068 12.6318 11.7784 13.0388 12.3199 13.3334C12.8614 13.6279 13.4601 13.8031 14.0756 13.847C14.6911 13.8908 15.3088 13.8024 15.8869 13.5877C16.465 13.373 16.99 13.037 17.4262 12.6025L17.4264 12.6024L20.6467 9.39622C21.4267 8.5889 21.8581 7.50942 21.8483 6.38905C21.8385 5.26575 21.386 4.19122 20.5881 3.3969C19.7903 2.60258 18.7111 2.15202 17.5828 2.14225C16.457 2.13251 15.3724 2.56244 14.5614 3.33962L12.7169 5.16536C12.2955 5.58241 11.6144 5.58043 11.1955 5.16094C10.7766 4.74146 10.7786 4.06331 11.1999 3.64626L13.0503 1.81477L13.0614 1.80393Z" fill="url(#paint0_linear_3218_88338)"/>
    <path fill-rule="evenodd" clip-rule="evenodd" d="M7.36112 8.40527C8.2283 8.08321 9.15491 7.95059 10.0781 8.01642C11.0013 8.08225 11.8995 8.34498 12.7117 8.78679C13.5239 9.22861 14.2312 9.83917 14.7856 10.5771C15.1415 11.0507 15.0443 11.722 14.5685 12.0763C14.0928 12.4306 13.4186 12.3338 13.0627 11.8601C12.6932 11.3682 12.2216 10.9612 11.6801 10.6666C11.1386 10.3721 10.5399 10.1969 9.9244 10.153C9.30895 10.1092 8.69121 10.1976 8.11309 10.4123C7.53496 10.627 7.00998 10.963 6.57375 11.3975L3.35331 14.6038C2.57334 15.4111 2.14191 16.4906 2.15168 17.611C2.16149 18.7343 2.61404 19.8088 3.41185 20.6031C4.20967 21.3974 5.28893 21.848 6.41717 21.8577C7.54247 21.8675 8.62669 21.4379 9.43757 20.6614L11.2702 18.8368C11.6903 18.4186 12.3714 18.4186 12.7915 18.8368C13.2116 19.2551 13.2116 19.9333 12.7915 20.3515L10.952 22.183L10.9386 22.1961C9.72128 23.3667 8.09085 24.0144 6.39848 23.9998C4.70611 23.9851 3.08723 23.3093 1.8905 22.1178C0.69377 20.9263 0.0149502 19.3145 0.000243999 17.6296C-0.0144622 15.9446 0.636122 14.3213 1.81187 13.1093L1.82498 13.096L5.05212 9.88304C5.05208 9.88308 5.05217 9.88299 5.05212 9.88304C5.70644 9.23139 6.494 8.72732 7.36112 8.40527Z" fill="url(#paint1_linear_3218_88338)"/>
    <defs>
    <linearGradient id="paint0_linear_3218_88338" x1="16.5" y1="0" x2="16.5" y2="16" gradientUnits="userSpaceOnUse">
    <stop stop-color="#FE5468"/>
    <stop offset="1" stop-color="#FFDF27"/>
    </linearGradient>
    <linearGradient id="paint1_linear_3218_88338" x1="7.5" y1="8" x2="7.5" y2="24" gradientUnits="userSpaceOnUse">
    <stop stop-color="#10808C"/>
    <stop offset="1" stop-color="#1DF7EF"/>
    </linearGradient>
    </defs>
    </svg>
    """
}
