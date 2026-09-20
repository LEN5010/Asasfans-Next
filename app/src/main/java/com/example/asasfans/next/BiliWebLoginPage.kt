package com.example.asasfans.next

import android.annotation.SuppressLint
import android.net.http.SslError
import android.webkit.*
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import com.example.asasfans.bili.account.BiliWebLoginPolicy
import com.example.asasfans.bili.account.LoginTicket
import com.example.asasfans.core.model.AppFailure
import kotlinx.coroutines.*

@SuppressLint("SetJavaScriptEnabled")
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BiliWebLoginPage(vm: MainViewModel, exit: () -> Unit) {
    val graph = vm.graph
    val owner = LocalLifecycleOwner.current
    val scope = rememberCoroutineScope()
    val leave by rememberUpdatedState(exit)
    var web by remember { mutableStateOf<WebView?>(null) }
    var ticket by remember { mutableStateOf<LoginTicket?>(null) }
    var ready by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var progress by remember { mutableIntStateOf(0) }
    var attempt by remember { mutableIntStateOf(0) }
    var error by remember { mutableStateOf<String?>(null) }
    var lastTried by remember { mutableStateOf<String?>(null) }

    fun complete(manual: Boolean) {
        val current = ticket ?: return
        if (busy || !ready || web?.url?.let(BiliWebLoginPolicy::allowsPage) != true) return
        val header = CookieManager.getInstance().getCookie(BiliWebLoginPolicy.COOKIE_ORIGIN).orEmpty()
        if (!BiliWebLoginPolicy.hasSession(header)) {
            if (manual) error = "请先在网页中完成登录"
            return
        }
        if (!manual && header == lastTried) return
        lastTried = header
        busy = true
        error = null
        scope.launch {
            try {
                if (graph.account.verifyAndAcceptWebCookies(current, header)) {
                    leave()
                } else {
                    ready = false
                    error = "此次登录已取消，请重新打开"
                }
            } catch (cancelled: CancellationException) { throw cancelled }
            catch (failure: AppFailure) { error = failure.userMessage }
            catch (_: Exception) { error = "登录验证暂未完成，请重试" }
            finally { busy = false }
        }
    }

    LaunchedEffect(attempt) {
        var session: Long? = null
        var login: LoginTicket? = null
        try {
            error = null
            session = graph.webLoginCookies.beginSession()
            login = graph.account.beginWebLogin()
            ticket = login
            ready = true
            awaitCancellation()
        } catch (cancelled: CancellationException) { throw cancelled }
        catch (failure: AppFailure) { error = failure.userMessage }
        finally {
            ready = false
            ticket = null
            web?.stopLoading()
            lastTried = null
            withContext(NonCancellable) {
                login?.let { graph.account.cancelLogin(it) }
                try { session?.let { graph.webLoginCookies.endSession(it) } }
                catch (_: AppFailure) { vm.notify("网页登录清理未完成，请重新打开登录页") }
            }
        }
    }
    val checkLogin by rememberUpdatedState<() -> Unit>({ complete(false) })
    LaunchedEffect(owner, ready) {
        if (ready) owner.lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            while (isActive) { checkLogin(); delay(1500) }
        }
    }
    DisposableEffect(owner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> web?.onResume()
                Lifecycle.Event.ON_PAUSE -> web?.onPause()
                else -> Unit
            }
        }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }
    BackHandler { exit() }
    Column(Modifier.fillMaxSize().imePadding()) {
        TopAppBar(title = { Text("B 站网页登录") }, navigationIcon = {
            IconButton(onClick = exit) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "返回") }
        }, actions = {
            IconButton(onClick = { error = null; web?.reload() }, enabled = ready && !busy) { Icon(Icons.Outlined.Refresh, "刷新网页") }
            TextButton(onClick = { complete(true) }, enabled = ready && !busy) { Text(if (busy) "验证中…" else "完成登录") }
        })
        if (busy || (error == null && (!ready || progress < 100))) LinearProgressIndicator(Modifier.fillMaxWidth())
        error?.let { message ->
            MessagePanel("登录尚未完成", message, "重试") {
                if (ready) { error = null; lastTried = null; web?.reload() } else attempt++
            }
        }
        if (ready) AndroidView(modifier = Modifier.weight(1f).fillMaxWidth(), factory = { context ->
            WebView(context).apply {
                web = this
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.allowFileAccess = false
                settings.allowContentAccess = false
                settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                settings.setSupportMultipleWindows(false)
                settings.javaScriptCanOpenWindowsAutomatically = false
                settings.useWideViewPort = true
                settings.loadWithOverviewMode = true
                CookieManager.getInstance().setAcceptThirdPartyCookies(this, false)
                webChromeClient = object : WebChromeClient() {
                    override fun onProgressChanged(view: WebView, newProgress: Int) { progress = newProgress }
                }
                webViewClient = object : WebViewClient() {
                    override fun onPageStarted(view: WebView, url: String, favicon: android.graphics.Bitmap?) {
                        if (!BiliWebLoginPolicy.allowsPage(url)) {
                            view.stopLoading()
                            error = "请在当前官方登录页完成登录"
                        }
                    }
                    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                        val allowed = if (request.isForMainFrame) BiliWebLoginPolicy.allowsPage(request.url.toString())
                            else request.url.scheme == "https"
                        if (!allowed && request.isForMainFrame) error = "请在当前官方登录页完成登录"
                        return !allowed
                    }
                    override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, failure: SslError) {
                        handler.cancel()
                        error = "无法安全连接登录页面，请稍后重试"
                    }
                    override fun onReceivedError(view: WebView, request: WebResourceRequest, failure: WebResourceError) {
                        if (request.isForMainFrame) error = "登录页面暂时无法连接"
                    }
                    override fun onReceivedHttpError(view: WebView, request: WebResourceRequest, response: WebResourceResponse) {
                        if (request.isForMainFrame) error = "登录页面暂时不可用"
                    }
                }
                loadUrl(BiliWebLoginPolicy.LOGIN_URL)
            }
        }, onReset = null, onRelease = { view ->
            view.stopLoading()
            view.webChromeClient = null
            view.webViewClient = WebViewClient()
            view.removeAllViews()
            view.destroy()
            if (web === view) web = null
        })
    }
}
