package com.example.asasfans.player

import android.content.Context
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.ConcatenatingMediaSource2
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.MergingMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import com.example.asasfans.bili.content.PlaybackStreams
import com.example.asasfans.bili.network.BiliMediaDataSource
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

/** A released player's listener retains its own token, never reads a mutable current CID. */
@OptIn(UnstableApi::class)
class Media3PlaybackEngine(context: Context, private val media: BiliMediaDataSource) : PlaybackEngine {
    private val app = context.applicationContext
    private val mutablePlayer = MutableStateFlow<ExoPlayer?>(null)
    val player = mutablePlayer.asStateFlow()
    override var listener: PlaybackEngine.Listener? = null

    override fun load(token: Long, bvid: String, streams: PlaybackStreams, quality: Int, backup: Int, positionMs: Long, speed: Float, play: Boolean) {
        release()
        val factory = media.factory(bvid)
        fun source(urls: List<String>): MediaSource = ProgressiveMediaSource.Factory(factory)
            .createMediaSource(MediaItem.fromUri(urls[backup.coerceAtMost(urls.lastIndex)]))
        val video = streams.selectVideo(quality)
        val source = if (video != null) {
            val audio = streams.selectAudio()
            if (audio == null) source(video.urls) else MergingMediaSource(source(video.urls), source(audio.urls))
        } else {
            require(streams.segments.isNotEmpty())
            if (streams.segments.size == 1) source(streams.segments.single().urls)
            else ConcatenatingMediaSource2.Builder().apply { streams.segments.forEach { add(source(it.urls)) } }.build()
        }
        val exo = ExoPlayer.Builder(app).build()
        mutablePlayer.value = exo
        exo.setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(), true)
        exo.setHandleAudioBecomingNoisy(true)
        exo.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                when (playbackState) {
                    Player.STATE_IDLE -> Unit
                    Player.STATE_READY -> listener?.ready(token)
                    Player.STATE_BUFFERING -> listener?.buffering(token)
                    Player.STATE_ENDED -> listener?.ended(token)
                }
            }
            override fun onPlayerError(error: PlaybackException) {
                val kind = when (error.errorCode) {
                    in 2000..2999 -> MediaFailureKind.NETWORK
                    in 4000..4999 -> MediaFailureKind.DECODER
                    else -> MediaFailureKind.OTHER
                }
                listener?.failed(token, kind)
            }
            override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                if (!playWhenReady && (reason == Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_BECOMING_NOISY ||
                    reason == Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_FOCUS_LOSS)) listener?.interrupted(token)
            }
        })
        exo.setMediaSource(source, positionMs)
        exo.setPlaybackSpeed(speed)
        exo.playWhenReady = play
        exo.prepare()
    }

    override fun position(): EnginePosition? = player.value?.let {
        EnginePosition(it.currentPosition.coerceAtLeast(0), it.duration.takeIf { d -> d != C.TIME_UNSET && d > 0 } ?: 0, it.isPlaying)
    }
    override fun play(enabled: Boolean) { player.value?.playWhenReady = enabled }
    override fun seek(positionMs: Long) { player.value?.seekTo(positionMs) }
    override fun speed(value: Float) { player.value?.setPlaybackSpeed(value) }
    override fun release() {
        val previous = mutablePlayer.value
        mutablePlayer.value = null
        previous?.release()
    }
}
