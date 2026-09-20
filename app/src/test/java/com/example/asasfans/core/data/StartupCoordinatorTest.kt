package com.example.asasfans.core.data

import com.example.asasfans.core.model.AppFailure
import com.example.asasfans.core.database.UnsupportedLegacyVersion
import java.io.IOException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class StartupCoordinatorTest {
    @Test fun failedAssetsNeverUnlockWritesAndCanBeRetried() = runBlocking {
        var shouldFail = true
        var preferenceImports = 0
        val startup = StartupCoordinator(importAssets = { if (shouldFail) throw IOException("private/path") },
            importPreferences = { preferenceImports++ })
        startup.initialize()
        assertTrue(startup.state.value is StartupState.Failed)
        assertFalse((startup.state.value as StartupState.Failed).message.contains("private"))
        assertEquals(0, preferenceImports)
        try { startup.requireReady(); fail("writes must remain locked") } catch (_: AppFailure.LocalStorage) { }
        shouldFail = false
        startup.initialize()
        startup.requireReady()
        assertEquals(StartupState.Ready, startup.state.value)
        assertEquals(1, preferenceImports)
        startup.initialize()
        assertEquals(1, preferenceImports)
    }
    @Test fun preferencesMustFinishBeforeBecomingReady() = runBlocking {
        val startup = StartupCoordinator(importAssets = {}, importPreferences = { throw IOException("disk") })
        startup.initialize()
        assertTrue(startup.state.value is StartupState.Failed)
    }
    @Test fun cancellationDoesNotBecomeAnUnrecoverableFailure() = runBlocking {
        val startup = StartupCoordinator(importAssets = { throw CancellationException() }, importPreferences = {})
        try { startup.initialize(); fail("must propagate cancellation") } catch (_: CancellationException) { }
        assertEquals(StartupState.NotStarted, startup.state.value)
    }
    @Test fun unsupportedVersionDoesNotMisdiagnoseStorageSpace() = runBlocking {
        val startup = StartupCoordinator(importAssets = { throw UnsupportedLegacyVersion(5) }, importPreferences = {})
        startup.initialize()
        val failure = startup.state.value as StartupState.Failed
        assertEquals("UnsupportedLegacyVersion", failure.failureType)
        assertEquals("此版本暂不支持现有数据，请更新应用", failure.message)
        assertFalse(failure.message.contains("存储空间"))
    }

}
