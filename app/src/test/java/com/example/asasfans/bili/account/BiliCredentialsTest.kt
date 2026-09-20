package com.example.asasfans.bili.account

import com.example.asasfans.core.model.AppFailure
import okhttp3.HttpUrl.Companion.toHttpUrl
import org.junit.Assert.*
import org.junit.Test

class BiliCredentialsTest {
    private val origin = "https://passport.bilibili.com/x/passport-login/web/qrcode/poll".toHttpUrl()

    @Test fun onlyKnownCookiesAreAcceptedAndRefreshTokenIsNotSentAsCookie() {
        val credentials = BiliCredentials.fromSetCookies(origin, listOf(
            "SESSDATA=fixture=a; Domain=bilibili.com; Path=/; Secure; HttpOnly",
            "DedeUserID=123; Domain=bilibili.com; Path=/", "tracking=fixture; Path=/",
            "bili_jct=fixture-wrong-domain; Domain=evil.example; Path=/",
            "sid=fixture-expired; Max-Age=0; Path=/",
        ), "fixture-refresh")
        assertEquals("SESSDATA=fixture=a; DedeUserID=123", credentials.cookieHeader())
        assertFalse(credentials.toString().contains("fixture"))
        assertEquals("fixture-refresh", credentials.storedValues()["refresh_token"])
    }

    @Test fun webLoginDoesNotRetainFieldsFromPreviousLogin() {
        val credentials = BiliCredentials.fromWebCookies("SESSDATA=fixture-new; unknown=fixture; refresh_token=ignored")
        assertEquals(setOf("SESSDATA"), credentials.storedValues().keys)
    }

    @Test fun headerInjectionAndMissingSessionAreRejected() {
        for (value in listOf("SESSDATA=fixture\r\nX-Test: bad", "sid=fixture", "SESSDATA=", "SESSDATA=has space")) {
            try { BiliCredentials.fromWebCookies(value); fail("must reject") }
            catch (_: AppFailure.InvalidResponse) { }
        }
    }
}
