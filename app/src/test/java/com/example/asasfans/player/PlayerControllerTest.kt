package com.example.asasfans.player

import com.example.asasfans.bili.content.*
import com.example.asasfans.core.model.*
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PlayerControllerTest {
    private class Engine : PlaybackEngine {
        override var listener: PlaybackEngine.Listener? = null
        data class Loaded(val token: Long, val quality: Int, val backup: Int, val at: Long, val speed: Float, val play: Boolean)
        val loads = mutableListOf<Loaded>()
        var point: EnginePosition? = null
        var enabled = false
        val token get() = loads.last().token
        override fun load(token: Long, bvid: String, streams: PlaybackStreams, quality: Int, backup: Int, positionMs: Long, speed: Float, play: Boolean) {
            loads += Loaded(token, quality, backup, positionMs, speed, play)
            point = EnginePosition(positionMs, streams.durationMs, play); enabled = play
        }
        override fun position() = point?.copy(playing = enabled)
        override fun play(enabled: Boolean) { this.enabled = enabled }
        override fun seek(positionMs: Long) { point = point?.copy(positionMs = positionMs) }
        override fun speed(value: Float) { }
        override fun release() { point = null; enabled = false }
        fun ready() { listener?.ready(token) }
    }
    private class Fixture(scope: CoroutineScope) {
        val engine = Engine()
        val saved = mutableListOf<ProgressRecord>()
        val requests = mutableListOf<Pair<Long, Boolean>>()
        var stored: suspend (Long?) -> SavedPosition? = { null }
        var load: suspend (Long, Boolean) -> PlaybackStreams = { _, mp4 -> streams(mp4) }
        var now = 0L
        val controller = PlayerController(scope, engine, { details() }, { _, cid, _, mp4 -> requests += cid to mp4; load(cid, mp4) },
            { _, part -> stored(part) }, saved::add, nowMs = { now })
        fun open() { controller.setForeground(true); controller.open("BV1xx411c7mD") }
    }

    @Test fun resumesUsingStablePartIdNotItsIndex() = runTest {
        val f = Fixture(this); f.stored = { SavedPosition(201, 45_000) }; f.open(); runCurrent()
        assertEquals(201L, f.controller.state.value.partId)
        assertEquals(45_000L, f.engine.loads.single().at)
        assertEquals(listOf(201L to false), f.requests)
    }
    @Test fun qualitySwitchPreservesPositionSpeedAndPauseIntent() = runTest {
        val f = Fixture(this); f.open(); runCurrent(); f.engine.ready()
        f.engine.point = EnginePosition(31_000, 120_000, true)
        f.controller.setSpeed(1.5f); f.controller.setPlayIntent(false); f.controller.selectQuality(64); runCurrent()
        val load = f.engine.loads.last()
        assertEquals(31_000L, load.at); assertEquals(1.5f, load.speed); assertFalse(load.play)
        assertEquals(64, load.quality)
    }
    @Test fun lateErrorFromPreviousInstallationCannotRecoverNewPart() = runTest {
        val f = Fixture(this); f.open(); runCurrent(); f.engine.ready(); val old = f.engine.token
        f.controller.selectPart(201); runCurrent(); val requests = f.requests.size
        f.controller.failed(old, MediaFailureKind.NETWORK); f.controller.ready(old)
        assertEquals(requests, f.requests.size); assertEquals(201L, f.controller.state.value.partId)
    }
    @Test fun pendingLoadUsesLatestPauseIntentAndDoesNotAutoplayInBackground() = runTest {
        val gate = CompletableDeferred<PlaybackStreams>(); val f = Fixture(this); f.load = { _, _ -> gate.await() }
        f.open(); runCurrent(); f.controller.setPlayIntent(false); f.controller.setForeground(false)
        gate.complete(streams()); runCurrent(); f.engine.ready()
        assertFalse(f.engine.loads.single().play); assertFalse(f.engine.enabled)
        f.controller.setForeground(true); assertFalse(f.engine.enabled)
    }
    @Test fun leavingScreenCancelsPendingSourceAndDoesNotInventHistory() = runTest {
        val gate = CompletableDeferred<PlaybackStreams>(); val f = Fixture(this); f.load = { _, _ -> gate.await() }
        f.open(); runCurrent(); f.controller.close(); gate.complete(streams()); runCurrent()
        assertTrue(f.engine.loads.isEmpty()); assertTrue(f.saved.isEmpty())
    }
    @Test fun riskControlNeverStartsRepeatedMp4RequestsOrCreatesHistory() = runTest {
        val f = Fixture(this); f.load = { _, _ -> throw AppFailure.RiskControl(412) }; f.open(); runCurrent()
        assertEquals(listOf(101L to false), f.requests)
        assertEquals(PlayerPhase.FAILED, f.controller.state.value.phase); assertTrue(f.saved.isEmpty())
    }
    @Test fun requestFailureMayFallBackToMp4Once() = runTest {
        val f = Fixture(this); f.load = { _, mp4 -> if (!mp4) throw AppFailure.Network() else streams(true) }
        f.open(); runCurrent()
        assertEquals(listOf(101L to false, 101L to true), f.requests)
        assertTrue(f.controller.state.value.usingMp4)
    }
    @Test fun decodingFallbackKeepsPositionAndIsBounded() = runTest {
        val f = Fixture(this); f.open(); runCurrent(); f.engine.ready()
        f.engine.point = EnginePosition(55_000, 120_000, true)
        f.controller.failed(f.engine.token, MediaFailureKind.DECODER); runCurrent()
        assertTrue(f.controller.state.value.usingMp4); assertEquals(55_000L, f.engine.loads.last().at)
        f.controller.failed(f.engine.token, MediaFailureKind.DECODER); runCurrent()
        assertEquals(PlayerPhase.FAILED, f.controller.state.value.phase); assertEquals(2, f.requests.size)
    }
    @Test fun repeatedCdnErrorsExhaustFiniteBackupRefreshAndFallbackBudget() = runTest {
        val f = Fixture(this); f.open(); runCurrent()
        repeat(20) { f.controller.failed(f.engine.token, MediaFailureKind.NETWORK); runCurrent() }
        assertEquals(PlayerPhase.FAILED, f.controller.state.value.phase)
        assertTrue(f.engine.loads.size <= 12); assertEquals(4, f.requests.size)
    }
    @Test fun autoAdvanceRecordsCompletionBeforeSelectingNextCid() = runTest {
        val f = Fixture(this); f.open(); runCurrent(); f.engine.ready()
        f.engine.point = EnginePosition(120_000, 120_000, false)
        f.controller.ended(f.engine.token); runCurrent()
        assertTrue(f.saved.first().completed); assertEquals(101L, f.saved.first().partId)
        assertEquals(201L, f.controller.state.value.partId); assertEquals(0L, f.engine.loads.last().at)
    }
    @Test fun missingHistoricalPartPreservesDetailsForExplicitReselection() = runTest {
        val f = Fixture(this); f.stored = { SavedPosition(999, 1000) }; f.open(); runCurrent()
        assertEquals(PlayerPhase.FAILED, f.controller.state.value.phase)
        assertNotNull(f.controller.state.value.details); assertTrue(f.requests.isEmpty())
        f.stored = { null }; f.controller.selectPart(201); runCurrent()
        assertEquals(201L, f.controller.state.value.partId)
    }
    @Test fun progressWritesAreThrottledAndStationaryPositionsAreNotRepeated() = runTest {
        val f = Fixture(this); f.open(); runCurrent(); f.engine.ready()
        f.engine.point = EnginePosition(1000, 120_000, true)
        f.now = 9999; f.controller.tick(); assertTrue(f.saved.isEmpty())
        f.now = 10000; f.controller.tick(); assertEquals(1, f.saved.size)
        f.now = 20000; f.controller.tick(); assertEquals(1, f.saved.size)
        f.engine.point = EnginePosition(2000, 120_000, true); f.controller.close()
        assertEquals(2000L, f.saved.last().positionMs)
    }
    @Test fun audioFocusOrHeadphoneInterruptionRequiresExplicitResume() = runTest {
        val f = Fixture(this); f.open(); runCurrent(); f.engine.ready()
        f.controller.interrupted(f.engine.token); f.controller.setForeground(false); f.controller.setForeground(true)
        assertFalse(f.engine.enabled); assertFalse(f.controller.state.value.playIntent)
    }
    @Test fun completedVideoReplaysWithOnePlayActionWhenAutoAdvanceIsOff() = runTest {
        val f = Fixture(this); f.open(); runCurrent(); f.engine.ready(); f.controller.autoAdvance = false
        f.engine.point = EnginePosition(120_000, 120_000, false); f.controller.ended(f.engine.token)
        assertFalse(f.controller.state.value.playIntent)
        f.controller.setPlayIntent(true)
        assertEquals(0L, f.controller.state.value.positionMs); assertTrue(f.engine.enabled)
    }

    companion object {
        private fun details() = VideoDetails(Video(ContentId.bilibili("BV1xx411c7mD"), "合成视频", Creator(id = "42")), 123,
            listOf(VideoPart(101, 1, "P1", 120_000), VideoPart(201, 2, "P2", 120_000)))
        private fun streams(mp4: Boolean = false) = PlaybackStreams(
            if (mp4) emptyList() else listOf(MediaTrack(64, "avc1", "video/mp4", 100, listOf("https://fixture.bilivideo.com/1", "https://fixture.bilivideo.com/2"))),
            emptyList(), if (mp4) listOf(MediaSegment(1, 120_000, listOf("https://fixture.bilivideo.com/mp4"))) else emptyList(),
            listOf(QualityOption(64, "720P", true)), 64, 120_000, 0)
    }
}
