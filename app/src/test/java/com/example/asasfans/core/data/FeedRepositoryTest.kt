package com.example.asasfans.core.data

import android.app.Application
import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.example.asasfans.core.database.AsasDatabase
import com.example.asasfans.core.database.RuleEntity
import com.example.asasfans.core.model.*
import com.example.asasfans.core.network.VideoPage
import kotlinx.coroutines.CancellationException
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
class FeedRepositoryTest {
    private lateinit var db: AsasDatabase
    @Before fun setUp() { db = Room.inMemoryDatabaseBuilder(ApplicationProvider.getApplicationContext<Context>(), AsasDatabase::class.java).build() }
    @After fun tearDown() { db.close() }
    private fun videos(page: Int) = (0..19).map { index -> Video(ContentId.bilibili("page-$page-$index"),
        "视频 $index", Creator(id = "123"), publishedAtMs = (20 - index).toLong()) }

    @Test fun refreshFailureKeepsCacheAndLoadMoreFailureDoesNotAdvanceCursor() = runBlocking {
        var fail = false
        val pages = mutableListOf<Int>()
        val repository = FeedRepository(db, "test", { _, page ->
            pages += page
            if (fail) throw AppFailure.Network()
            VideoPage(videos(page), page, 40, page < 2)
        }, awaitReady = {})
        val query = QuerySpec()
        repository.refresh(query)
        assertEquals(20, repository.observe(query).first().videos.size)
        fail = true
        repository.refresh(query)
        val failedRefresh = repository.observe(query).first()
        assertEquals(20, failedRefresh.videos.size)
        assertTrue(failedRefresh.error is AppFailure.Network)
        repository.loadMore(query)
        assertEquals("2", db.feeds().syncState(repository.key(query))!!.cursor)
        fail = false
        repository.loadMore(query)
        assertEquals(listOf(1, 1, 2, 2), pages)
        assertEquals(40, repository.observe(query).first().videos.size)
        assertFalse(repository.observe(query).first().hasMore)
    }

    @Test fun filteringRefillIsBoundedAndExplainsEmptyResults() = runBlocking {
        db.assets().insertRule(RuleEntity("r", "CREATOR", "bilibili:123"))
        var requests = 0
        val repository = FeedRepository(db, "test", { _, page ->
            requests++; VideoPage(videos(page), page, 1000, true)
        }, awaitReady = {})
        repository.refresh(QuerySpec())
        assertEquals(5, requests)
        val state = repository.observe(QuerySpec()).first()
        assertTrue(state.videos.isEmpty())
        assertEquals(100, state.filteredCount)
        assertTrue(state.hasMore)
    }

    @Test fun sourceRankingIsNotAccidentallyReplacedByPublishDate() = runBlocking {
        val items = videos(1).reversed()
        val repository = FeedRepository(db, "test", { _, page -> VideoPage(items, page, 20, false) }, awaitReady = {})
        val query = QuerySpec(order = VideoOrder.POPULAR)
        repository.refresh(query)
        assertEquals(items.map { it.id }, repository.observe(query).first().videos.map { it.id })
    }

    @Test fun cancellationIsNotReportedAsNetworkErrorOrCommittedAsEmptySuccess() = runBlocking {
        val repository = FeedRepository(db, "test", { _, _ -> throw CancellationException("query changed") }, awaitReady = {})
        try { repository.refresh(QuerySpec()); fail("must propagate cancellation") } catch (_: CancellationException) { }
        assertNull(db.feeds().syncState(repository.key(QuerySpec())))
        val snapshot = repository.observe(QuerySpec()).first()
        assertFalse(snapshot.loading)
        assertNull(snapshot.error)
    }
}
