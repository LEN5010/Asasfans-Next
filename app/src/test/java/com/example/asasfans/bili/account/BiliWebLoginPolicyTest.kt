package com.example.asasfans.bili.account

import org.junit.Assert.*
import org.junit.Test

class BiliWebLoginPolicyTest {
    @Test fun onlyOfficialHttpsMainPagesAreAllowed() {
        assertTrue(BiliWebLoginPolicy.allowsPage(BiliWebLoginPolicy.LOGIN_URL))
        assertTrue(BiliWebLoginPolicy.allowsPage("https://account.bilibili.com/h5/account-h5/auth/login"))
        assertTrue(BiliWebLoginPolicy.allowsPage("https://www.bilibili.com/"))
        for (url in listOf("http://passport.bilibili.com/login", "https://passport.bilibili.com.evil.example/login",
            "https://evil.example/?next=https://passport.bilibili.com", "https://user@passport.bilibili.com/login",
            "https://passport.bilibili.com:8443/login", "javascript:alert(1)", "intent://login", "file:///login")) {
            assertFalse(BiliWebLoginPolicy.allowsPage(url))
        }
    }

    @Test fun sessionDetectionUsesExactCookieNamesAndNonemptyValues() {
        assertTrue(BiliWebLoginPolicy.hasSession("buvid3=fixture; SESSDATA=fixture-session; bili_jct=fixture"))
        assertFalse(BiliWebLoginPolicy.hasSession("NOT_SESSDATA=fixture"))
        assertFalse(BiliWebLoginPolicy.hasSession("SESSDATA=; bili_jct=fixture"))
    }

    @Test fun cookieDeletionIsScopedToLoginNamesAndBilibiliOrigins() {
        val plan = BiliWebLoginPolicy.expiredCookies()
        assertTrue(plan.isNotEmpty())
        for ((origin, cookie) in plan) {
            assertTrue(origin in BiliWebLoginPolicy.cookieOrigins)
            assertTrue(cookie.substringBefore('=') in BiliCredentials.COOKIE_NAMES)
            assertTrue(cookie.contains("Max-Age=0"))
            assertTrue(cookie.contains("Path=/"))
        }
        assertTrue(plan.any { it.second.contains("Domain=.bilibili.com") })
        assertFalse(plan.any { it.second.startsWith("buvid3=") })
        assertFalse(BiliWebLoginPolicy.containsLoginCookies("buvid3=fixture; community_preference=dark"))
        assertTrue(BiliWebLoginPolicy.containsLoginCookies("bili_jct=fixture"))
    }
}
