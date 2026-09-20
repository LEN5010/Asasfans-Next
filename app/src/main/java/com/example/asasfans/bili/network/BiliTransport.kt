package com.example.asasfans.bili.network

import com.example.asasfans.core.network.JsonHttpClient
import com.example.asasfans.core.network.JsonResponse
import okhttp3.HttpUrl

class BiliRequest(
    val url: HttpUrl,
    val cookies: String = "",
    val requireBusinessCode: Boolean = true,
    val referer: String = "https://www.bilibili.com/",
) {
    override fun toString() = "BiliRequest(<redacted>)"
}

fun interface BiliTransport { suspend fun get(request: BiliRequest): JsonResponse }

class HttpBiliTransport(private val http: JsonHttpClient) : BiliTransport {
    override suspend fun get(request: BiliRequest) = http.getResponse(
        request.url, bili = true, requireBusinessCode = request.requireBusinessCode,
        cookies = request.cookies, referer = request.referer,
    )
}
