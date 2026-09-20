package com.example.asasfans.core.network

import com.example.asasfans.core.model.*
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.*
import org.junit.Test

class CommunityVideoSourceTest {
    @Test fun parsesUnknownStatisticsAndTagsWithoutInventingZeroes() {
        val body = """{"data":{"page":1,"numResults":21,"result":[
            {"bvid":"BV1MBeq6rEz2","title":"测试","mid":123,"duration":"42","pubdate":1700000000},
            {"bvid":"BV19zea6vEWM","title":"测试2","mid":456,"tag":"","like":0}
        ]},"code":0}"""
        val result = CommunityVideoSource.decodePage(Json.parseToJsonElement(body).jsonObject, 1)
        assertEquals(42_000L, result.videos[0].durationMs)
        assertEquals(1_700_000_000_000L, result.videos[0].publishedAtMs)
        assertNull(result.videos[0].tags)
        assertNull(result.videos[0].likes)
        assertEquals(emptyList<String>(), result.videos[1].tags)
        assertEquals(0L, result.videos[1].likes)
        assertTrue(result.hasMore)
    }

    @Test fun unsupportedTitleSearchFailsExplicitlyRatherThanReturningUnfilteredFeed() {
        val source = CommunityVideoSource(JsonHttpClient(OkHttpClient()))
        assertThrows(AppFailure.InvalidInput::class.java) { source.url(QuerySpec(keyword = "嘉然"), 1) }
        assertThrows(AppFailure.InvalidInput::class.java) { source.url(QuerySpec(tags = listOf("a~mid.123.OR")), 1) }
    }

    @Test fun relativeDatesAreResolvedAtRequestTimeAndPageIsIndependent() {
        var now = 1_700_000_000_000L
        val source = CommunityVideoSource(JsonHttpClient(OkHttpClient()), nowMs = { now })
        val query = QuerySpec(days = 3, tags = listOf("嘉然"))
        val first = source.url(query, 1)
        now += 86_400_000
        val second = source.url(query, 2)
        assertTrue(first.queryParameter("q")!!.contains("tag.嘉然.AND"))
        assertNotEquals(first.queryParameter("q"), second.queryParameter("q"))
        assertEquals("2", second.queryParameter("page"))
    }

    @Test fun requestUsesSharedClientAndStructuredQuery() = runBlocking {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setBody("""{"code":0,"data":{"page":1,"numResults":0,"result":[]}}"""))
            server.start()
            val page = CommunityVideoSource(JsonHttpClient(OkHttpClient()), server.url("/feed"))
                .load(QuerySpec(tags = listOf("嘉然")), 1)
            assertFalse(page.hasMore)
            assertEquals("tag.嘉然.AND", server.takeRequest().requestUrl!!.queryParameter("q"))
        }
    }
}
