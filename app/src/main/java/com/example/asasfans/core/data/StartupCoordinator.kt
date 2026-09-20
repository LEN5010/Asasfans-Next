package com.example.asasfans.core.data

import com.example.asasfans.core.model.AppFailure
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
                "本地数据初始化未完成，旧数据未删除。请检查存储空间后重试。",
                error.javaClass.simpleName,
            )
        }
    }

    suspend fun requireReady() {
        if (mutableState.value != StartupState.Ready) throw AppFailure.LocalStorage()
    }
}
