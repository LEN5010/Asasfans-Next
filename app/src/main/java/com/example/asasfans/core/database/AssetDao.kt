package com.example.asasfans.core.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface AssetDao {
    @Upsert suspend fun putContent(content: ContentEntity)
    @Upsert suspend fun putContents(contents: List<ContentEntity>)
    @Query("SELECT * FROM contents WHERE id = :id") suspend fun content(id: String): ContentEntity?

    @Upsert suspend fun putSubscription(subscription: SubscriptionEntity)
    @Query("SELECT * FROM subscriptions WHERE creatorKey = :key") suspend fun subscription(key: String): SubscriptionEntity?
    @Query("SELECT * FROM subscriptions ORDER BY groupName, updatedAtMs DESC, creatorKey") fun subscriptions(): Flow<List<SubscriptionEntity>>
    @Query("SELECT * FROM subscriptions ORDER BY creatorKey") suspend fun allSubscriptions(): List<SubscriptionEntity>
    @Query("DELETE FROM subscriptions WHERE creatorKey = :key") suspend fun deleteSubscription(key: String)
    @Query("UPDATE subscriptions SET readThroughMs = :time WHERE creatorKey = :key") suspend fun markRead(key: String, time: Long)

    @Insert(onConflict = OnConflictStrategy.IGNORE) suspend fun insertRule(rule: RuleEntity): Long
    @Upsert suspend fun putRule(rule: RuleEntity)
    @Query("SELECT * FROM content_rules ORDER BY kind, value") fun rules(): Flow<List<RuleEntity>>
    @Query("SELECT * FROM content_rules ORDER BY id") suspend fun allRules(): List<RuleEntity>
    @Query("DELETE FROM content_rules WHERE id = :id") suspend fun deleteRule(id: String)

    @Upsert suspend fun putCollection(collection: CollectionEntity)
    @Query("SELECT * FROM collections ORDER BY position, createdAtMs") fun collections(): Flow<List<CollectionEntity>>
    @Query("SELECT * FROM collections ORDER BY id") suspend fun allCollections(): List<CollectionEntity>
    @Query("DELETE FROM collections WHERE id = :id") suspend fun deleteCollection(id: String)
    @Insert(onConflict = OnConflictStrategy.IGNORE) suspend fun addToCollection(item: CollectionItemEntity): Long
    @Query("DELETE FROM collection_items WHERE collectionId = :collection AND contentId = :content") suspend fun removeFromCollection(collection: String, content: String)
    @Query("SELECT c.* FROM contents c INNER JOIN collection_items i ON i.contentId = c.id WHERE i.collectionId = :id ORDER BY i.addedAtMs DESC, c.id LIMIT :limit OFFSET :offset")
    fun collectionContents(id: String, limit: Int = 100, offset: Int = 0): Flow<List<ContentEntity>>

    @Insert(onConflict = OnConflictStrategy.IGNORE) suspend fun addWatchLater(item: WatchLaterEntity): Long
    @Query("DELETE FROM watch_later WHERE contentId = :id") suspend fun removeWatchLater(id: String)
    @Query("UPDATE watch_later SET completed = :completed WHERE contentId = :id") suspend fun completeWatchLater(id: String, completed: Boolean)
    @Query("SELECT c.* FROM contents c INNER JOIN watch_later w ON w.contentId = c.id WHERE w.completed = 0 ORDER BY w.position, w.addedAtMs DESC, c.id LIMIT :limit OFFSET :offset")
    fun watchLater(limit: Int = 100, offset: Int = 0): Flow<List<ContentEntity>>
    @Query("SELECT EXISTS(SELECT 1 FROM watch_later WHERE contentId = :id)") fun isWatchLater(id: String): Flow<Boolean>

    @Upsert suspend fun putProgress(progress: ProgressEntity)
    @Query("SELECT * FROM playback_progress WHERE contentId = :id AND partId = :part") suspend fun progress(id: String, part: Long): ProgressEntity?
    @Query("SELECT * FROM playback_progress WHERE contentId = :id ORDER BY updatedAtMs DESC, partId DESC LIMIT 1") suspend fun latestProgress(id: String): ProgressEntity?
    @Query("SELECT * FROM playback_progress WHERE completed = 0 ORDER BY updatedAtMs DESC, contentId LIMIT :limit") fun recentProgress(limit: Int = 10): Flow<List<ProgressEntity>>
    @Query("DELETE FROM playback_progress WHERE contentId = :id") suspend fun clearProgress(id: String)
    @Upsert suspend fun putHistory(history: HistoryEntity)
    @Query("SELECT c.* FROM contents c INNER JOIN watch_history h ON h.contentId = c.id ORDER BY h.watchedAtMs DESC, c.id LIMIT :limit OFFSET :offset") fun history(limit: Int = 100, offset: Int = 0): Flow<List<ContentEntity>>
    @Query("DELETE FROM watch_history WHERE contentId = :id") suspend fun removeHistory(id: String)

    @Upsert suspend fun putBookmark(bookmark: BookmarkEntity)
    @Query("SELECT * FROM bookmarks ORDER BY createdAtMs DESC, id LIMIT :limit OFFSET :offset") fun bookmarks(limit: Int = 100, offset: Int = 0): Flow<List<BookmarkEntity>>
    @Query("DELETE FROM bookmarks WHERE id = :id") suspend fun deleteBookmark(id: String)

    @Upsert suspend fun putChannel(channel: ChannelEntity)
    @Query("SELECT * FROM saved_channels ORDER BY position, id") fun channels(): Flow<List<ChannelEntity>>
    @Query("DELETE FROM saved_channels WHERE id = :id") suspend fun deleteChannel(id: String)

    @Query("""SELECT DISTINCT c.* FROM contents c
        WHERE (EXISTS(SELECT 1 FROM collection_items i WHERE i.contentId = c.id)
          OR EXISTS(SELECT 1 FROM watch_later w WHERE w.contentId = c.id)
          OR EXISTS(SELECT 1 FROM watch_history h WHERE h.contentId = c.id)
          OR EXISTS(SELECT 1 FROM bookmarks b WHERE b.contentId = c.id))
        AND (instr(lower(c.title), lower(:keyword)) > 0 OR instr(lower(c.creatorName), lower(:keyword)) > 0
          OR EXISTS(SELECT 1 FROM bookmarks b WHERE b.contentId = c.id
            AND (instr(lower(b.title), lower(:keyword)) > 0 OR instr(lower(b.note), lower(:keyword)) > 0))
          OR EXISTS(SELECT 1 FROM collection_items i WHERE i.contentId = c.id AND instr(lower(i.note), lower(:keyword)) > 0))
        ORDER BY c.publishedAtMs DESC, c.id LIMIT :limit OFFSET :offset""")
    fun searchLibrary(keyword: String, limit: Int = 100, offset: Int = 0): Flow<List<ContentEntity>>

    @Insert suspend fun insertReceipt(receipt: MigrationReceiptEntity)
    @Query("SELECT * FROM migration_receipts WHERE id = :id") suspend fun receipt(id: String): MigrationReceiptEntity?
    @Insert suspend fun insertRecovery(row: LegacyRecoveryEntity)
    @Query("SELECT * FROM legacy_recovery ORDER BY id") suspend fun recoveryRows(): List<LegacyRecoveryEntity>
}
