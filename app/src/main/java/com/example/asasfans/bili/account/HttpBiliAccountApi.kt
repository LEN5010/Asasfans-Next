package com.example.asasfans.bili.account

import com.example.asasfans.bili.network.*
import com.example.asasfans.core.model.AppFailure
import com.example.asasfans.core.network.JsonHttpClient
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

class HttpBiliAccountApi(
    private val transport: BiliTransport,
    private val nowMs: () -> Long = System::currentTimeMillis,
) : BiliAccountApi {
    override suspend fun profile(credentials: BiliCredentials): BiliProfile? {
        val root = transport.get(BiliRequest(NAV.toHttpUrl(), credentials.cookieHeader(), false)).body
        val code = JsonHttpClient.checkBusinessCode(root, setOf(0, -101))
        if (code == -101) return null
        val data = root.data()
        return when (data.boolean("isLogin")) {
            false -> null
            true -> BiliProfile(data.positive("mid"), data.text("uname"), httpsUrl(data.text("face")), nowMs())
            null -> throw AppFailure.InvalidResponse()
        }
    }

    override suspend fun generateQr(): GeneratedQr {
        val data = transport.get(BiliRequest("$QR_BASE/generate".toHttpUrl())).body.data()
        val key = data.text("qrcode_key")
        val url = data.text("url").toHttpUrlOrNull() ?: throw AppFailure.InvalidResponse()
        if (!key.matches(Regex("[a-zA-Z0-9]{32}")) || !url.isHttps || url.host != "passport.bilibili.com" ||
            url.port != 443 || url.username.isNotEmpty() || url.password.isNotEmpty() ||
            url.queryParameter("qrcode_key") != key) throw AppFailure.InvalidResponse()
        return GeneratedQr(key, url.toString())
    }

    override suspend fun pollQr(key: String): PolledQr {
        if (!key.matches(Regex("[a-zA-Z0-9]{32}"))) throw AppFailure.InvalidInput("二维码已失效，请重新生成")
        val url = "$QR_BASE/poll".toHttpUrl().newBuilder().addQueryParameter("qrcode_key", key).build()
        val response = transport.get(BiliRequest(url))
        val data = response.body.data()
        return when (data.number("code")) {
            86101L -> PolledQr(QrStatus.WAITING)
            86090L -> PolledQr(QrStatus.SCANNED)
            86038L -> PolledQr(QrStatus.EXPIRED)
            0L -> PolledQr(QrStatus.SUCCESS,
                BiliCredentials.fromSetCookies(url, response.setCookies, data.text("refresh_token")))
            else -> throw AppFailure.InvalidResponse()
        }
    }

    companion object {
        internal const val NAV = "https://api.bilibili.com/x/web-interface/nav"
        private const val QR_BASE = "https://passport.bilibili.com/x/passport-login/web/qrcode"
    }
}
