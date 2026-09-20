package com.example.asasfans.next

import android.app.Application
import coil.Coil
import coil.ImageLoader
import com.example.asasfans.core.AppContainer
import com.example.asasfans.player.ProgressWriter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** The new graph owns no Activity/static Context; network is not a startup prerequisite. */
class NextApplication : Application() {
    val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    val container by lazy { AppContainer(this) }
    val progressWriter by lazy { ProgressWriter(applicationScope, container.library) }
    override fun onCreate() {
        super.onCreate()
        Coil.setImageLoader(ImageLoader.Builder(this).crossfade(true).build())
        applicationScope.launch { container.startup.initialize() }
        applicationScope.launch { container.account.initialize() }
    }
}
