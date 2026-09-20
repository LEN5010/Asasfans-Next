package com.example.asasfans.core.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext

private val Context.appPreferencesStore by preferencesDataStore(name = "asasfans_preferences")

enum class ThemeMode { SYSTEM, LIGHT, DARK }
enum class PlaybackMode { APP, EXTERNAL }

data class UserPreferences(
    val theme: ThemeMode = ThemeMode.SYSTEM,
    val playbackMode: PlaybackMode = PlaybackMode.APP,
    val playbackSpeed: Float = 1f,
    val floatingBall: Boolean = false,
    val lastTool: String = "https://cnki.asoul.us.kg",
    val hiddenHomeModules: Set<String> = emptySet(),
)

/** Construct once in the application container; never create a DataStore per screen. */
class AppPreferences(private val store: DataStore<Preferences>) {
    val state: Flow<UserPreferences> = store.data.map { values ->
        UserPreferences(
            enumValue(values[THEME], ThemeMode.SYSTEM), enumValue(values[PLAYBACK_MODE], PlaybackMode.APP),
            (values[SPEED] ?: 1f).takeIf { it.isFinite() && it in .25f..3f } ?: 1f,
            values[FLOATING_BALL] ?: false, values[LAST_TOOL] ?: LEGACY_TOOLS.first(),
            values[HIDDEN_HOME].orEmpty().split(',').filter(String::isNotBlank).toSet(),
        )
    }

    suspend fun setTheme(mode: ThemeMode) { store.edit { it[THEME] = mode.name } }
    suspend fun setPlaybackMode(mode: PlaybackMode) { store.edit { it[PLAYBACK_MODE] = mode.name } }
    suspend fun setPlaybackSpeed(speed: Float) {
        require(speed.isFinite() && speed in .25f..3f)
        store.edit { it[SPEED] = speed }
    }
    suspend fun setFloatingBall(enabled: Boolean) { store.edit { it[FLOATING_BALL] = enabled } }
    suspend fun setLastTool(url: String) { store.edit { it[LAST_TOOL] = url } }
    suspend fun setHiddenModules(ids: Set<String>) { store.edit { it[HIDDEN_HOME] = ids.sorted().joinToString(",") } }

    suspend fun importLegacy(context: Context) = withContext(Dispatchers.IO) {
        val app = context.applicationContext
        val legacyPlayback = app.getSharedPreferences("video_playback_mode", Context.MODE_PRIVATE).getString("mode", "app")
        val floating = LegacyCacheReader.read(File(app.cacheDir, "ACache"), "isShowFloatingBall") == "yes"
        val toolIndex = LegacyCacheReader.read(File(app.cacheDir, "ACache"), "toolsFragmentWebUrl")?.toIntOrNull()
        store.edit { values ->
            if (values[LEGACY_IMPORTED] == true) return@edit
            if (!values.contains(PLAYBACK_MODE)) values[PLAYBACK_MODE] = if (legacyPlayback == "external") PlaybackMode.EXTERNAL.name else PlaybackMode.APP.name
            if (!values.contains(FLOATING_BALL)) values[FLOATING_BALL] = floating
            if (!values.contains(LAST_TOOL)) values[LAST_TOOL] = LEGACY_TOOLS.getOrNull(toolIndex ?: -1) ?: LEGACY_TOOLS.first()
            values[LEGACY_IMPORTED] = true
        }
    }

    private inline fun <reified T : Enum<T>> enumValue(value: String?, fallback: T): T = enumValues<T>().firstOrNull { it.name == value } ?: fallback

    companion object {
        fun open(context: Context) = AppPreferences(context.applicationContext.appPreferencesStore)
        private val THEME = stringPreferencesKey("theme")
        private val PLAYBACK_MODE = stringPreferencesKey("playback_mode")
        private val SPEED = floatPreferencesKey("playback_speed")
        private val FLOATING_BALL = booleanPreferencesKey("floating_ball")
        private val LAST_TOOL = stringPreferencesKey("last_tool")
        private val HIDDEN_HOME = stringPreferencesKey("hidden_home_modules")
        private val LEGACY_IMPORTED = booleanPreferencesKey("legacy_imported")
        private val LEGACY_TOOLS = listOf(
            "https://cnki.asoul.us.kg", "https://nav.asoul.us.kg", "https://studio.asoul.us.kg",
            "https://book.asoul.us.kg", "https://cnki.asoul.us.kg/rank", "https://wiki.asoul.us.kg/",
            "https://nf.asoul-rec.com", "https://www.bilitools.top/t/4/", "https://zimu.live/",
            "https://aicu.cc", "https://vtbs.moe",
        )
    }
}

/** Minimal, read-only decoding of ACache's historical string format, not reuse of ACache. */
internal object LegacyCacheReader {
    fun read(directory: File, key: String, nowMs: Long = System.currentTimeMillis()): String? {
        val file = File(directory, key.hashCode().toString())
        if (!file.isFile || file.length() > 4096) return null
        val value = file.readText(Charsets.UTF_8)
        val date = Regex("^(\\d{13})-(\\d+) (.*)$", RegexOption.DOT_MATCHES_ALL).matchEntire(value) ?: return value
        val writtenAt = date.groupValues[1].toLongOrNull() ?: return null
        val ttl = date.groupValues[2].toLongOrNull() ?: return null
        if (ttl < 0 || ttl > (Long.MAX_VALUE - writtenAt) / 1000) return null
        return date.groupValues[3].takeIf { nowMs <= writtenAt + ttl * 1000 }
    }
}
