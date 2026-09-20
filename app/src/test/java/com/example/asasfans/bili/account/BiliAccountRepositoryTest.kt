package com.example.asasfans.bili.account

import com.example.asasfans.core.model.AppFailure
import kotlinx.coroutines.*
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.runCurrent
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class BiliAccountRepositoryTest {
    private class Vault : BiliCredentialVault {
        var saved = credentials("old")
        var failRead = false
        var failWrite = false
        var failClear = false
        var writes = 0
        var beforeWrite: suspend () -> Unit = {}
        override suspend fun read(): BiliCredentials {
            if (failRead) throw AppFailure.LocalStorage()
            return saved
        }
        override suspend fun replace(credentials: BiliCredentials) {
            beforeWrite()
            if (failWrite) throw AppFailure.LocalStorage()
            saved = credentials; writes++
        }
        override suspend fun clear() {
            if (failClear) throw AppFailure.LocalStorage()
            saved = BiliCredentials.Empty
        }
    }
    private class Api : BiliAccountApi {
        var load: suspend (BiliCredentials) -> BiliProfile? = { BiliProfile(1, "合成测试账号", "", 10) }
        var poll: suspend () -> PolledQr = { PolledQr(QrStatus.SUCCESS, credentials("new")) }
        override suspend fun profile(credentials: BiliCredentials) = load(credentials)
        override suspend fun generateQr() = GeneratedQr("a".repeat(32), "https://passport.bilibili.com/fixture")
        override suspend fun pollQr(key: String) = poll()
    }

    @Test fun networkFailureRetainsProfileAndCredentialsWithoutPretendingLogout() = runTest {
        val vault = Vault(); val api = Api(); val account = BiliAccountRepository(vault, api)
        account.refresh()
        assertEquals(AccountStatus.SIGNED_IN, account.state.value.status)
        api.load = { throw AppFailure.Network() }
        account.refresh()
        assertEquals(AccountStatus.UNVERIFIED, account.state.value.status)
        assertEquals(1L, account.state.value.profile!!.mid)
        assertTrue(account.requestCredentials().hasSession)
        assertFalse(account.state.value.checking)
    }

    @Test fun explicitAnonymousResponseExpiresStoredLoginButDoesNotDestroyIt() = runTest {
        val vault = Vault(); val api = Api().apply { load = { null } }
        val account = BiliAccountRepository(vault, api)
        account.refresh()
        assertEquals(AccountStatus.EXPIRED, account.state.value.status)
        assertTrue(vault.saved.hasSession)
    }

    @Test fun unreadableVaultAllowsAnonymousAccessAndCanBeRetried() = runTest {
        val vault = Vault().apply { failRead = true }
        val account = BiliAccountRepository(vault, Api())
        assertFalse(account.requestCredentials().hasSession)
        assertEquals(AccountStatus.STORAGE_ERROR, account.state.value.status)
        vault.failRead = false
        account.retryStorage()
        assertTrue(account.requestCredentials().hasSession)
        assertEquals(AccountStatus.UNVERIFIED, account.state.value.status)
    }

    @Test fun lateQrCannotRestoreLogout() = runTest {
        val deferred = CompletableDeferred<PolledQr>()
        val vault = Vault(); val api = Api().apply { poll = { deferred.await() } }
        val account = BiliAccountRepository(vault, api)
        val qr = account.createQr()!!
        val request = async { account.pollQr(qr) }; runCurrent()
        account.logout()
        deferred.complete(PolledQr(QrStatus.SUCCESS, credentials("new")))
        assertEquals(QrStatus.SUPERSEDED, request.await())
        assertEquals(0, vault.writes)
        assertEquals(AccountStatus.SIGNED_OUT, account.state.value.status)
        assertFalse(account.requestCredentials().hasSession)
    }

    @Test fun newerLoginInvalidatesOlderQrAndWebTickets() = runTest {
        val vault = Vault(); val account = BiliAccountRepository(vault, Api())
        val web = account.beginWebLogin()
        val old = account.createQr()!!
        val fresh = account.createQr()!!
        assertFalse(account.acceptWebCookies(web, "SESSDATA=fixture-old-web"))
        assertEquals(QrStatus.SUPERSEDED, account.pollQr(old))
        assertEquals(QrStatus.SUCCESS, account.pollQr(fresh))
        assertEquals(QrStatus.SUPERSEDED, account.pollQr(fresh))
        assertEquals(1, vault.writes)
    }

    @Test fun obsoleteQrFailureDoesNotSurfaceAsAnErrorForTheNewAttempt() = runTest {
        val gate = CompletableDeferred<Unit>()
        val api = Api().apply { poll = { gate.await(); throw AppFailure.Network() } }
        val account = BiliAccountRepository(Vault(), api)
        val old = account.createQr()!!
        val pending = async { account.pollQr(old) }; runCurrent()
        account.createQr()
        gate.complete(Unit)
        assertEquals(QrStatus.SUPERSEDED, pending.await())
    }

    @Test fun refreshResponseCannotOverwriteNewLogin() = runTest {
        val deferred = CompletableDeferred<BiliProfile?>()
        val account = BiliAccountRepository(Vault(), Api().apply { load = { deferred.await() } })
        val check = async { account.refresh() }; runCurrent()
        val ticket = account.beginWebLogin()
        assertTrue(account.acceptWebCookies(ticket, "SESSDATA=fixture-new-web"))
        deferred.complete(BiliProfile(99, "旧响应", "", 1))
        check.await()
        assertEquals(AccountStatus.UNVERIFIED, account.state.value.status)
        assertNull(account.state.value.profile)
    }

    @Test fun latestRefreshWinsEvenInSameCredentialGeneration() = runTest {
        val first = CompletableDeferred<BiliProfile?>()
        val api = Api().apply { load = { first.await() } }
        val account = BiliAccountRepository(Vault(), api)
        val check = async { account.refresh() }; runCurrent()
        api.load = { null }; account.refresh()
        first.complete(BiliProfile(1, "旧响应", "", 1)); check.await()
        assertEquals(AccountStatus.EXPIRED, account.state.value.status)
    }

    @Test fun cancellationClearsCheckingFlagAndDoesNotEraseSession() = runTest {
        val account = BiliAccountRepository(Vault(), Api().apply { load = { awaitCancellation() } })
        val job = launch { account.refresh() }; runCurrent()
        assertTrue(account.state.value.checking)
        job.cancelAndJoin()
        assertFalse(account.state.value.checking)
        assertTrue(account.requestCredentials().hasSession)
    }

    @Test fun logoutFailureIsVisibleAndStopsSendingCookiesUntilDeletionRetrySucceeds() = runTest {
        val vault = Vault().apply { failClear = true }
        val account = BiliAccountRepository(vault, Api())
        account.logout()
        assertEquals(AccountStatus.LOGOUT_PENDING, account.state.value.status)
        assertFalse(account.requestCredentials().hasSession)
        assertTrue(vault.saved.hasSession)
        vault.failClear = false; account.retryStorage()
        assertFalse(vault.saved.hasSession)
        assertEquals(AccountStatus.SIGNED_OUT, account.state.value.status)
    }

    @Test fun failedSaveDoesNotPublishNewAccount() = runTest {
        val vault = Vault().apply { failWrite = true }
        val account = BiliAccountRepository(vault, Api())
        val ticket = account.beginWebLogin()
        try { account.acceptWebCookies(ticket, "SESSDATA=fixture-next"); fail("must fail") }
        catch (_: AppFailure.LocalStorage) { }
        assertEquals(credentials("old").cookieHeader(), account.requestCredentials().cookieHeader())
        assertEquals(0, vault.writes)
    }

    @Test fun cancellationDuringDiskWriteStillPublishesTheCommittedSession() = runTest {
        val gate = CompletableDeferred<Unit>()
        val vault = Vault().apply { beforeWrite = { gate.await() } }
        val account = BiliAccountRepository(vault, Api())
        val ticket = account.beginWebLogin()
        val job = launch { account.acceptWebCookies(ticket, "SESSDATA=fixture-committed") }
        runCurrent(); job.cancel(); gate.complete(Unit); job.join()
        assertEquals(vault.saved.cookieHeader(), account.requestCredentials().cookieHeader())
        assertEquals("SESSDATA=fixture-committed", vault.saved.cookieHeader())
        assertEquals(1, vault.writes)
    }

    @Test fun qrExpiryAndCancellationCannotInstallCredentials() = runTest {
        var now = 0L
        val vault = Vault(); val account = BiliAccountRepository(vault, Api()) { now }
        val qr = account.createQr()!!
        now = 180_000L
        assertEquals(QrStatus.EXPIRED, account.pollQr(qr))
        val next = account.createQr()!!
        account.cancelQr(next)
        assertEquals(QrStatus.SUPERSEDED, account.pollQr(next))
        assertEquals(0, vault.writes)
    }

    companion object {
        private fun credentials(name: String) = BiliCredentials.fromWebCookies("SESSDATA=fixture-$name; bili_jct=fixture-csrf-$name")
    }
}
