package com.example.asasfans.bili.content

import com.example.asasfans.core.model.Video
import com.example.asasfans.core.model.VideoPart
import com.example.asasfans.core.model.Creator

data class CreatorProfile(val creator: Creator, val introduction: String, val officialTitle: String = "")

data class VideoDetails(val video: Video, val aid: Long, val parts: List<VideoPart>)

data class ReadOnlyComment(
    val id: Long,
    val authorId: String,
    val authorName: String,
    val avatarUrl: String,
    val message: String,
    val createdAtMs: Long,
    val likes: Long?,
    val pinned: Boolean = false,
    val hot: Boolean = false,
)
data class CommentPage(val comments: List<ReadOnlyComment>, val page: Int, val total: Long?, val hasMore: Boolean)
enum class CommentOrder(val value: String) { NEWEST("0"), LIKES("1"), REPLIES("2") }

data class QualityOption(val id: Int, val label: String, val available: Boolean)

/** Ephemeral only: never store signed media URLs in the library or export them in backups. */
class MediaTrack(
    val quality: Int,
    val codecs: String,
    val mimeType: String,
    val bandwidth: Long,
    val urls: List<String>,
) {
    override fun toString() = "MediaTrack(quality=$quality, urls=<redacted>)"
}
class MediaSegment(val order: Int, val durationMs: Long, val urls: List<String>) {
    override fun toString() = "MediaSegment(order=$order, urls=<redacted>)"
}
class PlaybackStreams(
    val videos: List<MediaTrack>,
    val audios: List<MediaTrack>,
    val segments: List<MediaSegment>,
    val qualities: List<QualityOption>,
    val returnedQuality: Int,
    val durationMs: Long,
    val obtainedAtMs: Long,
) {
    fun selectVideo(requested: Int): MediaTrack? {
        val candidates = videos.filter { it.quality == requested }.ifEmpty {
            videos.filter { requested <= 0 || it.quality <= requested }.ifEmpty { videos }
        }
        return candidates.sortedWith(compareByDescending<MediaTrack> { it.codecs.startsWith("avc1") }
            .thenByDescending { it.quality }.thenByDescending { it.bandwidth }).firstOrNull()
    }
    fun selectAudio(): MediaTrack? = audios.sortedWith(compareByDescending<MediaTrack> { it.quality == 30280 }
        .thenByDescending { it.bandwidth }).firstOrNull()
    override fun toString() = "PlaybackStreams(quality=$returnedQuality, urls=<redacted>)"
}

internal fun qualityLabel(quality: Int): String = when (quality) {
    6 -> "240P 极速"
    16 -> "360P 流畅"
    32 -> "480P 清晰"
    64 -> "720P 高清"
    74 -> "720P60"
    80 -> "1080P 高清"
    112 -> "1080P+"
    116 -> "1080P60"
    120 -> "4K 超清"
    125 -> "HDR"
    126 -> "杜比视界"
    127 -> "8K 超高清"
    129 -> "HDR Vivid"
    else -> "清晰度 $quality" // These are quality IDs, not a number of pixels.
}
