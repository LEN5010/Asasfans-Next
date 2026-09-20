package com.example.asasfans.player

import com.example.asasfans.core.model.*
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ProgressWriterTest {
    @Test fun coalescesWithinPartWithoutLosingOtherPart() = runTest {
        val writes = mutableListOf<ProgressRecord>()
        val writer = ProgressWriter(backgroundScope) { writes += it }
        writer.submit(record(1, 1000)); writer.submit(record(2, 2000)); writer.submit(record(1, 3000))
        runCurrent()
        assertEquals(mapOf(1L to 3000L, 2L to 2000L), writes.associate { it.partId to it.positionMs })
    }
    @Test fun aFailedWriteRemainsPendingUntilExplicitRetrySucceeds() = runTest {
        var fail = true
        val writes = mutableListOf<ProgressRecord>()
        val writer = ProgressWriter(backgroundScope) { if (fail) throw AppFailure.LocalStorage() else writes += it }
        writer.submit(record(1, 1000)); writer.submit(record(2, 2000)); runCurrent()
        assertNotNull(writer.error.value); assertTrue(writes.isEmpty())
        fail = false; writer.retry(); runCurrent()
        assertEquals(2, writes.size); assertNull(writer.error.value)
    }
    @Test fun inFlightWriteCannotRemoveNewerPendingSnapshot() = runTest {
        val gate = CompletableDeferred<Unit>()
        val writes = mutableListOf<Long>()
        val writer = ProgressWriter(backgroundScope) {
            if (it.positionMs == 1000L) gate.await()
            writes += it.positionMs
        }
        writer.submit(record(1, 1000)); runCurrent()
        writer.submit(record(1, 2000)); gate.complete(Unit); runCurrent()
        assertEquals(listOf(1000L, 2000L), writes)
    }
    private fun record(part: Long, at: Long) = ProgressRecord(Video(ContentId.bilibili("BV1xx411c7mD"), "fixture", Creator(id = "42")), part, at, 120_000, false)
}
