package com.example.asasfans.bili.network

import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.okhttp.OkHttpDataSource
import com.example.asasfans.bili.account.BiliCredentials
import com.example.asasfans.core.network.JsonHttpClient
import okhttp3.CookieJar
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/** Media3 headers are applied at EVERY network hop, including CDN redirects and range retries. */
@OptIn(UnstableApi::class)
class BiliMediaDataSource(
    private val client: OkHttpClient,
    private val credentials: () -> BiliCredentials,
) {
    fun factory(bvid: String): OkHttpDataSource.Factory {
        return OkHttpDataSource.Factory(newMediaClient(bvid))
            .setUserAgent(JsonHttpClient.USER_AGENT)
            .setDefaultRequestProperties(mapOf("Referer" to "https://www.bilibili.com/video/$bvid"))
    }

    internal fun newMediaClient(bvid: String): OkHttpClient {
        requireBvid(bvid)
        return client.newBuilder().cookieJar(CookieJar.NO_COOKIES)
            // A progressive video request can live for hours. Keep inactivity/connect timeouts,
            // but do not inherit the metadata API's 25-second whole-call deadline.
            .callTimeout(0, TimeUnit.MILLISECONDS)
            .followRedirects(true).followSslRedirects(false)
            .addNetworkInterceptor { chain ->
                chain.proceed(MediaCredentialPolicy.apply(chain.request(), bvid, credentials()))
            }.build()
    }
}

internal object MediaCredentialPolicy {
    private val domains = setOf("bilivideo.com", "bilivideo.cn", "bilibili.com")
    fun maySend(url: HttpUrl) = url.isHttps && url.port == 443 && domains.any { url.host == it || url.host.endsWith(".$it") }
    fun apply(request: Request, bvid: String, credentials: BiliCredentials): Request = request.newBuilder()
        .removeHeader("Cookie").removeHeader("Authorization")
        .header("User-Agent", JsonHttpClient.USER_AGENT)
        .header("Referer", "https://www.bilibili.com/video/$bvid")
        .apply {
            if (maySend(request.url)) credentials.cookieHeader().takeIf(String::isNotEmpty)?.let { header("Cookie", it) }
        }.build()
}
