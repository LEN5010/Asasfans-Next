package com.example.asasfans.core.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [ContentEntity::class, SubscriptionEntity::class, RuleEntity::class, CollectionEntity::class,
        CollectionItemEntity::class, WatchLaterEntity::class, ProgressEntity::class, HistoryEntity::class,
        BookmarkEntity::class, ChannelEntity::class, FeedEntryEntity::class, SyncStateEntity::class,
        MigrationReceiptEntity::class, LegacyRecoveryEntity::class],
    version = 1, exportSchema = true,
)
abstract class AsasDatabase : RoomDatabase() {
    abstract fun assets(): AssetDao
    abstract fun feeds(): FeedDao

    companion object {
        fun open(context: Context): AsasDatabase = Room.databaseBuilder(
            context.applicationContext, AsasDatabase::class.java, "asasfans.db",
        ).build()
    }
}
