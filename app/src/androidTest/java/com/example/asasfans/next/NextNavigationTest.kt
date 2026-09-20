package com.example.asasfans.next

import androidx.compose.ui.test.*
import android.content.pm.ActivityInfo
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import com.example.asasfans.core.data.StartupState
import com.example.asasfans.core.model.*
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.Assert.assertTrue
import kotlin.math.abs

class NextNavigationTest {
    @get:Rule val compose = createAndroidComposeRule<NextActivity>()

    @Test fun nativeLibraryNavigationAndRecreationPreserveStoredContent() {
        val app = ApplicationProvider.getApplicationContext<NextApplication>()
        compose.waitUntil(10_000) { app.container.startup.state.value == StartupState.Ready }
        val video = Video(ContentId.bilibili("BV1xx411c7mD"), "本地界面合成测试", Creator(id = "42", name = "测试 UP"), durationMs = 60_000)
        runBlocking { app.container.library.addWatchLater(video) }
        try {
            compose.onAllNodesWithText("资料库").onLast().performClick()
            compose.waitUntil(5000) { compose.onAllNodesWithText(video.title).fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithText(video.title).assertIsDisplayed()
            compose.activityRule.scenario.recreate()
            compose.waitUntil(5000) { compose.onAllNodesWithText(video.title).fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithText(video.title).assertIsDisplayed()
            compose.onAllNodesWithText("我的").onLast().performClick()
            compose.onNodeWithText("扫码登录").assertIsDisplayed()
            compose.onNodeWithText("订阅管理").performScrollTo().performClick()
            compose.onNodeWithContentDescription("添加订阅").assertIsDisplayed()
        } finally { runBlocking { app.container.library.removeWatchLater(video.id.key) } }
    }

    @Test fun centerToolsOpensAnIconGridAndSubscriptionsLiveUnderMine() {
        val app = ApplicationProvider.getApplicationContext<NextApplication>()
        compose.waitUntil(10_000) { app.container.startup.state.value == StartupState.Ready }
        compose.onNodeWithTag("tools-button").performClick()
        compose.onNodeWithTag("tools-grid").assertIsDisplayed()
        compose.onNodeWithText("社区导航").assertIsDisplayed()
        compose.onNodeWithText("录音棚").assertIsDisplayed()
        compose.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        compose.onNodeWithTag("tools-grid").assertDoesNotExist()
        compose.onAllNodesWithText("我的").onLast().performClick()
        compose.onNodeWithText("网页登录").assertIsDisplayed()
        compose.onNodeWithText("社区导航").assertDoesNotExist()
        compose.onNodeWithText("订阅管理").performScrollTo().performClick()
        compose.onNodeWithText("订阅管理").assertIsDisplayed()
        compose.onNodeWithContentDescription("添加订阅").assertIsDisplayed()
    }

    @Test fun videoCreatorActionOpensNativeProfileWithoutOpeningPlayback() {
        val app = ApplicationProvider.getApplicationContext<NextApplication>()
        compose.waitUntil(10_000) { app.container.startup.state.value == StartupState.Ready }
        val video = Video(ContentId.bilibili("BV1xx411c7mZ"), "主页入口合成视频", Creator(id = "42", name = "主页合成 UP"))
        runBlocking { app.container.library.addWatchLater(video) }
        try {
            compose.onAllNodesWithText("资料库").onLast().performClick()
            compose.onNodeWithText(video.title).assertIsDisplayed()
            compose.onNodeWithText(video.creator.name).performClick()
            compose.onNodeWithText("UP 主页").assertIsDisplayed()
            compose.onNodeWithText("UID 42").assertIsDisplayed()
            compose.onNodeWithContentDescription("在 B 站打开 UP 主页").assertIsDisplayed()
            compose.onNodeWithContentDescription("返回").performClick()
            compose.onNodeWithText(video.title).assertIsDisplayed()
        } finally { runBlocking { app.container.library.removeWatchLater(video.id.key) } }
    }

    @Test fun creatingCollectionUsesNewLocalRepository() {
        val app = ApplicationProvider.getApplicationContext<NextApplication>()
        compose.waitUntil(10_000) { app.container.startup.state.value == StartupState.Ready }
        compose.onAllNodesWithText("资料库").onLast().performClick()
        compose.onNodeWithText("收藏夹").performClick()
        compose.onNodeWithText("新建收藏夹").performClick()
        compose.onNodeWithText("名称").performTextInput("合成收藏夹")
        compose.onNodeWithText("创建").performClick()
        compose.waitUntil(5000) { compose.onAllNodesWithText("合成收藏夹").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("合成收藏夹").assertIsDisplayed()
        runBlocking {
            app.container.database.assets().allCollections().filter { it.name == "合成收藏夹" }.forEach { app.container.library.deleteCollection(it.id) }
        }
    }

    @Test fun compactGridSearchAndMenuRemainUsableWithoutInstructionalCopy() {
        val app = ApplicationProvider.getApplicationContext<NextApplication>()
        compose.waitUntil(10_000) { app.container.startup.state.value == StartupState.Ready }
        val first = Video(ContentId.bilibili("BV1xx411c7mA"), "布局回归甲", Creator(id = "42", name = "测试 UP"), durationMs = 60_000)
        val second = Video(ContentId.bilibili("BV1xx411c7mB"), "布局回归乙", Creator(id = "43", name = "另一位 UP"), durationMs = 120_000)
        runBlocking { app.container.library.addWatchLater(first); app.container.library.addWatchLater(second) }
        try {
            compose.onAllNodesWithText("资料库").onLast().performClick()
            compose.waitUntil(5000) { compose.onAllNodesWithText(first.title).fetchSemanticsNodes().isNotEmpty() }
            val a = compose.onNodeWithText(first.title).fetchSemanticsNode().boundsInRoot
            val b = compose.onNodeWithText(second.title).fetchSemanticsNode().boundsInRoot
            assertTrue("Compact cards must occupy two columns", abs(a.top - b.top) < 2f && abs(a.left - b.left) > a.width / 2)
            compose.onNodeWithText("本地收藏、历史与书签不随 B 站账号退出而删除。").assertDoesNotExist()
            compose.onAllNodes(hasSetTextAction()).assertCountEquals(0)
            compose.onNodeWithContentDescription("搜索资料库").performClick()
            compose.onNode(hasSetTextAction()).performTextInput(first.title)
            compose.onNodeWithText("搜索").performClick()
            compose.waitUntil(5000) { compose.onAllNodesWithText(second.title).fetchSemanticsNodes().isEmpty() }
            compose.onAllNodesWithText(first.title).onLast().assertIsDisplayed()
            compose.onNodeWithContentDescription("视频操作").performClick()
            compose.onNodeWithText("加入稍后看").assertIsDisplayed()
        } finally {
            runBlocking { app.container.library.removeWatchLater(first.id.key); app.container.library.removeWatchLater(second.id.key) }
        }
    }


    @Test fun libraryScrollSurvivesTabReturnAndActivityRecreation() {
        val app = ApplicationProvider.getApplicationContext<NextApplication>()
        compose.waitUntil(10_000) { app.container.startup.state.value == StartupState.Ready }
        val videos = (800..823).map { index ->
            Video(ContentId.bilibili("BV1xx411c$index"), "滚动恢复记录 $index", Creator(id = "42", name = "测试 UP"))
        }
        runBlocking { videos.forEach { app.container.library.addWatchLater(it) } }
        try {
            compose.onAllNodesWithText("资料库").onLast().performClick()
            compose.waitUntil(5000) { compose.onAllNodesWithText(videos.last().title).fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithTag("library-grid").performScrollToNode(hasText(videos.first().title))
            compose.onNodeWithText(videos.first().title).assertIsDisplayed()
            compose.onAllNodesWithText("我的").onLast().performClick()
            compose.onAllNodesWithText("资料库").onLast().performClick()
            compose.onNodeWithText(videos.first().title).assertIsDisplayed()
            compose.activityRule.scenario.recreate()
            compose.waitUntil(5000) { compose.onAllNodesWithText(videos.first().title).fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithText(videos.first().title).assertIsDisplayed()
        } finally {
            runBlocking { videos.forEach { app.container.library.removeWatchLater(it.id.key) } }
        }
    }


    @Test fun landscapeNavigationKeepsAllFiveDestinationsReachable() {
        val app = ApplicationProvider.getApplicationContext<NextApplication>()
        compose.waitUntil(10_000) { app.container.startup.state.value == StartupState.Ready }
        try {
            compose.activityRule.scenario.onActivity { it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE }
            compose.waitUntil(5000) { compose.onAllNodesWithTag("side-navigation").fetchSemanticsNodes().isNotEmpty() }
            listOf("今日", "发现", "工具", "资料库", "我的").forEach { label ->
                compose.onAllNodesWithText(label).onLast().assertIsDisplayed()
            }
            compose.onAllNodesWithText("我的").onLast().performClick()
            compose.onNodeWithText("扫码登录").assertIsDisplayed()
        } finally {
            compose.activityRule.scenario.onActivity { it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED }
        }
    }

}
