package com.example.asasfans

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/// Connects the return overlay to Flutter over its own channel.
///
/// Deliberately not part of the login cookie channel. That one owns an isolated
/// WebView store for Bilibili sign-in; giving it an overlay service, or giving
/// the overlay its cookie reach, would hand each the other's permissions for no
/// reason beyond both being native.
///
/// The bridge starts and stops a service and forwards taps. It does not know
/// what the user is doing, does not query running packages, and never brings
/// the app forward on its own: only a user tap does that.
class ReturnEntryBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    companion object {
        private const val CHANNEL = "asasfans.next/return_entry"
    }

    private val methods = MethodChannel(messenger, CHANNEL)
    private val events = EventChannel(messenger, "$CHANNEL/taps")
    private var taps: EventChannel.EventSink? = null

    init {
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "capability" -> result.success(capability())
                "requestPermission" -> {
                    requestPermission()
                    result.success(null)
                }
                "show" -> {
                    val session = call.argument<String>("sessionId")
                    if (session.isNullOrEmpty()) {
                        result.success(false)
                    } else {
                        result.success(show(session))
                    }
                }
                "hide" -> {
                    hide()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                taps = sink
                ReturnOverlayService.onTap = { session ->
                    // The tap arrives on the service's thread; channel calls
                    // must be made on the UI thread.
                    activity.runOnUiThread {
                        bringForward()
                        taps?.success(session)
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                ReturnOverlayService.onTap = null
                taps = null
            }
        })
    }

    /// What this device can actually do, distinguishing an OS that has no
    /// suitable overlay window type from a permission the user can still grant.
    ///
    /// API 24 and 25 report [osTooOld] rather than silently borrowing the
    /// API 26 window type. The plan is explicit that the app's own minSdk must
    /// not be raised for this enhancement, and that ordinary handoff and system
    /// return keep working without it.
    private fun capability(): Map<String, Any?> = when {
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ->
            mapOf("available" to false, "block" to "osTooOld")
        !Settings.canDrawOverlays(activity) ->
            mapOf("available" to false, "block" to "permissionMissing")
        else -> mapOf("available" to true, "block" to null)
    }

    private fun requestPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            activity.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${activity.packageName}"),
                )
            )
        } catch (_: Exception) {
            // No settings activity to open. Capability is re-read by the caller
            // regardless, so the state stays truthful.
        }
    }

    /// Starts the overlay while the app is still in the foreground.
    ///
    /// Called before the handoff is dispatched, because a newer Android will
    /// not let an overlay-backed foreground service start from the background.
    /// A refusal returns false and the handoff proceeds without an entry.
    private fun show(session: String): Boolean {
        if (!ReturnOverlayService.canDraw(activity)) return false
        return try {
            activity.startService(
                Intent(activity, ReturnOverlayService::class.java)
                    .setAction(ReturnOverlayService.ACTION_SHOW)
                    .putExtra(ReturnOverlayService.EXTRA_SESSION, session)
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun hide() {
        try {
            activity.startService(
                Intent(activity, ReturnOverlayService::class.java)
                    .setAction(ReturnOverlayService.ACTION_HIDE)
            )
        } catch (_: Exception) {
            // Nothing running to stop.
        }
    }

    /// Brings this app's own task forward. Only ever called from a user tap on
    /// the entry, never on a timer or a background event.
    private fun bringForward() {
        try {
            activity.startActivity(
                Intent(activity, MainActivity::class.java)
                    .setAction(Intent.ACTION_MAIN)
                    .addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                    )
            )
        } catch (_: Exception) {
            // The task could not be brought forward; the tap is still reported
            // so the app restores its context when the user arrives by hand.
        }
    }

    fun dispose() {
        ReturnOverlayService.onTap = null
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        taps = null
        hide()
    }
}

/// Convenience for the activity, keeping the context requirement explicit.
fun Context.returnEntryAvailable(): Boolean = ReturnOverlayService.canDraw(this)
