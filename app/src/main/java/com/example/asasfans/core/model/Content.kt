package com.example.asasfans.core.model

import kotlinx.serialization.Serializable

/** Stable source identity. Never use a signed playback URL as a content key. */
@Serializable
data class ContentId(val source: String, val value: String) {
    init {
        require(source.matches(Regex("[a-z][a-z0-9_-]{0,31}")))
        require(value.isNotBlank() && value.length <= 2048)
    }

    val key: String get() = "$source:$value"

    companion object {
        fun bilibili(bvid: String) = ContentId("bilibili", bvid)
        fun fromKey(key: String): ContentId {
            val separator = key.indexOf(':')
            require(separator > 0) { "Missing content source" }
            return ContentId(key.substring(0, separator), key.substring(separator + 1))
        }
    }
}

@Serializable
data class Creator(
    val source: String = "bilibili",
    val id: String,
    val name: String = "",
    val avatarUrl: String = "",
) {
    val key: String get() = "$source:$id"
}

@Serializable
data class Video(
    val id: ContentId,
    val title: String,
    val creator: Creator,
    val coverUrl: String = "",
    val description: String = "",
    val category: String = "",
    /** null means this source did not supply tags; empty means known to have no tags. */
    val tags: List<String>? = null,
    val publishedAtMs: Long = 0,
    val durationMs: Long = 0,
    val views: Long? = null,
    val likes: Long? = null,
    val available: Boolean = true,
)

@Serializable
data class VideoPart(val id: Long, val number: Int, val title: String, val durationMs: Long)

@Serializable
enum class VideoOrder { NEWEST, POPULAR }

/** Persist semantic criteria, not a request URL with a frozen date interval. */
@Serializable
data class QuerySpec(
    val version: Int = 1,
    val keyword: String = "",
    val order: VideoOrder = VideoOrder.NEWEST,
    val days: Int? = null,
    val maxDurationMs: Long? = null,
    val copyright: Int? = null,
    val creatorId: String? = null,
    val tags: List<String> = emptyList(),
) {
    init {
        require(version == 1) { "Unsupported query version" }
        require(keyword.length <= 256)
        require(days == null || days in 1..36500)
        require(maxDurationMs == null || maxDurationMs > 0)
        require(copyright == null || copyright in 1..2)
        require(tags.size <= 4 && tags.all { it.isNotBlank() && it.length <= 80 })
    }
}
