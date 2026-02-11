import UIKit
import Capacitor
import WebKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Called when the app was launched with a url. Feel free to add additional processing here,
        // but if you want the App API to support tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Called when the app was launched with an activity, including Universal Links.
        // Feel free to add additional processing here, but if you want the App API to support
        // tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

}

class AppBridgeViewController: CAPBridgeViewController {
    override open func viewDidLoad() {
        super.viewDidLoad()
        installNativeLogoHiding()
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
