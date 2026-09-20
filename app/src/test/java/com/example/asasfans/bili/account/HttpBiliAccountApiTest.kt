package com.example.asasfans.bili.account

import com.example.asasfans.bili.network.HttpBiliTransport
import com.example.asasfans.core.model.AppFailure
import com.example.asasfans.core.network.JsonHttpClient
import kotlinx.coroutines.test.runTest
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.*
import org.junit.Test

class HttpBiliAccountApiTest {
    private var body = ""
    private var headers = emptyList<String>()
    private val requests = mutableListOf<Request>()
    private val http = JsonHttpClient(OkHttpClient.Builder().addInterceptor { chain ->
        requests += chain.request()
        Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1).code(200).message("fixture")
            .body(body.toResponseBody("application/json".toMediaType()))
            .apply { headers.forEach { addHeader("Set-Cookie", it) } }.build()
    }.build()) { "SESSDATA=must-not-accidentally-use-global-session" }
    private val api = HttpBiliAccountApi(HttpBiliTransport(http)) { 123 }

    @Test fun navAnonymousIsRecognizedWithoutTreatingMalformedSuccessAsLogout() = runTest {
        body = """{"code":-101,"data":{"isLogin":false}}"""
        assertNull(api.profile(BiliCredentials.Empty))
        assertNull(requests.last().header("Cookie"))
        body = """{"code":0,"data":{}}"""
        try { api.profile(BiliCredentials.Empty); fail("must fail") }
        catch (_: AppFailure.InvalidResponse) { }
    }

    @Test fun navUsesExplicitCredentialSnapshotAndIgnoresUnknownFields() = runTest {
        body = """{"data":{"isLogin":true,"mid":123,"uname":"合成账号","face":"//i0.hdslb.com/fixture","newField":true},"code":0}"""
        val profile = api.profile(BiliCredentials.fromWebCookies("SESSDATA=fixture-only"))!!
        assertEquals(123L, profile.mid)
        assertEquals(123L, profile.verifiedAtMs)
        assertEquals("SESSDATA=fixture-only", requests.last().header("Cookie"))
    }

    @Test fun qrGenerationValidatesOriginAndMatchingKey() = runTest {
        val key = "a".repeat(32)
        body = """{"code":0,"data":{"qrcode_key":"$key","url":"https://passport.bilibili.com/h5-app/passport/login/scan?qrcode_key=$key"}}"""
        assertEquals(key, api.generateQr().key)
        assertNull(requests.last().header("Cookie"))
        body = body.replace("passport.bilibili.com", "passport.bilibili.com.evil.example")
        try { api.generateQr(); fail("must fail") } catch (_: AppFailure.InvalidResponse) { }
    }

    @Test fun qrStatusCodesAndSuccessfulSetCookieAreDecodedWithoutCrossDomainHop() = runTest {
        for ((code, expected) in listOf(86101 to QrStatus.WAITING, 86090 to QrStatus.SCANNED, 86038 to QrStatus.EXPIRED)) {
            body = """{"code":0,"data":{"code":$code}}"""
            assertEquals(expected, api.pollQr("a".repeat(32)).status)
        }
        body = """{"code":0,"data":{"code":0,"refresh_token":"fixture-refresh","url":"https://passport.biligame.com/never-follow-this"}}"""
        headers = listOf("SESSDATA=fixture-session; Domain=bilibili.com; Path=/; Secure")
        val result = api.pollQr("a".repeat(32))
        assertEquals(QrStatus.SUCCESS, result.status)
        assertEquals("SESSDATA=fixture-session", result.credentials!!.cookieHeader())
        assertEquals(4, requests.size)
        assertTrue(requests.all { it.url.host == "passport.bilibili.com" && it.header("Cookie") == null })
        assertFalse(result.toString().contains("fixture"))
    }

    @Test fun successfulPollWithoutSessionCookieDoesNotCountAsLogin() = runTest {
        body = """{"code":0,"data":{"code":0}}"""
        try { api.pollQr("a".repeat(32)); fail("must fail") } catch (_: AppFailure.InvalidResponse) { }
    }

    @Test fun qrAcceptsCurrentOfficialAccountHostWithoutSendingCookiesThere() = runTest {
        val key = "a".repeat(32)
        body = """{"code":0,"data":{"qrcode_key":"$key","url":"https://account.bilibili.com/h5/account-h5/auth/scan-web?navhide=1&callback=&qrcode_key=$key"}}"""
        val qr = api.generateQr()
        assertEquals(key, qr.key)
        assertTrue(qr.url.startsWith("https://account.bilibili.com/"))
        assertEquals("passport.bilibili.com", requests.single().url.host)
        assertNull(requests.single().header("Cookie"))
        assertFalse(qr.toString().contains(key))
    }

    @Test fun qrRejectsSpoofedHostsWrongRoutesDuplicateKeysAndMismatches() = runTest {
        val key = "a".repeat(32)
        val valid = "https://account.bilibili.com/h5/account-h5/auth/scan-web?qrcode_key=$key"
        for (url in listOf(
            valid.replace("account.bilibili.com", "account.bilibili.com.evil.example"),
            valid.replace("https:", "http:"), valid.replace("/scan-web", "/unrelated"),
            valid.replace(key, "b".repeat(32)), "$valid&qrcode_key=$key", "$valid#fragment",
            valid.replace("account.bilibili.com", "user@account.bilibili.com"),
        )) {
            body = """{"code":0,"data":{"qrcode_key":"$key","url":"$url"}}"""
            try { api.generateQr(); fail("untrusted QR address must be rejected") } catch (_: AppFailure.InvalidResponse) { }
        }
    }

}
