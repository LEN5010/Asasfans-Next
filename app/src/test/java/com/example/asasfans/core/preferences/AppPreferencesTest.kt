package com.example.asasfans.core.preferences

import android.app.Application
import android.content.Context
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.test.core.app.ApplicationProvider
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelAndJoin
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
class AppPreferencesTest {
    private lateinit var context: Context
    private lateinit var scope: CoroutineScope
    private lateinit var file: File
    private lateinit var preferences: AppPreferences
    @Before fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        file = File(context.filesDir, "test-${System.nanoTime()}.preferences_pb")
        preferences = AppPreferences(PreferenceDataStoreFactory.create(scope = scope, produceFile = { file }))
    }
    @After fun tearDown() = runBlocking {
        scope.coroutineContext[Job]!!.cancelAndJoin()
        file.delete()
        Unit
    }

    @Test fun importsLegacyValuesExactlyOnceAndDoesNotOverrideNewPreferences() = runBlocking {
        context.getSharedPreferences("video_playback_mode", Context.MODE_PRIVATE).edit().putString("mode", "external").commit()
        val cache = File(context.cacheDir, "ACache").apply { mkdirs() }
        File(cache, "isShowFloatingBall".hashCode().toString()).writeText("yes")
        File(cache, "toolsFragmentWebUrl".hashCode().toString()).writeText("2")
        preferences.setTheme(ThemeMode.DARK)
        preferences.importLegacy(context)
        val state = preferences.state.first()
        assertEquals(PlaybackMode.EXTERNAL, state.playbackMode)
        assertEquals(ThemeMode.DARK, state.theme)
        assertTrue(state.floatingBall)
        assertEquals("https://studio.asoul.us.kg", state.lastTool)
        preferences.setPlaybackMode(PlaybackMode.APP)
        preferences.importLegacy(context)
        assertEquals(PlaybackMode.APP, preferences.state.first().playbackMode)
        // Clearing cache must not erase the already migrated preferences.
        cache.deleteRecursively()
        assertTrue(preferences.state.first().floatingBall)
    }
    @Test fun newInstallDefaultsAreQuietAndDoNotRequireOverlayPermission() = runBlocking {
        preferences.importLegacy(context)
        val state = preferences.state.first()
        assertFalse(state.floatingBall)
        assertEquals(ThemeMode.SYSTEM, state.theme)
        assertEquals(PlaybackMode.APP, state.playbackMode)
    }
}
