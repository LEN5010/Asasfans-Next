package com.example.asasfans.core.network

import com.example.asasfans.core.model.AppFailure
import java.io.IOException
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.intOrNull
import okhttp3.Call
import okhttp3.Callback
import okhttp3.CookieJar
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** Asynchronous API boundary. Credentials are scoped to exact trusted HTTPS origins. */
class JsonHttpClient(
    client: OkHttpClient,
    private val credentialHeader: () -> String = { "" },
) {
    // Prevent redirecting an authenticated API request to an arbitrary host.
    private val client = client.newBuilder().followRedirects(false).followSslRedirects(false)
        .cookieJar(CookieJar.NO_COOKIES).build()
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun get(url: HttpUrl, bili: Boolean = false, requireBusinessCode: Boolean = true): JsonObject =
        getResponse(url, bili, requireBusinessCode).body

    /** An explicit empty cookie header makes a request anonymous, even if a session exists. */
    suspend fun getResponse(
        url: HttpUrl,
        bili: Boolean = false,
        requireBusinessCode: Boolean = true,
        cookies: String? = null,
        referer: String = "https://www.bilibili.com/",
    ): JsonResponse {
        val builder = Request.Builder().url(url).header("User-Agent", USER_AGENT).header("Accept", "application/json")
        if (bili) {
            builder.header("Referer", referer)
            if (CredentialPolicy.maySend(url)) {
                (cookies ?: credentialHeader()).takeIf(String::isNotEmpty)?.let { builder.header("Cookie", it) }
            }
        }
        return execute(builder.build(), requireBusinessCode)
    }

    private suspend fun execute(request: Request, requireBusinessCode: Boolean): JsonResponse = suspendCancellableCoroutine { continuation ->
        val call = client.newCall(request)
        continuation.invokeOnCancellation { call.cancel() }
        call.enqueue(object : Callback {
            override fun onFailure(call: Call, error: IOException) {
                if (continuation.isActive) continuation.resumeWithException(AppFailure.Network())
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    if (!continuation.isActive) return
                    val result = try {
                        if (response.code == 412 || response.code == 429) throw AppFailure.RiskControl(response.code)
                        if (!response.isSuccessful) throw AppFailure.Http(response.code)
                        val body = response.body ?: throw AppFailure.InvalidResponse()
                        val source = body.source()
                        source.request(MAX_BODY_BYTES + 1)
                        if (source.buffer.size > MAX_BODY_BYTES) throw AppFailure.InvalidResponse()
                        val root = json.parseToJsonElement(source.readUtf8()) as? JsonObject ?: throw AppFailure.InvalidResponse()
                        if (requireBusinessCode) {
                            checkBusinessCode(root)
                        }
                        Result.success(JsonResponse(root, if (CredentialPolicy.maySend(request.url))
                            response.headers.values("Set-Cookie") else emptyList()))
                    } catch (error: AppFailure) {
                        Result.failure(error)
                    } catch (error: SerializationException) {
                        Result.failure(AppFailure.InvalidResponse())
                    } catch (error: IllegalArgumentException) {
                        Result.failure(AppFailure.InvalidResponse())
                    } catch (error: IOException) {
                        Result.failure(AppFailure.Network())
                    }
                    if (continuation.isActive) result.fold(continuation::resume, continuation::resumeWithException)
                }
            }
        })
    }

    companion object {
        const val USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        private const val MAX_BODY_BYTES = 4L * 1024 * 1024

        fun checkBusinessCode(root: JsonObject, allowed: Set<Int> = setOf(0)): Int {
            val code = (root["code"] as? kotlinx.serialization.json.JsonPrimitive)?.intOrNull
                ?: throw AppFailure.InvalidResponse()
            if (code in allowed) return code
            throw when (code) {
                -101 -> AppFailure.LoginRequired()
                -352, -412 -> AppFailure.RiskControl(code)
                -403, -404, 62002, 62004, 62012 -> AppFailure.Unavailable()
                else -> AppFailure.Business(code)
            }
        }
    }
}

/** Do not let data-class toString leak login response bodies, QR keys, or Set-Cookie. */
class JsonResponse(val body: JsonObject, val setCookies: List<String> = emptyList()) {
    override fun toString() = "JsonResponse(<redacted>)"
}

object CredentialPolicy {
    private val apiHosts = setOf("api.bilibili.com", "passport.bilibili.com", "api.live.bilibili.com")
    fun maySend(url: HttpUrl): Boolean = url.isHttps && url.port == 443 && url.host in apiHosts
}
