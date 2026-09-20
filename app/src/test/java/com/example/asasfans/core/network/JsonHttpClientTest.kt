package com.example.asasfans.core.network

import com.example.asasfans.core.model.AppFailure
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import okhttp3.OkHttpClient
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.SocketPolicy
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class JsonHttpClientTest {
    private lateinit var server: MockWebServer
    @Before fun setUp() { server = MockWebServer(); server.start() }
    @After fun tearDown() { server.shutdown() }

    @Test fun jsonKeyOrderingDoesNotDetermineSuccess() = runBlocking {
        server.enqueue(MockResponse().setBody("{\"data\":{},\"message\":\"ok\",\"code\":0}"))
        assertNotNull(JsonHttpClient(OkHttpClient()).get(server.url("/"))["data"])
    }
    @Test fun untrustedOriginsNeverReceiveCredentialsEvenWhenBiliModeIsRequested() = runBlocking {
        server.enqueue(MockResponse().setBody("{\"code\":0}"))
        JsonHttpClient(OkHttpClient()) { "SESSDATA=fixture-only" }.get(server.url("/"), bili = true)
        assertNull(server.takeRequest().getHeader("Cookie"))
        assertTrue(CredentialPolicy.maySend("https://api.bilibili.com/x".toHttpUrl()))
        assertFalse(CredentialPolicy.maySend("https://api.bilibili.com.evil.example/x".toHttpUrl()))
        assertFalse(CredentialPolicy.maySend("http://api.bilibili.com/x".toHttpUrl()))
        assertFalse(CredentialPolicy.maySend("https://api.bilibili.com:8443/x".toHttpUrl()))
    }
    @Test fun malformedBusinessResponseIsNotAnEmptySuccess() = runBlocking {
        server.enqueue(MockResponse().setBody("{\"message\":\"ok\"}"))
        try { JsonHttpClient(OkHttpClient()).get(server.url("/")); fail("must fail") }
        catch (_: AppFailure.InvalidResponse) { }
    }
    @Test fun riskResponseDoesNotExposeServerMessage() = runBlocking {
        server.enqueue(MockResponse().setBody("{\"code\":-352,\"message\":\"private server payload\"}"))
        try { JsonHttpClient(OkHttpClient()).get(server.url("/")); fail("must fail") }
        catch (error: AppFailure.RiskControl) { assertFalse(error.userMessage.contains("private")) }
    }
    @Test fun redirectsAreNotFollowed() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(302).setHeader("Location", server.url("/other")))
        try { JsonHttpClient(OkHttpClient()).get(server.url("/")); fail("must fail") }
        catch (error: AppFailure.Http) { assertEquals(302, error.status) }
        assertEquals(1, server.requestCount)
    }
    @Test fun cancellationCancelsTheUnderlyingCall() = runBlocking {
        server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
        val client = OkHttpClient()
        val result = async { JsonHttpClient(client).get(server.url("/")) }
        withTimeout(5000) { while (server.requestCount == 0) kotlinx.coroutines.delay(10) }
        result.cancel()
        result.join()
        withTimeout(5000) { while (client.dispatcher.runningCallsCount() != 0) kotlinx.coroutines.delay(10) }
        assertTrue(result.isCancelled)
    }

    @Test fun untrustedCookieResponsesAreNotAvailableForLoginInstallation() = runBlocking {
        server.enqueue(MockResponse().setBody("{\"code\":0}").addHeader("Set-Cookie", "SESSDATA=fixture; Path=/"))
        val response = JsonHttpClient(OkHttpClient()).getResponse(server.url("/"), bili = true, cookies = "SESSDATA=fixture")
        assertTrue(response.setCookies.isEmpty())
        assertNull(server.takeRequest().getHeader("Cookie"))
        assertEquals("JsonResponse(<redacted>)", response.toString())
    }

    @Test fun nonPrimitiveBusinessCodeIsAControlledInvalidResponse() = runBlocking {
        server.enqueue(MockResponse().setBody("{\"code\":{},\"data\":{}}"))
        try { JsonHttpClient(OkHttpClient()).get(server.url("/")); fail("must fail") }
        catch (_: AppFailure.InvalidResponse) { }
    }
}
