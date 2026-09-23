import Flutter
import UIKit
import WebKit
import webview_flutter_wkwebview

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var loginCookies: FlutterMethodChannel?
  private weak var loginRegistry: FlutterPluginRegistry?
  private var transparencyPreference: TransparencyPreferenceBridge?
  deinit { transparencyPreference?.dispose() }
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    transparencyPreference?.dispose()
    transparencyPreference = TransparencyPreferenceBridge(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
    loginRegistry = engineBridge.pluginRegistry
    // UIScene owns the window. Bind to the actual engine instead of relying on
    // window.rootViewController during process launch (before a scene exists).
    loginCookies?.setMethodCallHandler(nil)
    loginCookies = FlutterMethodChannel(
      name: "asasfans.next/bilibili_login_cookies",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    loginCookies?.setMethodCallHandler { [weak self] call, result in
      guard let registry = self?.loginRegistry else {
        result(FlutterError(code: "LOGIN_COOKIES", message: "Login browser unavailable", details: nil))
        return
      }
      BiliLoginCookieBridge.handle(call, registry: registry, result: result)
    }
  }
}

// UIScene-independent, engine-bound and read-only. Separate from high contrast.
private final class TransparencyPreferenceBridge: NSObject, FlutterStreamHandler {
  private let events: FlutterEventChannel
  private let state: FlutterMethodChannel
  private var observer: NSObjectProtocol?

  init(messenger: FlutterBinaryMessenger) {
    events = FlutterEventChannel(name: "asasfans.next/reduce_transparency", binaryMessenger: messenger)
    state = FlutterMethodChannel(name: "asasfans.next/reduce_transparency_state", binaryMessenger: messenger)
    super.init()
    state.setMethodCallHandler { call, result in
      if call.method == "read" {
        result(UIAccessibility.isReduceTransparencyEnabled)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    events.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    stopObserving()
    observer = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil, queue: .main
    ) { _ in events(UIAccessibility.isReduceTransparencyEnabled) }
    events(UIAccessibility.isReduceTransparencyEnabled)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopObserving()
    return nil
  }

  private func stopObserving() {
    if let observer = observer { NotificationCenter.default.removeObserver(observer) }
    observer = nil
  }

  func dispose() {
    stopObserving()
    events.setStreamHandler(nil)
    state.setMethodCallHandler(nil)
  }

  deinit { stopObserving() }
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
      // The default embedded store belongs exclusively to login, not tools.
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
