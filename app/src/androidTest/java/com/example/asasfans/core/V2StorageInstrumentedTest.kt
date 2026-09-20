package com.example.asasfans.core

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.asasfans.core.data.LibraryRepository
import com.example.asasfans.core.database.AsasDatabase
import com.example.asasfans.core.database.LegacyImporter
import com.example.asasfans.core.model.ContentId
import com.example.asasfans.core.model.Creator
import com.example.asasfans.core.model.Video
import java.io.File
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class V2StorageInstrumentedTest {
    @Test fun realSqliteMigrationAndLibrarySurviveClosingDatabase() = runBlocking {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val name = "v2-instrumentation-${System.nanoTime()}.db"
        val legacy = File(context.cacheDir, "legacy-${System.nanoTime()}.db")
        fun open() = Room.databaseBuilder(context, AsasDatabase::class.java, name).build()
        SQLiteDatabase.openOrCreateDatabase(legacy, null).use {
            it.version = 3
            it.execSQL("CREATE TABLE blackWord(word TEXT PRIMARY KEY)")
            it.execSQL("INSERT INTO blackWord VALUES ('测试屏蔽')")
            it.execSQL("CREATE TABLE subscribedUp(mid INTEGER PRIMARY KEY, name TEXT, face TEXT, note TEXT, updatedAt INTEGER)")
            it.execSQL("INSERT INTO subscribedUp VALUES (123, '迁移昵称', '', '迁移备注', 1700000000)")
        }
        val video = Video(ContentId.bilibili("BV1MBeq6rEz2"), "测试收藏", Creator(id = "123"))
        var database = open()
        try {
            val importer = LegacyImporter(database, legacy)
            val repository = LibraryRepository(database, awaitReady = { importer.importIfNeeded(); Unit })
            repository.addWatchLater(video)
            repository.recordProgress(video, 7, 12_000, 90_000)
            assertEquals("迁移备注", database.assets().allSubscriptions().single().note)
            assertEquals(1, database.assets().allRules().size)
            database.close()
            database = open()
            val restored = LibraryRepository(database, awaitReady = { LegacyImporter(database, legacy).importIfNeeded(); Unit })
            assertEquals(video.id.key, restored.watchLater.first().single().id)
            assertEquals(12_000L, restored.progress(video.id.key, 7)!!.positionMs)
            restored.clearFeedCache()
            assertEquals(1, restored.watchLater.first().size)
            assertEquals(1, database.assets().allRules().size)
            assertTrue(legacy.exists())
        } finally {
            database.close()
            context.deleteDatabase(name)
            legacy.delete()
        }
    }
}
