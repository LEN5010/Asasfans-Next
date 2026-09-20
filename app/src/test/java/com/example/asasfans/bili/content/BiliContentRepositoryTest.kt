package com.example.asasfans.bili.content

import android.app.Application
import com.example.asasfans.bili.account.BiliCredentials
import com.example.asasfans.bili.network.*
import com.example.asasfans.core.model.*
import com.example.asasfans.core.network.JsonHttpClient
import com.example.asasfans.core.network.JsonResponse
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class BiliContentRepositoryTest {
    private class Transport : BiliTransport {
        val requests = mutableListOf<BiliRequest>()
        var response = fixture("detail")
        override suspend fun get(request: BiliRequest): JsonResponse {
            requests += request
            val body = when (request.url.encodedPath) {
                "/x/web-interface/nav" -> fixture("nav-anonymous")
                "/x/frontend/finger/spi" -> Json.parseToJsonElement("""{"code":0,"data":{"b_3":"fixture-device"}}""") as JsonObject
                else -> response
            }
            if (request.requireBusinessCode) JsonHttpClient.checkBusinessCode(body)
            return JsonResponse(body)
        }
        val repository = BiliContentRepository(BiliGateway(this) { BiliCredentials.fromWebCookies("SESSDATA=fixture-session") }) { 100 }
    }

    @Test fun creatorUsesSignedReadOnlySpaceEndpointAndCurrentCredentialSnapshot() = runTest {
        val transport = Transport().apply {
            response = Json.parseToJsonElement("""{"code":0,"data":{"mid":42,"name":"合成 UP","sign":"简介","face":""}}""") as JsonObject
        }
        assertEquals("合成 UP", transport.repository.creator(42).creator.name)
        val request = transport.requests.last()
        assertEquals("/x/space/wbi/acc/info", request.url.encodedPath)
        assertEquals("42", request.url.queryParameter("mid"))
        assertEquals(32, request.url.queryParameter("w_rid")!!.length)
        assertEquals("https://space.bilibili.com/42", request.referer)
        assertTrue(request.cookies.contains("SESSDATA=fixture-session"))
        assertNull(request.url.queryParameter("csrf"))
    }

    @Test fun invalidCreatorNeverMakesANetworkRequest() = runTest {
        val transport = Transport()
        try { transport.repository.creator(0); fail("invalid creator") }
        catch (_: AppFailure.InvalidInput) { }
        assertTrue(transport.requests.isEmpty())
    }

    @Test fun searchSignsRealKeywordAndAddsEphemeralDeviceCookie() = runTest {
        val transport = Transport().apply { response = fixture("search") }
        val query = QuerySpec(keyword = "嘉然 & 歌曲", order = VideoOrder.POPULAR)
        val results = transport.repository.search(query, 1)
        assertEquals(1, results.videos.size)
        val request = transport.requests.last()
        assertEquals("/x/web-interface/wbi/search/type", request.url.encodedPath)
        assertEquals("嘉然 & 歌曲", request.url.queryParameter("keyword"))
        assertEquals("click", request.url.queryParameter("order"))
        assertEquals("video", request.url.queryParameter("search_type"))
        assertEquals(32, request.url.queryParameter("w_rid")!!.length)
        assertTrue(request.cookies.contains("SESSDATA=fixture-session"))
        assertTrue(request.cookies.contains("buvid3=fixture-device"))
        assertTrue(transport.requests.dropLast(1).all { it.cookies.isEmpty() })
        assertFalse(request.toString().contains("fixture"))
    }

    @Test fun signingAndDeviceInitializationAreSingleFlight() = runTest {
        val transport = Transport().apply { response = fixture("search") }
        val query = QuerySpec(keyword = "合成")
        val first = async { transport.repository.search(query, 1) }
        val second = async { transport.repository.search(query, 1) }
        first.await(); second.await()
        assertEquals(1, transport.requests.count { it.url.encodedPath.endsWith("/nav") })
        assertEquals(1, transport.requests.count { it.url.encodedPath.endsWith("/spi") })
    }

    @Test fun unsupportedSearchConstraintsFailBeforeAnyNetworkCall() = runTest {
        val transport = Transport()
        for (query in listOf(QuerySpec(keyword = "x", days = 7), QuerySpec(keyword = "x", maxDurationMs = 60_000),
            QuerySpec(keyword = "x", tags = listOf("嘉然")), QuerySpec(keyword = "x", creatorId = "42"))) {
            try { transport.repository.search(query, 1); fail("must reject") }
            catch (_: AppFailure.InvalidInput) { }
        }
        assertTrue(transport.requests.isEmpty())
    }

    @Test fun voucherSuccessCodeIsRiskControlNotEmptyData() = runTest {
        val transport = Transport().apply {
            response = Json.parseToJsonElement("""{"code":0,"data":{"v_voucher":"fixture-challenge"}}""") as JsonObject
        }
        try { transport.repository.detail("BV1xx411c7mD"); fail("must fail") }
        catch (error: AppFailure.RiskControl) { assertEquals(0, error.code) }
    }

    @Test fun archiveRiskFailureStaysVisibleRatherThanBecomingEmptySubscriptionFeed() = runTest {
        val transport = Transport().apply { response = Json.parseToJsonElement("""{"code":-352}""") as JsonObject }
        try { transport.repository.archive(42, 1); fail("must fail") }
        catch (_: AppFailure.RiskControl) { }
        assertEquals("42", transport.requests.last().url.queryParameter("mid"))
    }

    @Test fun closedCommentsAreASeparateStateAndNeverUseWriteEndpoints() = runTest {
        val transport = Transport().apply { response = Json.parseToJsonElement("""{"code":12002}""") as JsonObject }
        try { transport.repository.comments(123, 1); fail("must fail") }
        catch (_: AppFailure.CommentsClosed) { }
        val request = transport.requests.single()
        assertEquals("/x/v2/reply", request.url.encodedPath)
        assertEquals("1", request.url.queryParameter("type"))
        assertEquals("123", request.url.queryParameter("oid"))
        assertNull(request.url.queryParameter("csrf"))
    }

    @Test fun dashAndMp4RequestsPreservePartIdentityAndReferer() = runTest {
        val transport = Transport().apply { response = fixture("dash") }
        transport.repository.playback("BV1xx411c7mD", 201, 64)
        var request = transport.requests.last()
        assertEquals("201", request.url.queryParameter("cid"))
        assertEquals("16", request.url.queryParameter("fnval"))
        assertEquals("view-card", request.url.queryParameter("gaia_source"))
        assertEquals("64", request.url.queryParameter("qn"))
        assertEquals("https://www.bilibili.com/video/BV1xx411c7mD", request.referer)
        transport.response = fixture("mp4")
        val result = transport.repository.playback("BV1xx411c7mD", 201, mp4 = true)
        request = transport.requests.last()
        assertEquals("1", request.url.queryParameter("fnval"))
        assertEquals("html5", request.url.queryParameter("platform"))
        assertEquals(32, result.returnedQuality)
    }
}
