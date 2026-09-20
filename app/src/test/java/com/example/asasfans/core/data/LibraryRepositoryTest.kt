package com.example.asasfans.core.data

import android.app.Application
import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.example.asasfans.core.database.*
import com.example.asasfans.core.model.*
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class LibraryRepositoryTest {
    private lateinit var db: AsasDatabase
    private lateinit var repository: LibraryRepository
    private val video = Video(ContentId.bilibili("BV1MBeq6rEz2"), "歌曲", Creator(id = "123", name = "UP"), tags = listOf("歌切"))
    @Before fun setUp() {
        db = Room.inMemoryDatabaseBuilder(ApplicationProvider.getApplicationContext<Context>(), AsasDatabase::class.java).build()
        repository = LibraryRepository(db, awaitReady = {}, nowMs = { 100 })
    }
    @After fun tearDown() { db.close() }

    @Test fun collectionDeletionDoesNotDeleteContentInOtherCollections() = runBlocking {
        val a = repository.createCollection("A"); val b = repository.createCollection("B")
        repository.saveToCollection(a, video); repository.saveToCollection(b, video)
        repository.saveToCollection(b, video)
        repository.deleteCollection(a)
        assertEquals(1, repository.collectionContents(b).first().size)
        assertNotNull(db.assets().content(video.id.key))
    }
    @Test fun cacheEvictionProtectsAllUserAssets() = runBlocking {
        repository.addWatchLater(video)
        val progressVideo = video.copy(id = ContentId.bilibili("progress"))
        val bookmarkVideo = video.copy(id = ContentId.bilibili("bookmark"))
        val cacheVideo = video.copy(id = ContentId.bilibili("cache-only"))
        repository.recordProgress(progressVideo, 1, 42_000, 100_000)
        repository.addBookmark(bookmarkVideo, 2, 7_000, "好听")
        db.assets().putContent(ContentEntity.from(cacheVideo, 1))
        db.feeds().putEntries(listOf(FeedEntryEntity("feed", cacheVideo.id.key, 1, 1)))
        repository.clearFeedCache()
        assertEquals(1, repository.watchLater.first().size)
        assertEquals(1, repository.bookmarks.first().size)
        assertEquals(42_000L, repository.progress(progressVideo.id.key, 1)!!.positionMs)
        assertNull(db.assets().content(cacheVideo.id.key))
    }
    @Test fun progressIsPartScopedAndHistoryDeletionDoesNotDeleteProgress() = runBlocking {
        repository.recordProgress(video, 1, 123, 1000)
        repository.recordProgress(video, 2, 456, 1000)
        repository.removeHistory(video.id.key)
        assertEquals(123L, repository.progress(video.id.key, 1)!!.positionMs)
        assertEquals(456L, repository.progress(video.id.key, 2)!!.positionMs)
        assertTrue(repository.history.first().isEmpty())
    }
    @Test fun bookmarkNotesAreSearchableAndUnknownTagsDoNotEraseKnownTags() = runBlocking {
        repository.addWatchLater(video)
        repository.addBookmark(video.copy(tags = null), 1, 0, "书签", "特别的备注")
        assertEquals(listOf("歌切"), db.assets().content(video.id.key)!!.toVideo().tags)
        assertEquals(video.id.key, repository.search("特别的备注").first().single().id)
    }
    @Test fun migrationGateFailurePreventsAnyMutation() = runBlocking {
        val locked = LibraryRepository(db, awaitReady = { error("Migration failed") })
        try { locked.addWatchLater(video); fail("must not write while migration failed") }
        catch (_: IllegalStateException) { }
        assertNull(db.assets().content(video.id.key))
    }
}
