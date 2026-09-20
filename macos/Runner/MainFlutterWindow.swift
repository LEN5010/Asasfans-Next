import Cocoa
import FlutterMacOS
import WebKit
import webview_flutter_wkwebview

class MainFlutterWindow: NSWindow {
  private var loginCookies: FlutterMethodChannel?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    loginCookies = FlutterMethodChannel(name: "asasfans.next/bilibili_login_cookies", binaryMessenger: flutterViewController.engine.binaryMessenger)
    loginCookies?.setMethodCallHandler { [weak flutterViewController] call, result in
      guard let registry = flutterViewController else {
        result(FlutterError(code: "LOGIN_COOKIES", message: "Login browser unavailable", details: nil))
        return
      }
      BiliLoginCookieBridge.handle(call, registry: registry, result: result)
    }

    super.awakeFromNib()
  }
}

private enum BiliLoginCookieBridge {
  static let names: Set<String> = ["SESSDATA", "bili_jct", "DedeUserID", "DedeUserID__ckMd5", "sid"]
  static func handle(_ call: FlutterMethodCall, registry: FlutterPluginRegistry, result: @escaping FlutterResult) {
    let store = WKWebsiteDataStore.default()
    switch call.method {
    case "available":
      result(true)
    case "stop":
      guard let args = call.arguments as? [String: Any],
            let id = args["webViewId"] as? NSNumber,
            registry.valuePublished(byPlugin: "WebViewFlutterPlugin") is WebViewFlutterPlugin,
            let view = FWFWebViewFlutterWKWebViewExternalAPI.webView(forIdentifier: id.int64Value, withPluginRegistry: registry) else {
        result(FlutterError(code: "LOGIN_COOKIES", message: "Login browser unavailable", details: nil))
        return
      }
      view.stopLoading()
      result(true)
    case "read":
      store.httpCookieStore.getAllCookies { cookies in
        let values = cookies.filter { cookie in
          let domain = cookie.domain.lowercased()
          return names.contains(cookie.name) && [".bilibili.com", "bilibili.com", "api.bilibili.com"].contains(domain)
            && cookie.path == "/" && (cookie.expiresDate == nil || cookie.expiresDate! > Date())
        }.map { ["name": $0.name, "value": $0.value] }
        result(values)
      }
    case "clear":
      store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date.distantPast) {
        store.httpCookieStore.getAllCookies { cookies in
          if cookies.isEmpty { result(true) }
          else { result(FlutterError(code: "LOGIN_COOKIES", message: "Cookie cleanup incomplete", details: nil)) }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
