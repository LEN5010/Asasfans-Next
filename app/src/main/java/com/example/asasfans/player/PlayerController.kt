package com.example.asasfans.player

import com.example.asasfans.bili.content.PlaybackStreams
import com.example.asasfans.bili.content.VideoDetails
import com.example.asasfans.core.model.AppFailure
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Playback coordination, with immutable request identities and bounded recovery.
 * Main-thread confined; no Activity or Media3 classes, so lifecycle/race tests need no device.
 */
class PlayerController(
    private val scope: CoroutineScope,
    private val engine: PlaybackEngine,
    private val loadDetail: suspend (String) -> VideoDetails,
    private val loadStreams: suspend (String, Long, Int, Boolean) -> PlaybackStreams,
    private val readProgress: suspend (String, Long?) -> SavedPosition?,
    private val saveProgress: (ProgressRecord) -> Unit,
    initialSpeed: Float = 1f,
    private val nowMs: () -> Long = System::currentTimeMillis,
) : PlaybackEngine.Listener {
    private val mutableState = MutableStateFlow(PlayerState(speed = initialSpeed.coerceIn(.25f, 3f)))
    val state = mutableState.asStateFlow()
    private var generation = 0L
    private var job: Job? = null
    private var foreground = false
    private var closed = false
    private var prepared = false
    private var streams: PlaybackStreams? = null
    private var recovery = Recovery()
    private var lastSavedAt = 0L
    private var lastSavedRecord: ProgressRecord? = null
    private var opening: OpenRequest? = null
    var autoAdvance = true

    init { engine.listener = this }

    fun open(bvid: String, partId: Long? = null, positionMs: Long? = null, play: Boolean = true) {
        if (closed) return
        checkpoint()
        val token = invalidate()
        opening = OpenRequest(bvid, partId, positionMs, play)
        mutableState.value = PlayerState(speed = state.value.speed, requestedQuality = state.value.requestedQuality,
            playIntent = play, phase = PlayerPhase.LOADING)
        job = scope.launch {
            try {
                val details = loadDetail(bvid)
                if (!current(token)) return@launch
                mutableState.value = state.value.copy(details = details)
                val saved = readProgress(details.video.id.key, partId)
                if (!current(token)) return@launch
                val selected = partId ?: saved?.partId ?: details.parts.firstOrNull()?.id
                val part = details.parts.firstOrNull { it.id == selected }
                    ?: throw AppFailure.InvalidInput("原分 P 已不存在，请重新选择；历史记录仍保留")
                val position = positionMs ?: saved?.takeIf { it.partId == part.id && !it.completed }?.positionMs ?: 0
                mutableState.value = state.value.copy(details = details, partId = part.id,
                    positionMs = clamp(position, part.durationMs), durationMs = part.durationMs)
                requestStreams(token, recovery)
            } catch (error: CancellationException) { throw error }
            catch (error: AppFailure) { fail(token, error.userMessage) }
        }
    }

    fun selectPart(partId: Long) {
        val details = state.value.details ?: return
        if (details.parts.none { it.id == partId }) return
        open(details.video.id.value, partId, play = state.value.playIntent)
    }

    fun selectQuality(quality: Int) {
        if (closed || state.value.details == null || quality < 0) return
        checkpoint()
        val token = invalidate()
        mutableState.value = state.value.copy(requestedQuality = quality, playing = false, phase = PlayerPhase.LOADING, message = null)
        job = scope.launch { requestStreams(token, recovery) }
    }

    fun retry() {
        if (state.value.details == null || state.value.partId == null) opening?.let { open(it.bvid, it.part, it.position, it.play) }
        else selectQuality(state.value.requestedQuality)
    }

    fun setForeground(visible: Boolean) {
        if (closed) return
        if (!visible) checkpoint()
        foreground = visible
        engine.play(visible && state.value.playIntent && prepared)
        if (!visible) mutableState.value = state.value.copy(playing = false)
    }

    fun setPlayIntent(play: Boolean) {
        if (closed) return
        if (!play) checkpoint()
        if (play && state.value.phase == PlayerPhase.ENDED) {
            seek(0)
            mutableState.value = state.value.copy(phase = PlayerPhase.READY)
        }
        mutableState.value = state.value.copy(playIntent = play)
        engine.play(play && foreground && prepared)
    }

    fun setSpeed(value: Float) {
        if (!value.isFinite() || value !in .25f..3f || closed) return
        mutableState.value = state.value.copy(speed = value)
        engine.speed(value)
    }

    fun seek(positionMs: Long) {
        if (closed) return
        val position = clamp(positionMs, state.value.durationMs)
        mutableState.value = state.value.copy(positionMs = position)
        if (prepared) { engine.seek(position); checkpoint() }
    }

    fun tick() {
        if (closed || !prepared) return
        samplePosition()
        if (nowMs() - lastSavedAt >= SAVE_INTERVAL_MS) checkpoint()
    }

    fun checkpoint(completed: Boolean = false) {
        if (!prepared) return // A playurl failure is not a view at 00:00.
        samplePosition()
        val state = state.value
        val video = state.details?.video ?: return
        val part = state.partId ?: return
        val record = ProgressRecord(video, part, state.positionMs, state.durationMs, completed || state.phase == PlayerPhase.ENDED)
        if (record != lastSavedRecord) { saveProgress(record); lastSavedRecord = record }
        lastSavedAt = nowMs()
    }

    fun close() {
        if (closed) return
        checkpoint()
        closed = true
        invalidate()
        engine.listener = null
        mutableState.value = state.value.copy(playing = false)
    }

    override fun ready(token: Long) {
        if (!current(token)) return
        prepared = true
        mutableState.value = state.value.copy(phase = PlayerPhase.READY)
        engine.play(foreground && state.value.playIntent)
        samplePosition()
    }

    override fun buffering(token: Long) {
        if (current(token)) mutableState.value = state.value.copy(phase = PlayerPhase.BUFFERING, playing = false)
    }

    override fun interrupted(token: Long) {
        if (!current(token)) return
        checkpoint()
        mutableState.value = state.value.copy(playIntent = false, playing = false)
    }

    override fun ended(token: Long) {
        if (!current(token)) return
        mutableState.value = state.value.copy(phase = PlayerPhase.ENDED, playing = false)
        checkpoint(completed = true)
        val details = state.value.details ?: return
        val index = details.parts.indexOfFirst { it.id == state.value.partId }
        if (autoAdvance && foreground && state.value.playIntent && index >= 0 && index < details.parts.lastIndex) {
            open(details.video.id.value, details.parts[index + 1].id, positionMs = 0)
        } else mutableState.value = state.value.copy(playIntent = false)
    }

    override fun failed(token: Long, kind: MediaFailureKind) {
        if (!current(token) || state.value.phase == PlayerPhase.FAILED) return
        checkpoint()
        val available = streams ?: return fail(token, "媒体播放失败，请重试或用 B 站打开")
        val backupCount = if (recovery.mp4) available.segments.minOfOrNull { it.urls.size } ?: 0
            else maxOf(available.selectVideo(state.value.requestedQuality)?.urls?.size ?: 0,
                available.selectAudio()?.urls?.size ?: 0)
        val next = when {
            kind != MediaFailureKind.DECODER && recovery.backup + 1 < backupCount.coerceAtMost(3) -> recovery.copy(backup = recovery.backup + 1)
            kind != MediaFailureKind.DECODER && !recovery.refreshed -> recovery.copy(refreshed = true, backup = 0)
            !recovery.mp4 -> Recovery(mp4 = true)
            else -> null
        }
        if (next == null) return fail(token, if (kind == MediaFailureKind.DECODER) "设备无法解码此媒体，请用 B 站打开" else "媒体加载失败，自动恢复已停止，请重试或用 B 站打开")
        // Every installation gets a new token; late errors from a released player cannot re-enter recovery.
        val newToken = invalidate(resetRecovery = false)
        val previous = recovery
        recovery = next
        mutableState.value = state.value.copy(phase = PlayerPhase.LOADING, playing = false, message = "正在恢复播放…")
        if (next.mp4 == previous.mp4 && next.backup > 0) install(newToken, available, next)
        else job = scope.launch { requestStreams(newToken, next) }
    }

    private suspend fun requestStreams(token: Long, attempt: Recovery) {
        val snapshot = state.value
        val video = snapshot.details?.video ?: return
        val part = snapshot.partId ?: return
        try {
            val result = loadStreams(video.id.value, part, snapshot.requestedQuality, attempt.mp4)
            if (current(token)) install(token, result, attempt)
        } catch (error: CancellationException) { throw error }
        catch (error: AppFailure) {
            if (!current(token)) return
            if (!attempt.mp4 && error !is AppFailure.RiskControl && error !is AppFailure.LoginRequired && error !is AppFailure.InvalidInput) {
                recovery = Recovery(mp4 = true)
                requestStreams(token, recovery)
            } else fail(token, error.userMessage)
        }
    }

    private fun install(token: Long, result: PlaybackStreams, attempt: Recovery) {
        if (!current(token)) return
        streams = result
        val snapshot = state.value
        val video = snapshot.details?.video ?: return
        val actualQuality = if (attempt.mp4) result.returnedQuality else result.selectVideo(snapshot.requestedQuality)?.quality ?: result.returnedQuality
        mutableState.value = snapshot.copy(phase = PlayerPhase.BUFFERING, actualQuality = actualQuality, qualities = result.qualities,
            durationMs = result.durationMs.takeIf { it > 0 } ?: snapshot.durationMs, usingMp4 = attempt.mp4, message = null)
        try {
            engine.load(token, video.id.value, result, snapshot.requestedQuality, attempt.backup,
                clamp(snapshot.positionMs, state.value.durationMs), snapshot.speed, foreground && snapshot.playIntent)
        } catch (_: IllegalArgumentException) { fail(token, "媒体格式无法识别，请重试或用 B 站打开") }
    }

    private fun samplePosition() {
        if (!prepared) return
        val position = engine.position() ?: return
        val duration = position.durationMs.takeIf { it > 0 } ?: state.value.durationMs
        mutableState.value = state.value.copy(positionMs = clamp(position.positionMs, duration), durationMs = duration,
            playing = position.playing && foreground && state.value.playIntent)
    }

    private fun invalidate(resetRecovery: Boolean = true): Long {
        generation++
        job?.cancel(); job = null
        prepared = false
        streams = null
        engine.release()
        if (resetRecovery) recovery = Recovery()
        return generation
    }

    private fun fail(token: Long, message: String) {
        if (!current(token)) return
        prepared = false
        engine.release()
        mutableState.value = state.value.copy(phase = PlayerPhase.FAILED, playing = false, message = message)
    }
    private fun current(token: Long) = !closed && token == generation
    private fun clamp(position: Long, duration: Long) = if (duration > 0) position.coerceIn(0, duration) else position.coerceAtLeast(0)
    private data class Recovery(val mp4: Boolean = false, val backup: Int = 0, val refreshed: Boolean = false)
    private data class OpenRequest(val bvid: String, val part: Long?, val position: Long?, val play: Boolean)
    companion object { private const val SAVE_INTERVAL_MS = 10_000L }
}
