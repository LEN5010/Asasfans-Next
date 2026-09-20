package com.example.asasfans.bili.account

import com.example.asasfans.core.model.AppFailure
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/** No Activity/executor ownership. Late QR, WebView and nav responses cannot resurrect a logout. */
class BiliAccountRepository(
    private val vault: BiliCredentialVault,
    private val api: BiliAccountApi,
    private val clearWebSession: suspend () -> Unit = {},
    private val nowMs: () -> Long = System::currentTimeMillis,
) {
    private val mutex = Mutex()
    private var loaded = false
    private var generation = 0L
    private var attempt = 0L
    private var checkSequence = 0L
    @Volatile private var credentials = BiliCredentials.Empty
    private val mutableState = MutableStateFlow(AccountState())
    val state = mutableState.asStateFlow()

    /** Nonblocking snapshot for media network threads; initialize via requestCredentials first. */
    fun currentCredentials(): BiliCredentials = credentials

    suspend fun initialize() = mutex.withLock { readIfNeeded() }

    /** Storage failure degrades to anonymous content access, not an application startup failure. */
    suspend fun requestCredentials(): BiliCredentials = mutex.withLock {
        readIfNeeded()
        credentials
    }

    suspend fun retryStorage() = mutex.withLock {
        if (mutableState.value.status == AccountStatus.LOGOUT_PENDING) {
            clearCredentials()
        } else if (mutableState.value.status == AccountStatus.STORAGE_ERROR) {
            loaded = false
            readIfNeeded()
        }
    }

    suspend fun refresh() {
        val snapshot = mutex.withLock {
            readIfNeeded()
            if (mutableState.value.status in setOf(AccountStatus.STORAGE_ERROR, AccountStatus.LOGOUT_PENDING)) return
            mutableState.value = mutableState.value.copy(checking = true, failure = null)
            CheckSnapshot(generation, ++checkSequence, credentials)
        }
        try {
            val profile = api.profile(snapshot.credentials)
            mutex.withLock {
                if (!isCurrent(snapshot)) return
                mutableState.value = if (profile != null && snapshot.credentials.hasSession) {
                    AccountState(AccountStatus.SIGNED_IN, profile)
                } else AccountState(if (snapshot.credentials.hasSession) AccountStatus.EXPIRED else AccountStatus.SIGNED_OUT)
            }
        } catch (error: CancellationException) {
            throw error
        } catch (error: AppFailure) {
            mutex.withLock {
                if (isCurrent(snapshot)) mutableState.value = mutableState.value.copy(
                    status = if (snapshot.credentials.hasSession) AccountStatus.UNVERIFIED else AccountStatus.SIGNED_OUT,
                    checking = false, failure = error,
                )
            }
        } finally {
            withContext(NonCancellable) {
                mutex.withLock {
                    if (isCurrent(snapshot)) mutableState.value = mutableState.value.copy(checking = false)
                }
            }
        }
    }

    suspend fun beginWebLogin(): LoginTicket = mutex.withLock {
        readIfNeeded()
        if (mutableState.value.status == AccountStatus.LOGOUT_PENDING) throw AppFailure.LocalStorage()
        LoginTicket(generation, ++attempt)
    }

    suspend fun createQr(): LoginQr? {
        val ticket = beginWebLogin()
        val startedAt = nowMs()
        val qr = try { api.generateQr() } catch (error: AppFailure) {
            mutex.withLock { if (!isCurrent(ticket)) return null }
            throw error
        }
        return mutex.withLock {
            if (!isCurrent(ticket)) null else LoginQr(ticket, qr.key, qr.url, startedAt + QR_LIFETIME_MS)
        }
    }

    suspend fun pollQr(qr: LoginQr): QrStatus {
        mutex.withLock {
            if (!isCurrent(qr.ticket)) return QrStatus.SUPERSEDED
            if (nowMs() >= qr.expiresAtMs) { attempt++; return QrStatus.EXPIRED }
        }
        val result = try { api.pollQr(qr.key) } catch (error: AppFailure) {
            mutex.withLock {
                if (!isCurrent(qr.ticket)) return QrStatus.SUPERSEDED
                if (nowMs() >= qr.expiresAtMs) { attempt++; return QrStatus.EXPIRED }
            }
            throw error
        }
        return mutex.withLock {
            if (!isCurrent(qr.ticket)) return QrStatus.SUPERSEDED
            if (nowMs() >= qr.expiresAtMs) { attempt++; return QrStatus.EXPIRED }
            when (result.status) {
                QrStatus.SUCCESS -> install(result.credentials ?: throw AppFailure.InvalidResponse())
                QrStatus.EXPIRED -> attempt++
                else -> Unit
            }
            result.status
        }
    }

    suspend fun acceptWebCookies(ticket: LoginTicket, cookieHeader: String): Boolean = mutex.withLock {
        if (!isCurrent(ticket)) return false
        install(BiliCredentials.fromWebCookies(cookieHeader))
        true
    }

    /** Verify the official browser snapshot before replacing an existing encrypted account. */
    suspend fun verifyAndAcceptWebCookies(ticket: LoginTicket, cookieHeader: String): Boolean {
        mutex.withLock { if (!isCurrent(ticket)) return false }
        val next = BiliCredentials.fromWebCookies(cookieHeader)
        val profile = try {
            api.profile(next) ?: throw AppFailure.LoginRequired()
        } catch (error: AppFailure) {
            mutex.withLock { if (!isCurrent(ticket)) return false }
            throw error
        }
        return mutex.withLock {
            if (!isCurrent(ticket)) return false
            // Persist and publish the same verified account, even if disposal occurs during disk IO.
            withContext(NonCancellable) {
                install(next)
                mutableState.value = AccountState(AccountStatus.SIGNED_IN, profile)
            }
            true
        }
    }

    suspend fun cancelLogin(ticket: LoginTicket) = mutex.withLock {
        if (isCurrent(ticket)) attempt++
    }

    suspend fun cancelQr(qr: LoginQr) = cancelLogin(qr.ticket)

    suspend fun logout() = mutex.withLock {
        // Invalidate in-flight operations and stop sending credentials even if durable deletion fails.
        generation++; attempt++; checkSequence++
        credentials = BiliCredentials.Empty
        loaded = true
        clearCredentials()
    }

    private suspend fun readIfNeeded() {
        if (loaded) return
        try {
            credentials = vault.read()
            loaded = true
            mutableState.value = AccountState(if (credentials.hasSession) AccountStatus.UNVERIFIED else AccountStatus.SIGNED_OUT)
        } catch (error: AppFailure) {
            loaded = true
            credentials = BiliCredentials.Empty
            mutableState.value = AccountState(AccountStatus.STORAGE_ERROR, failure = error)
        }
    }

    /** Persistence + in-memory publication are indivisible even if the page is closed during disk IO. */
    private suspend fun install(next: BiliCredentials) = withContext(NonCancellable) {
        if (!next.hasSession) throw AppFailure.InvalidResponse()
        vault.replace(next)
        credentials = next
        loaded = true
        generation++; attempt++; checkSequence++
        mutableState.value = AccountState(AccountStatus.UNVERIFIED)
    }

    private suspend fun clearCredentials() = withContext(NonCancellable) {
        try {
            vault.clear()
            clearWebSession()
            mutableState.value = AccountState(AccountStatus.SIGNED_OUT)
        } catch (error: AppFailure) {
            mutableState.value = AccountState(AccountStatus.LOGOUT_PENDING, failure = error)
        }
    }

    private fun isCurrent(ticket: LoginTicket) = ticket.generation == generation && ticket.attempt == attempt
    private fun isCurrent(snapshot: CheckSnapshot) = snapshot.generation == generation && snapshot.check == checkSequence
    private class CheckSnapshot(val generation: Long, val check: Long, val credentials: BiliCredentials)
    companion object { private const val QR_LIFETIME_MS = 180_000L }
}
