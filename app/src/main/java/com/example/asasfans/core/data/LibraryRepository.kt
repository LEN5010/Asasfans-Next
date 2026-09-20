package com.example.asasfans.core.data

import androidx.room.withTransaction
import com.example.asasfans.core.database.*
import com.example.asasfans.core.model.Video
import java.util.UUID

/** All user-asset mutations pass the startup migration gate before touching Room. */
class LibraryRepository(
    private val database: AsasDatabase,
    private val awaitReady: suspend () -> Unit,
    private val nowMs: () -> Long = System::currentTimeMillis,
) {
    private val dao = database.assets()
    val collections = dao.collections()
    val watchLater = dao.watchLater()
    val history = dao.history()
    val bookmarks = dao.bookmarks()
    val continueWatching = dao.recentProgress()

    fun collectionContents(id: String) = dao.collectionContents(id)
    fun search(keyword: String) = dao.searchLibrary(keyword.trim().take(256))
    fun isWatchLater(id: String) = dao.isWatchLater(id)
    suspend fun content(id: String): Video? { awaitReady(); return dao.content(id)?.toVideo() }
    suspend fun latestProgress(id: String): ProgressEntity? { awaitReady(); return dao.latestProgress(id) }

    suspend fun createCollection(name: String): String {
        require(name.trim().isNotEmpty() && name.length <= 100)
        awaitReady()
        val id = UUID.randomUUID().toString()
        dao.putCollection(CollectionEntity(id, name.trim(), nowMs()))
        return id
    }

    suspend fun deleteCollection(id: String) { awaitReady(); dao.deleteCollection(id) }
    suspend fun saveToCollection(collectionId: String, video: Video) {
        awaitReady()
        database.withTransaction {
            remember(video)
            dao.addToCollection(CollectionItemEntity(collectionId, video.id.key, nowMs()))
        }
    }
    suspend fun removeFromCollection(collectionId: String, contentId: String) {
        awaitReady(); dao.removeFromCollection(collectionId, contentId)
    }

    suspend fun addWatchLater(video: Video) {
        awaitReady()
        database.withTransaction {
            remember(video)
            dao.addWatchLater(WatchLaterEntity(video.id.key, nowMs()))
        }
    }
    suspend fun removeWatchLater(id: String) { awaitReady(); dao.removeWatchLater(id) }
    suspend fun completeWatchLater(id: String, completed: Boolean) { awaitReady(); dao.completeWatchLater(id, completed) }

    suspend fun recordProgress(video: Video, partId: Long, positionMs: Long, durationMs: Long, completed: Boolean = false) {
        require(partId >= 0 && positionMs >= 0 && durationMs >= 0)
        awaitReady()
        database.withTransaction {
            remember(video)
            val now = nowMs()
            dao.putProgress(ProgressEntity(video.id.key, partId, if (durationMs > 0) positionMs.coerceAtMost(durationMs) else positionMs, durationMs, now, completed))
            dao.putHistory(HistoryEntity(video.id.key, now))
        }
    }
    suspend fun progress(id: String, partId: Long): ProgressEntity? { awaitReady(); return dao.progress(id, partId) }
    suspend fun removeHistory(id: String) { awaitReady(); dao.removeHistory(id) }
    suspend fun clearProgress(id: String) { awaitReady(); dao.clearProgress(id) }

    suspend fun addBookmark(video: Video, partId: Long, positionMs: Long, title: String, note: String = "", endMs: Long? = null): String {
        require(partId >= 0 && positionMs >= 0 && (endMs == null || endMs >= positionMs))
        require(title.trim().isNotEmpty() && title.length <= 200 && note.length <= 10_000)
        awaitReady()
        val id = UUID.randomUUID().toString()
        database.withTransaction {
            remember(video)
            dao.putBookmark(BookmarkEntity(id, video.id.key, partId, positionMs, title.trim(), note, endMs, nowMs()))
        }
        return id
    }
    suspend fun deleteBookmark(id: String) { awaitReady(); dao.deleteBookmark(id) }

    suspend fun clearFeedCache() {
        awaitReady()
        database.withTransaction {
            database.feeds().clearEntries()
            database.feeds().clearSyncStates()
            database.feeds().deleteUnreferencedContent()
        }
    }

    private suspend fun remember(video: Video) {
        val previous = dao.content(video.id.key)
        val next = ContentEntity.from(video, nowMs())
        dao.putContent(next.copy(
            tagsJson = next.tagsJson ?: previous?.tagsJson,
            views = next.views ?: previous?.views,
            likes = next.likes ?: previous?.likes,
            creatorName = next.creatorName.ifBlank { previous?.creatorName.orEmpty() },
            avatarUrl = next.avatarUrl.ifBlank { previous?.avatarUrl.orEmpty() },
            coverUrl = next.coverUrl.ifBlank { previous?.coverUrl.orEmpty() },
        ))
    }
}
