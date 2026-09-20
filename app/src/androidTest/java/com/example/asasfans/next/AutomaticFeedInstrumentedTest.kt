package com.example.asasfans.next

import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.unit.dp
import com.example.asasfans.core.data.FeedSnapshot
import com.example.asasfans.core.model.*
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/** UI-only fixtures; never replace or clear the installed app's databases. */
class AutomaticFeedInstrumentedTest {
    @get:Rule val compose = createAndroidComposeRule<NextActivity>()
    private fun batch(count: Int) = (0 until count).map { Video(ContentId.bilibili("fixture-$it"), "合成条目 $it", Creator(id = "42")) }
    private fun initial() = FeedSnapshot(videos = batch(40), queryKey = "fixture", cursor = "3", loadedCount = 40, updatedAtMs = 1)

    private fun mount(state: MutableState<FeedSnapshot>, requested: AtomicInteger, retries: AtomicInteger = AtomicInteger()) {
        compose.activityRule.scenario.onActivity { activity -> activity.setContent {
            MaterialTheme {
                val grid = rememberLazyGridState()
                AutoLoadFeed(grid, state.value) {
                    requested.incrementAndGet()
                    state.value = state.value.copy(loading = true, appending = true)
                }
                LazyVerticalGrid(GridCells.Fixed(2), state = grid, modifier = Modifier.fillMaxSize().testTag("auto-grid")) {
                    items(state.value.videos, key = { it.id.key }) { Text(it.title, Modifier.height(120.dp)) }
                    item(span = { GridItemSpan(maxLineSpan) }) {
                        FeedFooter(state.value, retry = { retries.incrementAndGet() }, continueLoading = {})
                    }
                }
            }
        } }
    }

    @Test fun scrollingLoadsSubsequentPagesWithoutButtonsAndDoesNotDuplicateRequests() {
        val state = mutableStateOf(initial())
        val requested = AtomicInteger()
        mount(state, requested)
        compose.waitForIdle()
        assertEquals(0, requested.get())
        compose.onNodeWithTag("auto-grid").performScrollToIndex(36)
        compose.waitUntil(5000) { requested.get() == 1 }
        compose.onNodeWithText("加载更多").assertDoesNotExist()
        compose.runOnIdle { state.value = state.value.copy(loading = false, appending = false, videos = batch(80), loadedCount = 80, cursor = "5") }
        compose.waitForIdle()
        assertEquals(1, requested.get())
        compose.onNodeWithTag("auto-grid").performScrollToIndex(76)
        compose.waitUntil(5000) { requested.get() == 2 }
        compose.runOnIdle { state.value = state.value.copy(loading = false, appending = false, hasMore = false) }
        compose.onNodeWithTag("auto-grid").performScrollToIndex(80)
        compose.onNodeWithText("没有更多了").assertIsDisplayed()
        assertEquals(2, requested.get())
    }

    @Test fun failedAppendKeepsVisibleContentAndWaitsForExplicitRetry() {
        val state = mutableStateOf(initial())
        val requested = AtomicInteger()
        val retries = AtomicInteger()
        mount(state, requested, retries)
        compose.onNodeWithTag("auto-grid").performScrollToIndex(36)
        compose.waitUntil(5000) { requested.get() == 1 }
        compose.runOnIdle { state.value = state.value.copy(loading = false, appending = false, error = AppFailure.Network(), failedAppend = true) }
        compose.onNodeWithTag("auto-grid").performScrollToIndex(40)
        compose.onNodeWithText("重试").assertIsDisplayed().performClick()
        compose.waitForIdle()
        assertEquals(1, retries.get())
        assertEquals(1, requested.get())
        assertEquals(40, state.value.videos.size)
    }
}
