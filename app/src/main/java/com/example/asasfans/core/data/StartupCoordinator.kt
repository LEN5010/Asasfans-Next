package com.example.asasfans.core.data

import com.example.asasfans.core.model.AppFailure
import com.example.asasfans.core.database.UnsupportedLegacyVersion
import android.database.sqlite.SQLiteFullException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

sealed interface StartupState {
    data object NotStarted : StartupState
    data object Migrating : StartupState
    data object Ready : StartupState
    data class Failed(val message: String, val failureType: String) : StartupState
}

/** Local readiness is independent of login, GitHub, CDN or any community service. */
class StartupCoordinator(
    private val importAssets: suspend () -> Unit,
    private val importPreferences: suspend () -> Unit,
) {
    private val mutex = Mutex()
    private val mutableState = MutableStateFlow<StartupState>(StartupState.NotStarted)
    val state = mutableState.asStateFlow()

    suspend fun initialize() = mutex.withLock {
        if (mutableState.value == StartupState.Ready) return@withLock
        mutableState.value = StartupState.Migrating
        try {
            importAssets()
            importPreferences()
            mutableState.value = StartupState.Ready
        } catch (error: CancellationException) {
            mutableState.value = StartupState.NotStarted
            throw error
        } catch (error: Exception) {
            mutableState.value = StartupState.Failed(
                when (error) {
                    is UnsupportedLegacyVersion -> "此版本暂不支持现有数据，请更新应用"
                    is SQLiteFullException -> "存储空间不足，请释放空间后重试"
                    else -> "无法读取本地数据，请重试"
                },
                error.javaClass.simpleName,
            )
        }
    }

    suspend fun requireReady() {
        if (mutableState.value != StartupState.Ready) throw AppFailure.LocalStorage()
    }
}
