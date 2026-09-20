package com.example.asasfans.bili.network

import com.example.asasfans.bili.account.BiliCredentials
import java.util.concurrent.TimeUnit
import okhttp3.*
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.*
import org.junit.Test

class BiliMediaDataSourceTest {
    @Test fun longMediaRequestsKeepReadTimeoutButNotApiWholeCallDeadline() {
        val source = BiliMediaDataSource(OkHttpClient.Builder().callTimeout(25, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS).build()) { BiliCredentials.Empty }
        val client = source.newMediaClient("BV1xx411c7mD")
        assertEquals(0, client.callTimeoutMillis)
        assertEquals(15_000, client.readTimeoutMillis)
        assertFalse(client.followSslRedirects)
        assertTrue(client.followRedirects)
    }

    @Test fun realRedirectHopsRemoveInheritedCookieAndPreserveRangeAndReferer() {
        MockWebServer().use { first -> MockWebServer().use { second ->
            first.start(); second.start()
            first.enqueue(MockResponse().setResponseCode(302).setHeader("Location", second.url("/segment")))
            second.enqueue(MockResponse().setBody("fixture-video"))
            val client = BiliMediaDataSource(OkHttpClient()) { BiliCredentials.fromWebCookies("SESSDATA=fixture-session") }
                .newMediaClient("BV1xx411c7mD")
            client.newCall(Request.Builder().url(first.url("/video"))
                .header("Cookie", "SESSDATA=inherited-must-remove").header("Range", "bytes=1-").build()).execute().use {
                assertEquals(200, it.code)
            }
            for (request in listOf(first.takeRequest(), second.takeRequest())) {
                assertNull(request.getHeader("Cookie"))
                assertEquals("bytes=1-", request.getHeader("Range"))
                assertEquals("https://www.bilibili.com/video/BV1xx411c7mD", request.getHeader("Referer"))
            }
        } }
    }
}
