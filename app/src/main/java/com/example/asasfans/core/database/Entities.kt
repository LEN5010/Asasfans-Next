package com.example.asasfans.core.database

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.example.asasfans.core.model.ContentId
import com.example.asasfans.core.model.Creator
import com.example.asasfans.core.model.Video
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Entity(tableName = "contents", indices = [Index(value = ["source", "sourceId"], unique = true), Index("publishedAtMs")])
data class ContentEntity(
    @PrimaryKey val id: String,
    val source: String,
    val sourceId: String,
    val title: String,
    val creatorId: String,
    val creatorName: String = "",
    val avatarUrl: String = "",
    val coverUrl: String = "",
    val description: String = "",
    val category: String = "",
    val tagsJson: String? = null,
    val publishedAtMs: Long = 0,
    val durationMs: Long = 0,
    val views: Long? = null,
    val likes: Long? = null,
    val available: Boolean = true,
    val fetchedAtMs: Long = 0,
) {
    fun toVideo() = Video(
        ContentId(source, sourceId), title, Creator(source, creatorId, creatorName, avatarUrl),
        coverUrl, description, category, tagsJson?.let { Json.decodeFromString<List<String>>(it) },
        publishedAtMs, durationMs, views, likes, available,
    )

    companion object {
        fun from(video: Video, fetchedAtMs: Long) = ContentEntity(
            video.id.key, video.id.source, video.id.value, video.title, video.creator.id, video.creator.name,
            video.creator.avatarUrl, video.coverUrl, video.description, video.category,
            video.tags?.let { Json.encodeToString(it) }, video.publishedAtMs, video.durationMs,
            video.views, video.likes, video.available, fetchedAtMs,
        )
    }
}

@Entity(tableName = "subscriptions", indices = [Index("groupName")])
data class SubscriptionEntity(
    @PrimaryKey val creatorKey: String,
    val source: String,
    val creatorId: String,
    val name: String = "",
    val avatarUrl: String = "",
    val note: String = "",
    val groupName: String = "默认分组",
    val updatedAtMs: Long = 0,
    val readThroughMs: Long = 0,
)

@Entity(tableName = "content_rules", indices = [Index(value = ["kind", "value"], unique = true)])
data class RuleEntity(
    @PrimaryKey val id: String,
    val kind: String,
    val value: String,
    val enabled: Boolean = true,
    val expiresAtMs: Long? = null,
    val origin: String = "user",
)

@Entity(tableName = "collections")
data class CollectionEntity(@PrimaryKey val id: String, val name: String, val createdAtMs: Long, val position: Int = 0)

@Entity(
    tableName = "collection_items", primaryKeys = ["collectionId", "contentId"], indices = [Index("contentId")],
    foreignKeys = [
        ForeignKey(entity = CollectionEntity::class, parentColumns = ["id"], childColumns = ["collectionId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = ContentEntity::class, parentColumns = ["id"], childColumns = ["contentId"], onDelete = ForeignKey.RESTRICT),
    ],
)
data class CollectionItemEntity(val collectionId: String, val contentId: String, val addedAtMs: Long, val note: String = "")

@Entity(tableName = "watch_later", foreignKeys = [
    ForeignKey(entity = ContentEntity::class, parentColumns = ["id"], childColumns = ["contentId"], onDelete = ForeignKey.RESTRICT),
])
data class WatchLaterEntity(@PrimaryKey val contentId: String, val addedAtMs: Long, val completed: Boolean = false, val position: Int = 0)

@Entity(tableName = "playback_progress", primaryKeys = ["contentId", "partId"], indices = [Index("updatedAtMs")], foreignKeys = [
    ForeignKey(entity = ContentEntity::class, parentColumns = ["id"], childColumns = ["contentId"], onDelete = ForeignKey.RESTRICT),
])
data class ProgressEntity(
    val contentId: String, val partId: Long, val positionMs: Long, val durationMs: Long,
    val updatedAtMs: Long, val completed: Boolean = false,
)

@Entity(tableName = "watch_history", indices = [Index("watchedAtMs")], foreignKeys = [
    ForeignKey(entity = ContentEntity::class, parentColumns = ["id"], childColumns = ["contentId"], onDelete = ForeignKey.RESTRICT),
])
data class HistoryEntity(@PrimaryKey val contentId: String, val watchedAtMs: Long)

@Entity(tableName = "bookmarks", indices = [Index("contentId")], foreignKeys = [
    ForeignKey(entity = ContentEntity::class, parentColumns = ["id"], childColumns = ["contentId"], onDelete = ForeignKey.RESTRICT),
])
data class BookmarkEntity(
    @PrimaryKey val id: String, val contentId: String, val partId: Long, val positionMs: Long,
    val title: String, val note: String = "", val endMs: Long? = null, val createdAtMs: Long,
)

@Entity(tableName = "saved_channels")
data class ChannelEntity(@PrimaryKey val id: String, val name: String, val queryJson: String, val position: Int = 0)

@Entity(tableName = "feed_entries", primaryKeys = ["feedKey", "contentId"], indices = [Index("contentId"), Index(value = ["feedKey", "publishedAtMs"])], foreignKeys = [
    ForeignKey(entity = ContentEntity::class, parentColumns = ["id"], childColumns = ["contentId"], onDelete = ForeignKey.CASCADE),
])
data class FeedEntryEntity(val feedKey: String, val contentId: String, val publishedAtMs: Long, val fetchedAtMs: Long, val position: Int = 0)

@Entity(tableName = "source_sync")
data class SyncStateEntity(
    @PrimaryKey val sourceKey: String, val cursor: String? = null, val lastSuccessMs: Long = 0,
    val exhausted: Boolean = false, val errorKind: String? = null, val retryAfterMs: Long = 0,
)

@Entity(tableName = "migration_receipts")
data class MigrationReceiptEntity(@PrimaryKey val id: String, val sourceVersion: Int, val importedAtMs: Long, val rowCount: Int)

/** Invalid historical rows are preserved for recovery instead of silently discarded. */
@Entity(tableName = "legacy_recovery")
data class LegacyRecoveryEntity(@PrimaryKey val id: String, val tableName: String, val rowJson: String, val reason: String)
