package com.example.asasfans.next

import android.annotation.SuppressLint
import android.webkit.*
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.core.net.toUri

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun WebPage(initialUrl: String, external: (String) -> Unit, exit: () -> Unit) {
    var web by remember { mutableStateOf<WebView?>(null) }
    var canBack by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var pending by remember { mutableStateOf<String?>(null) }
    val owner = LocalLifecycleOwner.current
    BackHandler(canBack) { web?.goBack() }
    DisposableEffect(Unit) { onDispose { web?.stopLoading(); web?.destroy(); web = null } }
    DisposableEffect(owner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_START) web?.onResume()
            if (event == Lifecycle.Event.ON_STOP) {
                web?.evaluateJavascript("document.querySelectorAll('audio,video').forEach(function(m){m.pause();});", null)
                web?.onPause()
            }
        }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }
    Column(Modifier.fillMaxSize()) {
        Row {
            TextButton(onClick = { if (web?.canGoBack() == true) web?.goBack() else exit() }) { Text("返回") }
            TextButton(onClick = { error = null; web?.reload() }) { Text("刷新") }
            TextButton(onClick = { external(web?.url ?: initialUrl) }) { Text("浏览器打开") }
        }
        error?.let { MessagePanel("网页加载失败", it, "重试") { error = null; web?.reload() } }
        AndroidView(modifier = Modifier.weight(1f).fillMaxWidth(), factory = { context ->
            WebView(context).apply {
                web = this
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.allowFileAccess = false
                settings.allowContentAccess = false
                settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                CookieManager.getInstance().setAcceptThirdPartyCookies(this, false)
                webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                        val scheme = request.url.scheme
                        if (scheme == "https" || scheme == "http") return false
                        if (request.hasGesture() && scheme !in listOf("file", "content", "javascript", "data", "intent")) pending = request.url.toString()
                        return true
                    }
                    override fun onPageFinished(view: WebView, url: String) { canBack = view.canGoBack() }
                    override fun onReceivedError(view: WebView, request: WebResourceRequest, failure: WebResourceError) {
                        if (request.isForMainFrame) error = "暂时无法连接此网站"
                    }
                }
                setDownloadListener { url, _, _, _, _ -> if (url.toUri().scheme in listOf("http", "https")) pending = url }
                if (initialUrl.toUri().scheme == "https") loadUrl(initialUrl) else error = "不支持此网页地址"
            }
        })
    }
    pending?.let { url -> AlertDialog(onDismissRequest = { pending = null }, title = { Text("打开外部应用？") }, text = { Text("前往其他应用打开链接？") },
        confirmButton = { TextButton(onClick = { pending = null; external(url) }) { Text("打开") } }, dismissButton = { TextButton(onClick = { pending = null }) { Text("取消") } }) }
}
