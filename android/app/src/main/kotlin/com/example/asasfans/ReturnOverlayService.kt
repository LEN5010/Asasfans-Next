package com.example.asasfans

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import kotlin.math.abs

/// One small button that brings this app back to the foreground.
///
/// It shows a single draggable circle and nothing else. It does not read the
/// screen, does not know which app is in front, and holds no content: the
/// session id it carries is opaque to it. Everything the user came back to is
/// rebuilt by the app itself.
///
/// The service is started from the app's own foreground while the user is
/// still looking at it, which is what a newer Android requires before an
/// overlay-backed service may run.
class ReturnOverlayService : Service() {
    companion object {
        const val EXTRA_SESSION = "session"
        const val ACTION_SHOW = "show"
        const val ACTION_HIDE = "hide"

        /// Set by the bridge so a tap can be delivered without binding. The
        /// service holds no reference to Flutter itself.
        @Volatile
        var onTap: ((String) -> Unit)? = null

        private const val CHANNEL = "return_entry"
        private const val NOTIFICATION = 0x4153

        fun canDraw(context: Context): Boolean =
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                Settings.canDrawOverlays(context)
    }

    private var windows: WindowManager? = null
    private var ball: View? = null
    private var session: String? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_HIDE -> {
                teardown()
                return START_NOT_STICKY
            }
            ACTION_SHOW -> {
                val id = intent.getStringExtra(EXTRA_SESSION)
                if (id.isNullOrEmpty() || !canDraw(this)) {
                    teardown()
                    return START_NOT_STICKY
                }
                session = id
                startForeground(NOTIFICATION, notification())
                attach()
            }
            else -> {
                teardown()
                return START_NOT_STICKY
            }
        }
        // Never STICKY: a session that the system killed is over. Recreating a
        // return entry for a trip the user has long finished would put a button
        // on screen with nothing behind it.
        return START_NOT_STICKY
    }

    private fun notification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            manager.getNotificationChannel(CHANNEL) == null
        ) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    getString(R.string.return_entry_channel),
                    NotificationManager.IMPORTANCE_LOW,
                )
            )
        }
        // The notification is itself a way back and a way to stop, so the
        // feature is never something the user cannot get out of.
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .setAction(Intent.ACTION_MAIN)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, ReturnOverlayService::class.java).setAction(ACTION_HIDE),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return Notification.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_menu_revert)
            .setContentTitle(getString(R.string.return_entry_title))
            .setContentText(getString(R.string.return_entry_text))
            .setContentIntent(open)
            .addAction(
                Notification.Action.Builder(
                    null,
                    getString(R.string.return_entry_stop),
                    stop,
                ).build()
            )
            .setOngoing(true)
            .build()
    }

    private fun attach() {
        if (ball != null) return
        val manager = getSystemService(WindowManager::class.java) ?: return
        windows = manager
        val size = (56 * resources.displayMetrics.density).toInt()
        val view = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_revert)
            setBackgroundResource(R.drawable.return_entry_ball)
            contentDescription = getString(R.string.return_entry_title)
            val padding = (size * 0.22f).toInt()
            setPadding(padding, padding, padding, padding)
        }
        // Only the ball itself takes touches. A full-screen transparent window
        // would intercept input meant for whatever the user is actually using.
        val params = WindowManager.LayoutParams(
            size,
            size,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = resources.displayMetrics.widthPixels - size - (16 * resources.displayMetrics.density).toInt()
            y = resources.displayMetrics.heightPixels / 3
        }
        view.setOnTouchListener(DragToReturn(manager, params) {
            val id = session
            teardown()
            if (!id.isNullOrEmpty()) onTap?.invoke(id)
        })
        try {
            manager.addView(view, params)
            ball = view
        } catch (_: Exception) {
            // The window was refused. The handoff itself is unaffected: the
            // user returns through the app switcher as they otherwise would.
            teardown()
        }
    }

    private fun teardown() {
        val view = ball
        ball = null
        session = null
        if (view != null) {
            try {
                windows?.removeView(view)
            } catch (_: Exception) {
                // Already gone.
            }
        }
        windows = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        teardown()
        super.onDestroy()
    }

    /// Drags the ball, and treats a touch that barely moved as a tap.
    ///
    /// Positions are clamped to the current display, so a rotation or a split
    /// screen cannot leave the button off the edge where it can never be hit.
    private class DragToReturn(
        private val windows: WindowManager,
        private val params: WindowManager.LayoutParams,
        private val onTap: () -> Unit,
    ) : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var touchX = 0f
        private var touchY = 0f
        private var moved = false

        override fun onTouch(view: View, event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    moved = false
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - touchX
                    val dy = event.rawY - touchY
                    val slop = view.resources.displayMetrics.density * 8
                    if (abs(dx) > slop || abs(dy) > slop) moved = true
                    if (!moved) return true
                    val metrics = view.resources.displayMetrics
                    params.x = (startX + dx.toInt())
                        .coerceIn(0, metrics.widthPixels - view.width)
                    params.y = (startY + dy.toInt())
                        .coerceIn(0, metrics.heightPixels - view.height)
                    try {
                        windows.updateViewLayout(view, params)
                    } catch (_: Exception) {
                        // The window is gone; nothing to reposition.
                    }
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) {
                        view.performClick()
                        onTap()
                    }
                    return true
                }
            }
            return false
        }
    }
}
