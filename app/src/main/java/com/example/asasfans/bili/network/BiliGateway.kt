package com.example.asasfans.bili.network

import com.example.asasfans.bili.WbiSigner
import com.example.asasfans.bili.account.BiliCredentials
import com.example.asasfans.bili.account.HttpBiliAccountApi
import com.example.asasfans.core.model.AppFailure
import com.example.asasfans.core.network.JsonHttpClient
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.JsonObject
import okhttp3.HttpUrl.Companion.toHttpUrl

/** Shared signing/device context only. It never updates account state based on a content request. */
class BiliGateway(
    private val transport: BiliTransport,
    private val credentials: suspend () -> BiliCredentials,
) {
    private val signer = WbiSigner()
    private val signingMutex = Mutex()
    private val deviceMutex = Mutex()
    private var buvid = ""

    suspend fun get(
        path: String,
        params: Map<String, String>,
        signed: Boolean = true,
        needsDeviceCookie: Boolean = false,
        referer: String = "https://www.bilibili.com/",
    ): JsonObject {
        require(path.startsWith("/x/") && !path.contains('?') && !path.contains('#'))
        val url = "https://api.bilibili.com$path".toHttpUrl().newBuilder()
        if (signed) url.encodedQuery(signedQuery(params))
        else params.forEach { (key, value) -> url.addQueryParameter(key, value) }
        val device = if (needsDeviceCookie) deviceCookie() else ""
        val cookie = listOf(credentials().cookieHeader(), device).filter(String::isNotEmpty).joinToString("; ")
        val root = transport.get(BiliRequest(url.build(), cookie, referer = referer)).body
        JsonHttpClient.checkBusinessCode(root)
        return root.data()
    }

    private suspend fun signedQuery(params: Map<String, String>): String = signingMutex.withLock {
        if (!signer.hasFreshKeys()) {
            // Keys are public and nav -101 still supplies them; no account credentials needed here.
            val root = transport.get(BiliRequest(HttpBiliAccountApi.NAV.toHttpUrl(), requireBusinessCode = false)).body
            JsonHttpClient.checkBusinessCode(root, setOf(0, -101))
            val keys = root.data().requireObject("wbi_img")
            val img = keys.text("img_url")
            val sub = keys.text("sub_url")
            val valid = listOf(img, sub).all { value ->
                value.substringBefore('?').substringBefore('#').substringAfterLast('/').substringBefore('.')
                    .matches(Regex("[a-fA-F0-9]{32}"))
            }
            if (!valid) throw AppFailure.InvalidResponse()
            signer.setKeys(img, sub)
        }
        // The tested legacy pure signer mutates its map; never mutate caller-owned query criteria.
        signer.signToQuery(params.toMutableMap())
    }

    private suspend fun deviceCookie(): String = deviceMutex.withLock {
        if (buvid.isEmpty()) {
            val data = transport.get(BiliRequest("https://api.bilibili.com/x/frontend/finger/spi".toHttpUrl())).body.data()
            val value = data.text("b_3")
            if (!value.matches(Regex("[a-zA-Z0-9_-]{1,256}"))) throw AppFailure.InvalidResponse()
            buvid = value
        }
        "buvid3=$buvid"
    }
}
