package com.example.asasfans.player

import com.example.asasfans.bili.content.PlaybackStreams
import com.example.asasfans.core.model.Video

enum class PlayerPhase { IDLE, LOADING, BUFFERING, READY, ENDED, FAILED }
enum class MediaFailureKind { NETWORK, DECODER, OTHER }
data class PlayerState(
    val details: com.example.asasfans.bili.content.VideoDetails? = null,
    val partId: Long? = null,
    val requestedQuality: Int = 0,
    val actualQuality: Int = 0,
    val qualities: List<com.example.asasfans.bili.content.QualityOption> = emptyList(),
    val positionMs: Long = 0,
    val durationMs: Long = 0,
    val speed: Float = 1f,
    val playIntent: Boolean = true,
    val playing: Boolean = false,
    val phase: PlayerPhase = PlayerPhase.IDLE,
    val message: String? = null,
    val usingMp4: Boolean = false,
)
data class EnginePosition(val positionMs: Long, val durationMs: Long, val playing: Boolean)
data class ProgressRecord(val video: Video, val partId: Long, val positionMs: Long, val durationMs: Long, val completed: Boolean)
data class SavedPosition(val partId: Long, val positionMs: Long, val completed: Boolean = false)

/** All methods and events run on the controller's main-thread owner, not network threads. */
interface PlaybackEngine {
    var listener: Listener?
    fun load(token: Long, bvid: String, streams: PlaybackStreams, quality: Int, backup: Int, positionMs: Long, speed: Float, play: Boolean)
    fun position(): EnginePosition?
    fun play(enabled: Boolean)
    fun seek(positionMs: Long)
    fun speed(value: Float)
    fun release()
    interface Listener {
        fun ready(token: Long)
        fun buffering(token: Long)
        fun ended(token: Long)
        fun failed(token: Long, kind: MediaFailureKind)
        fun interrupted(token: Long)
    }
}
