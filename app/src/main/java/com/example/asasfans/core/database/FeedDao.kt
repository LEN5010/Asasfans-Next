package com.example.asasfans.core.database

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface FeedDao {
    @Upsert suspend fun putEntries(entries: List<FeedEntryEntity>)
    @Upsert suspend fun putSyncState(state: SyncStateEntity)
    @Query("SELECT * FROM source_sync WHERE sourceKey = :key") suspend fun syncState(key: String): SyncStateEntity?
    @Query("SELECT * FROM source_sync WHERE sourceKey = :key") fun observeSyncState(key: String): Flow<SyncStateEntity?>
    @Query("SELECT COUNT(*) FROM feed_entries WHERE feedKey = :key") suspend fun count(key: String): Int
    @Query("SELECT contentId FROM feed_entries WHERE feedKey = :key") suspend fun contentIds(key: String): List<String>
    @Query("DELETE FROM feed_entries WHERE feedKey = :key") suspend fun clearFeed(key: String)
    @Query("SELECT c.* FROM contents c INNER JOIN feed_entries f ON f.contentId = c.id WHERE f.feedKey = :key ORDER BY f.position, c.id LIMIT :limit OFFSET :offset")
    fun entries(key: String, limit: Int = 100, offset: Int = 0): Flow<List<ContentEntity>>
    @Query("DELETE FROM feed_entries") suspend fun clearEntries()
    @Query("DELETE FROM source_sync") suspend fun clearSyncStates()
    /** Only unreferenced cache content can be evicted. User-owned references are protected. */
    @Query("""DELETE FROM contents WHERE id NOT IN (SELECT contentId FROM collection_items)
        AND id NOT IN (SELECT contentId FROM watch_later) AND id NOT IN (SELECT contentId FROM playback_progress)
        AND id NOT IN (SELECT contentId FROM watch_history) AND id NOT IN (SELECT contentId FROM bookmarks)
        AND id NOT IN (SELECT contentId FROM feed_entries)
        AND id NOT IN (SELECT value FROM content_rules WHERE kind = 'VIDEO')
        AND sourceId NOT IN (SELECT value FROM content_rules WHERE kind = 'VIDEO')""")
    suspend fun deleteUnreferencedContent()
}
