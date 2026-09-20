package com.example.asasfans.core.database

import android.app.Application
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import java.io.File
import java.io.IOException
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class LegacyImporterTest {
    private lateinit var db: AsasDatabase
    private lateinit var legacy: File

    @Before fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        db = Room.inMemoryDatabaseBuilder(context, AsasDatabase::class.java).build()
        legacy = File(context.cacheDir, "legacy-${System.nanoTime()}.db")
    }
    @After fun tearDown() { db.close(); legacy.delete() }

    @Test fun importsEveryLegacyVersionWithoutChangingSource() = runBlocking {
        for (version in 1..4) {
            fixture(version)
            val original = legacy.readBytes()
            val receipt = LegacyImporter(db, legacy, nowMs = { 1234 }).importIfNeeded()
            assertEquals(version, receipt.sourceVersion)
            assertEquals(when (version) { 1 -> 1; 2 -> 3; 3 -> 5; else -> 8 }, receipt.rowCount)
            val content = db.assets().content("bilibili:BV1MBeq6rEz2")!!
            assertEquals("历史标题", content.title)
            assertEquals(42_000L, content.durationMs)
            if (version >= 3) {
                val up = db.assets().allSubscriptions().single()
                assertEquals("昵称", up.name)
                assertEquals("备注,保留", up.note)
                assertEquals(1_700_000_000_000, up.updatedAtMs)
            }
            assertArrayEquals(original, legacy.readBytes())
            withContext(Dispatchers.IO) { db.clearAllTables() }
            legacy.delete()
        }
    }

    @Test fun interruptionRollsBackReceiptAndDataAndCanRetry() = runBlocking {
        fixture(3)
        try {
            LegacyImporter(db, legacy, afterRow = { if (it == 2) throw IOException("simulated disk failure") }).importIfNeeded()
            fail("must propagate write failure")
        } catch (_: IOException) { }
        assertNull(db.assets().receipt(LegacyImporter.RECEIPT_ID))
        assertTrue(db.assets().allRules().isEmpty())
        assertTrue(db.assets().allSubscriptions().isEmpty())
        assertEquals(5, LegacyImporter(db, legacy).importIfNeeded().rowCount)
    }

    @Test fun repeatingMigrationDoesNotResurrectDeletedRulesOrOverwriteNewNotes() = runBlocking {
        fixture(3)
        val importer = LegacyImporter(db, legacy)
        importer.importIfNeeded()
        db.assets().allRules().forEach { db.assets().deleteRule(it.id) }
        val subscription = db.assets().allSubscriptions().single()
        db.assets().putSubscription(subscription.copy(note = "2.0 新备注"))
        importer.importIfNeeded()
        assertTrue(db.assets().allRules().isEmpty())
        assertEquals("2.0 新备注", db.assets().allSubscriptions().single().note)
    }

    @Test fun invalidHistoricalRowsArePreservedNotDropped() = runBlocking {
        fixture(3)
        SQLiteDatabase.openDatabase(legacy.path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("INSERT INTO blackMid(mid) VALUES ('invalid-overflow-uid')")
        }
        val receipt = LegacyImporter(db, legacy).importIfNeeded()
        assertEquals(6, receipt.rowCount)
        assertTrue(db.assets().recoveryRows().single().rowJson.contains("invalid-overflow-uid"))
        assertEquals(4, db.assets().allRules().size)
    }

    @Test fun corruptDatabaseMustNotMarkMigrationComplete() = runBlocking {
        legacy.writeText("not a sqlite database")
        try { LegacyImporter(db, legacy).importIfNeeded(); fail("must not treat corruption as empty install") }
        catch (_: android.database.sqlite.SQLiteException) { }
        assertNull(db.assets().receipt(LegacyImporter.RECEIPT_ID))
    }

    @Test fun newInstallGetsAnAtomicEmptyReceipt() = runBlocking {
        val receipt = LegacyImporter(db, legacy).importIfNeeded()
        assertEquals(0, receipt.sourceVersion)
        assertEquals(receipt, db.assets().receipt(LegacyImporter.RECEIPT_ID))
        assertFalse(legacy.exists())
    }

    @Test fun v4UpdateCacheAndSeenFlagsArePreservedWithoutBecomingWatchHistory() = runBlocking {
        fixture(4)
        val original = legacy.readBytes()
        val importer = LegacyImporter(db, legacy)
        assertEquals(8, importer.importIfNeeded().rowCount)
        val recovered = db.assets().recoveryRows()
        assertEquals(3, recovered.size)
        val videos = recovered.filter { it.tableName == "subscriptionUpdateVideo" }
        assertEquals(2, videos.size)
        assertTrue(videos.any { it.rowJson.contains("\"seen\":\"1\"") })
        assertTrue(videos.any { it.rowJson.contains("\"seen\":\"0\"") })
        assertEquals(1, recovered.count { it.tableName == "subscriptionUpdateStatus" })
        assertTrue(db.assets().history().first().isEmpty())
        importer.importIfNeeded()
        assertEquals(3, db.assets().recoveryRows().size)
        assertArrayEquals(original, legacy.readBytes())
    }

    @Test fun unknownFutureVersionsRemainProtectedAndNeverGetAReceipt() = runBlocking {
        fixture(5)
        val original = legacy.readBytes()
        try { LegacyImporter(db, legacy).importIfNeeded(); fail("unsupported schema must not be silently accepted") }
        catch (error: UnsupportedLegacyVersion) { assertEquals(5, error.version) }
        assertNull(db.assets().receipt(LegacyImporter.RECEIPT_ID))
        assertTrue(db.assets().allSubscriptions().isEmpty())
        assertArrayEquals(original, legacy.readBytes())
    }

    private fun fixture(version: Int) {
        SQLiteDatabase.openOrCreateDatabase(legacy, null).use { old ->
            old.version = version
            old.execSQL("CREATE TABLE blackBvid(bvid TEXT PRIMARY KEY, PicUrl TEXT, Title TEXT, Duration INTEGER, Author TEXT, ViewNum INTEGER, LikeNum INTEGER, Tname TEXT)")
            old.execSQL("INSERT INTO blackBvid VALUES ('BV1MBeq6rEz2', 'https://example.com/cover', '历史标题', 42, '作者', 100, 3, '音乐')")
            if (version >= 2) {
                old.execSQL("CREATE TABLE blackMid(mid)")
                old.execSQL("INSERT INTO blackMid VALUES (123)")
                old.execSQL("CREATE TABLE blackTag(tag TEXT PRIMARY KEY)")
                old.execSQL("INSERT INTO blackTag VALUES ('切片')")
            }
            if (version >= 3) {
                old.execSQL("CREATE TABLE blackWord(word TEXT PRIMARY KEY)")
                old.execSQL("INSERT INTO blackWord VALUES ('屏蔽词')")
                old.execSQL("CREATE TABLE subscribedUp(mid INTEGER PRIMARY KEY, name TEXT, face TEXT, note TEXT, updatedAt INTEGER)")
                old.execSQL("INSERT INTO subscribedUp VALUES (456, '昵称', 'https://example.com/avatar', '备注,保留', 1700000000)")
            }
            if (version >= 4) {
                old.execSQL("CREATE TABLE subscriptionUpdateVideo(bvid TEXT PRIMARY KEY, title TEXT, cover TEXT, owner_name TEXT, owner_mid INTEGER, pubdate INTEGER, duration TEXT, view_count INTEGER, like_count INTEGER, tname TEXT, seen INTEGER, synced_at INTEGER)")
                old.execSQL("INSERT INTO subscriptionUpdateVideo VALUES ('BV1xx411c7mA', '合成更新甲', '', '昵称', 456, 1700000000, '1:30', 42, 3, '音乐', 1, 1700000010)")
                old.execSQL("INSERT INTO subscriptionUpdateVideo VALUES ('BV1xx411c7mB', '合成更新乙', '', '昵称', 456, 1700000001, '0:30', 20, 2, '音乐', 0, 1700000010)")
                old.execSQL("CREATE TABLE subscriptionUpdateStatus(id INTEGER PRIMARY KEY, syncing INTEGER, last_synced_at INTEGER, last_message TEXT, last_error TEXT, last_new_count INTEGER, last_total_count INTEGER, subscribed_up_count INTEGER)")
                old.execSQL("INSERT INTO subscriptionUpdateStatus VALUES (1, 0, 1700000010, '合成状态', '', 1, 2, 1)")
            }
        }
    }
}
