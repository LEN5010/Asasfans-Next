package com.example.asasfans.next

import org.junit.Assert.*
import org.junit.Test

class AutoPageGateTest {
    private fun signal(count: Int = 20, cursor: String = "2", last: Int = 17, enabled: Boolean = true, key: String = "new") =
        PagingSignal(key, cursor, count, last, count + 1, enabled)

    @Test fun requestsNearEndButNotAtTop() {
        val gate = AutoPageGate()
        assertFalse(gate.claim(signal(last = 8)))
        assertTrue(gate.claim(signal()))
    }
    @Test fun claimsEachContentBoundaryOnceAcrossRecompositionsAndLoadingTransitions() {
        val gate = AutoPageGate()
        assertTrue(gate.claim(signal()))
        assertFalse(gate.claim(signal(last = 18)))
        assertFalse(gate.claim(signal(enabled = false)))
        assertFalse(gate.claim(signal()))
        assertTrue(gate.claim(signal(count = 40, cursor = "3", last = 37)))
    }
    @Test fun errorsEndOfFeedOrManualContinuationDoNotConsumeABoundary() {
        val gate = AutoPageGate()
        assertFalse(gate.claim(signal(enabled = false)))
        assertTrue(gate.claim(signal()))
    }
    @Test fun revealingCachedRowsAllowsTheNextBoundaryWithoutChangingServerCursor() {
        val gate = AutoPageGate()
        assertTrue(gate.claim(signal(count = 40, last = 37)))
        assertTrue(gate.claim(signal(count = 80, last = 77)))
    }
    @Test fun switchingQueryWithSameRowCountDoesNotBlockLoading() {
        val gate = AutoPageGate()
        assertTrue(gate.claim(signal(key = "new")))
        assertTrue(gate.claim(signal(key = "clips")))
        assertFalse(gate.claim(signal(last = -1, key = "search")))
    }
    @Test fun refreshingTheSameFirstPageDoesNotPermanentlyBlockItsNextPage() {
        val gate = AutoPageGate()
        assertTrue(gate.claim(signal().copy(revision = 1)))
        assertFalse(gate.claim(signal().copy(revision = 1)))
        assertTrue(gate.claim(signal().copy(revision = 2)))
    }

}
