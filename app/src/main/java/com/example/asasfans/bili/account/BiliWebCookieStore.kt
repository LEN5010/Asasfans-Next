package com.example.asasfans.bili.account

import android.webkit.CookieManager
import com.example.asasfans.core.model.AppFailure
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume

/** Clear only Bilibili login cookies; community sites keep their own cookies. */
class BiliWebCookieStore {
    private val mutex = Mutex()
    private var generation = 0L

    suspend fun beginSession(): Long = mutex.withLock {
        clearCookies()
        ++generation
    }

    suspend fun endSession(session: Long) = mutex.withLock {
        // Disposal of an old screen must not clear a newer login screen's cookies.
        if (session == generation) {
            ++generation
            clearCookies()
        }
    }

    suspend fun clear() = mutex.withLock {
        ++generation
        clearCookies()
    }

    private suspend fun clearCookies() = withContext(Dispatchers.Main.immediate) {
        try {
            withTimeout(5_000) { expireCookies() }
        } catch (_: TimeoutCancellationException) { throw AppFailure.LocalStorage() }
        catch (cancelled: CancellationException) { throw cancelled }
        catch (_: Exception) { throw AppFailure.LocalStorage() }
    }

    private suspend fun expireCookies() {
        val cookies = CookieManager.getInstance()
        cookies.setAcceptCookie(true)
        for ((origin, cookie) in BiliWebLoginPolicy.expiredCookies()) {
            suspendCancellableCoroutine<Unit> { continuation ->
                cookies.setCookie(origin, cookie) { if (continuation.isActive) continuation.resume(Unit) }
            }
        }
        cookies.flush()
        if (BiliWebLoginPolicy.cookieOrigins.any {
                BiliWebLoginPolicy.containsLoginCookies(cookies.getCookie(it).orEmpty())
            }) throw AppFailure.LocalStorage()
    }
}
