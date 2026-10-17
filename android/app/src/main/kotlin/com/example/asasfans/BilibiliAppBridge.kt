package com.example.asasfans

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/// Opens a Bilibili web link in the Bilibili app by naming its package.
///
/// Since Android 12 an https link goes only to an app verified for its domain,
/// and the Bilibili app is not, so the system sends its links to the browser.
/// An intent addressed to the package is not a generic web intent and still
/// reaches the app's own link filters. Only Bilibili's https domains are
/// accepted; anything else, or no Bilibili app, answers false and the caller
/// opens the browser.
class BilibiliAppBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    companion object {
        /// The main app, then 概念版, HD and the international build.
        private val packages = listOf(
            "tv.danmaku.bili",
            "com.bilibili.app.blue",
            "tv.danmaku.bilibilihd",
            "com.bilibili.app.in",
        )
    }

    private val channel = MethodChannel(messenger, "asasfans.next/bilibili_app")

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "open") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val uri = call.argument<String>("url")?.let(Uri::parse)
            result.success(uri != null && bilibiliWeb(uri) && open(uri))
        }
    }

    private fun bilibiliWeb(uri: Uri): Boolean {
        val host = uri.host?.lowercase() ?: return false
        return uri.scheme == "https" &&
            uri.userInfo == null &&
            (host == "bilibili.com" || host.endsWith(".bilibili.com") || host == "b23.tv")
    }

    private fun open(uri: Uri): Boolean = packages.any { name ->
        try {
            activity.startActivity(Intent(Intent.ACTION_VIEW, uri).setPackage(name))
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
