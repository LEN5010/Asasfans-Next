package com.example.asasfans.player

import androidx.annotation.OptIn
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.ui.PlayerView
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.asasfans.bili.account.BiliCredentials
import com.example.asasfans.bili.content.MediaSegment
import com.example.asasfans.bili.content.PlaybackStreams
import com.example.asasfans.bili.network.BiliMediaDataSource
import com.example.asasfans.next.NextActivity
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import okio.Buffer
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Exercises real decoder/surface/Media3, independently of Bilibili availability or accounts. */
@OptIn(UnstableApi::class)
@RunWith(AndroidJUnit4::class)
class Media3PlaybackInstrumentedTest {
    @Test fun syntheticMp4RendersFirstFrameSeeksPausesAndReleases() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val bytes = instrumentation.context.assets.open("playback-test.mp4").use { it.readBytes() }
        val firstFrame = CountDownLatch(1)
        val ready = CountDownLatch(1)
        val failure = AtomicReference<MediaFailureKind?>(null)
        MockWebServer().use { server ->
            server.dispatcher = object : Dispatcher() {
                override fun dispatch(request: RecordedRequest): MockResponse {
                    val start = request.getHeader("Range")?.substringAfter("bytes=")?.substringBefore('-')?.toIntOrNull() ?: 0
                    if (start >= bytes.size) return MockResponse().setResponseCode(416)
                    return MockResponse().setResponseCode(if (request.getHeader("Range") == null) 200 else 206)
                        .setHeader("Content-Type", "video/mp4").setHeader("Accept-Ranges", "bytes")
                        .setHeader("Content-Range", "bytes $start-${bytes.lastIndex}/${bytes.size}")
                        .setBody(Buffer().write(bytes, start, bytes.size - start))
                }
            }
            server.start()
            val fixtureUrl = server.url("/fixture.mp4").toString()
            ActivityScenario.launch(NextActivity::class.java).use { scenario ->
                lateinit var engine: Media3PlaybackEngine
                var created = false
                try {
                    scenario.onActivity { activity ->
                        val surface = PlayerView(activity).apply { useController = false }
                        activity.setContentView(surface)
                        engine = Media3PlaybackEngine(activity, BiliMediaDataSource(OkHttpClient()) { BiliCredentials.Empty })
                        created = true
                        engine.listener = object : PlaybackEngine.Listener {
                            override fun ready(token: Long) { ready.countDown() }
                            override fun buffering(token: Long) { }
                            override fun ended(token: Long) { }
                            override fun interrupted(token: Long) { }
                            override fun failed(token: Long, kind: MediaFailureKind) { failure.set(kind); ready.countDown(); firstFrame.countDown() }
                        }
                        val streams = PlaybackStreams(emptyList(), emptyList(),
                            listOf(MediaSegment(1, 8000, listOf(fixtureUrl))), emptyList(), 32, 8000, 0)
                        engine.load(1, "BV1xx411c7mD", streams, 0, 0, 0, 1f, true)
                        val player = engine.player.value!!
                        player.volume = 0f
                        player.addListener(object : Player.Listener {
                            override fun onRenderedFirstFrame() { firstFrame.countDown() }
                        })
                        surface.player = player
                    }
                    assertTrue("Media3 did not become ready", ready.await(15, TimeUnit.SECONDS))
                    assertTrue("No decoded frame reached the surface", firstFrame.await(15, TimeUnit.SECONDS))
                    assertNull("Media3 decoder/source failed", failure.get())
                    scenario.onActivity {
                        engine.play(false)
                        engine.seek(3000)
                        engine.speed(1.5f)
                        assertFalse(engine.player.value!!.playWhenReady)
                        assertEquals(3000L, engine.position()!!.positionMs)
                        assertEquals(1.5f, engine.player.value!!.playbackParameters.speed)
                        assertTrue(engine.position()!!.durationMs in 7900..8200)
                    }
                } finally { scenario.onActivity { if (created) { engine.release(); assertNull(engine.player.value) } } }
            }
        }
    }
}
