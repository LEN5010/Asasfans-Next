package com.example.asasfans

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.webkit.CookieManager
import android.webkit.WebStorage
import android.webkit.WebView
import io.flutter.plugins.webviewflutter.WebViewFlutterPlugin
import android.os.Build
import android.os.Bundle

class MainActivity : FlutterActivity() {
    companion object {
        private var profileConfigured = false
        private var profileUnavailable = false
    }
    private var loginCookies: MethodChannel? = null

    /// The floating return entry, kept in its own module. It has no business
    /// with the login browser's cookie store, and the login channel has no
    /// business starting services.
    private var returnEntry: ReturnEntryBridge? = null
    private val navOrigin = "https://api.bilibili.com/x/web-interface/nav"
    private val allowedCookies = setOf("SESSDATA", "bili_jct", "DedeUserID", "DedeUserID__ckMd5", "sid")

    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= 28 && !profileConfigured && !profileUnavailable) {
            try {
                WebView.setDataDirectorySuffix("asasfans_flutter_bilibili")
                profileConfigured = true
            } catch (_: IllegalStateException) {
                profileUnavailable = true
            }
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        returnEntry = ReturnEntryBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        loginCookies = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "asasfans.next/bilibili_login_cookies").also { channel ->
            channel.setMethodCallHandler { call, result ->
                val available = !profileUnavailable && (Build.VERSION.SDK_INT >= 28 || packageName != "asasfans.next")
                if (call.method == "available") {
                    result.success(available)
                    return@setMethodCallHandler
                }
                // Never open the old production WebView store on API 24–27.
                // Development packages have an isolated application directory.
                if (!available) {
                    result.error("LOGIN_COOKIES", "Isolated login browser unavailable", null)
                    return@setMethodCallHandler
                }
                // This app's embedded browser store is reserved for Bilibili
                // login. Tools open externally and never share this WebView.
                val manager = CookieManager.getInstance()
                when (call.method) {
                    "stop" -> {
                        try {
                            val id = call.argument<Number>("webViewId")?.toLong()
                            val plugin = flutterEngine.plugins.get(WebViewFlutterPlugin::class.java) as? WebViewFlutterPlugin
                            val view = if (id == null) null else plugin?.instanceManager?.getInstance<WebView>(id)
                            if (view == null) {
                                result.error("LOGIN_COOKIES", "Login browser unavailable", null)
                            } else {
                                view.stopLoading()
                                result.success(true)
                            }
                        } catch (_: Exception) {
                            result.error("LOGIN_COOKIES", "Login browser stop failed", null)
                        }
                    }
                    "read" -> {
                        try {
                            val values = (manager.getCookie(navOrigin) ?: "").split(';').mapNotNull { part ->
                                val delimiter = part.indexOf('=')
                                if (delimiter < 1) return@mapNotNull null
                                val name = part.substring(0, delimiter).trim()
                                if (name !in allowedCookies) return@mapNotNull null
                                mapOf("name" to name, "value" to part.substring(delimiter + 1).trim())
                            }
                            result.success(values)
                        } catch (_: Exception) {
                            result.error("LOGIN_COOKIES", "Cookie access failed", null)
                        }
                    }
                    "clear" -> {
                        try {
                            manager.removeAllCookies {
                                try {
                                    manager.flush()
                                    WebStorage.getInstance().deleteAllData()
                                    if (!manager.hasCookies()) {
                                        WebStorage.getInstance().getOrigins { origins ->
                                            if (origins.isNullOrEmpty()) result.success(true)
                                            else result.error("LOGIN_COOKIES", "Browser storage cleanup incomplete", null)
                                        }
                                    } else result.error("LOGIN_COOKIES", "Cookie cleanup incomplete", null)
                                } catch (_: Exception) {
                                    result.error("LOGIN_COOKIES", "Cookie cleanup failed", null)
                                }
                            }
                        } catch (_: Exception) {
                            result.error("LOGIN_COOKIES", "Cookie cleanup failed", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        loginCookies?.setMethodCallHandler(null)
        loginCookies = null
        returnEntry?.dispose()
        returnEntry = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
