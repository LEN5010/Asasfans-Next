package com.example.asasfans.bili.network

import com.example.asasfans.bili.account.BiliCredentials
import okhttp3.Request
import org.junit.Assert.*
import org.junit.Test

class MediaCredentialPolicyTest {
    private val credentials = BiliCredentials.fromWebCookies("SESSDATA=fixture-media")

    @Test fun cookiesAreNeverCarriedToUntrustedRedirectTargets() {
        for (url in listOf("https://evil.example/video", "http://upos.bilivideo.com/video", "https://upos.bilivideo.com:8443/video",
            "https://upos.bilivideo.com.evil.example/video", "https://mirror.akamaized.net/video")) {
            val request = Request.Builder().url(url).header("Cookie", "inherited=must-remove")
                .header("Authorization", "Bearer must-remove").header("Range", "bytes=100-").build()
            val clean = MediaCredentialPolicy.apply(request, "BV1xx411c7mD", credentials)
            assertNull(clean.header("Cookie"))
            assertNull(clean.header("Authorization"))
            assertEquals("bytes=100-", clean.header("Range"))
            assertEquals("https://www.bilibili.com/video/BV1xx411c7mD", clean.header("Referer"))
        }
    }

    @Test fun trustedCdnUsesCurrentSessionAndLogoutRemovesPreviousHeaders() {
        val request = Request.Builder().url("https://upos.bilivideo.com/video").build()
        val signed = MediaCredentialPolicy.apply(request, "BV1xx411c7mD", credentials)
        assertEquals("SESSDATA=fixture-media", signed.header("Cookie"))
        val afterLogout = MediaCredentialPolicy.apply(signed, "BV1xx411c7mD", BiliCredentials.Empty)
        assertNull(afterLogout.header("Cookie"))
    }
}
