package com.example.asasfans

import android.annotation.SuppressLint
import android.app.Application
import android.content.Context
import coil.Coil
import coil.ImageLoader
import coil.disk.DiskCache
import coil.memory.MemoryCache
import coil.request.CachePolicy
import coil.transform.RoundedCornersTransformation
import java.io.File

class AsApplication : Application() {
    companion object {
        @SuppressLint("StaticFieldLeak")
        lateinit var context: Context

        @JvmStatic
        fun getStatusBarHeight(): Int {
            val resourceId = context.resources.getIdentifier("status_bar_height", "dimen", "android")
            return if (resourceId > 0) {
                context.resources.getDimensionPixelSize(resourceId)
            } else 0
        }
    }

    override fun onCreate() {
        super.onCreate()
        context = applicationContext

        // Coil ImageLoader with same config as previous universal-image-loader
        val imageLoader = ImageLoader.Builder(this)
            .memoryCache {
                MemoryCache.Builder(this)
                    .maxSizePercent(0.25)
                    .build()
            }
            .diskCache {
                val cacheDir = File(externalCacheDir ?: cacheDir, "pic")
                DiskCache.Builder()
                    .directory(cacheDir)
                    .maxSizeBytes(500 * 1024 * 1024) // 500 MB
                    .build()
            }
            .crossfade(1000)
            .build()
        Coil.setImageLoader(imageLoader)
    }
}
