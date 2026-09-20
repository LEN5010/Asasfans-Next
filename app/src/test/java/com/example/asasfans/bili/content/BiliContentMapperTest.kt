package com.example.asasfans.bili.content

import android.app.Application
import com.example.asasfans.core.model.AppFailure
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

internal fun fixture(name: String): JsonObject = Json.parseToJsonElement(
    checkNotNull(BiliContentMapperTest::class.java.getResource("/bili/v2/$name.json")).readText()) as JsonObject
internal fun fixtureData(name: String) = fixture(name)["data"] as JsonObject

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class BiliContentMapperTest {
    @Test fun creatorProfilePreservesDescriptionAndValidatesIdentity() {
        val data = Json.parseToJsonElement("""{"mid":42,"name":"合成 UP","face":"//i0.hdslb.com/fixture.png","sign":"简介\n第二行","official":{"title":"合成认证"}}""") as JsonObject
        val profile = BiliContentMapper.creator(data, 42)
        assertEquals("42", profile.creator.id)
        assertEquals("合成 UP", profile.creator.name)
        assertEquals("https://i0.hdslb.com/fixture.png", profile.creator.avatarUrl)
        assertEquals("简介\n第二行", profile.introduction)
        assertEquals("合成认证", profile.officialTitle)
        try { BiliContentMapper.creator(data, 43); fail("mismatched creator") }
        catch (_: AppFailure.InvalidResponse) { }
        try { BiliContentMapper.creator(JsonObject(data - "name"), 42); fail("missing identity") }
        catch (_: AppFailure.InvalidResponse) { }
    }

    @Test fun detailPreservesCidIdentityAndUnknownStats() {
        val result = BiliContentMapper.detail(fixtureData("detail"), "BV1xx411c7mD")
        assertEquals(listOf(101L, 201L), result.parts.map { it.id })
        assertEquals(120_000L, result.parts.first().durationMs)
        assertEquals(123L, result.aid)
        assertNull(result.video.tags)
        assertNull(result.video.likes)
        assertEquals(1200L, result.video.views)
        assertTrue(result.video.creator.avatarUrl.startsWith("https://"))
    }

    @Test fun mismatchedIdentityAndDuplicatePartsAreRejected() {
        val data = fixtureData("detail")
        try { BiliContentMapper.detail(data, "BV1yy411c7mD"); fail("must reject") }
        catch (_: AppFailure.InvalidResponse) { }
        val part = (data["pages"] as JsonArray).first()
        try { BiliContentMapper.detail(JsonObject(data + ("pages" to JsonArray(listOf(part, part)))), "BV1xx411c7mD"); fail("must reject") }
        catch (_: AppFailure.InvalidResponse) { }
    }

    @Test fun searchDecodesHighlightMarkupAndDurationWithoutInventingLikes() {
        val result = BiliContentMapper.search(fixtureData("search"), 1)
        val video = result.videos.single()
        assertEquals("嘉然 & 歌曲", video.title)
        assertEquals(3_723_000L, video.durationMs)
        assertEquals(listOf("嘉然", "歌曲"), video.tags)
        assertNull(video.likes)
        assertEquals(1234L, video.views)
        assertTrue(result.hasMore)
    }

    @Test fun emptySearchRequiresExplicitZeroAndStopsPagination() {
        val empty = Json.parseToJsonElement("""{"page":1,"numResults":0,"numPages":0,"result":null}""") as JsonObject
        assertFalse(BiliContentMapper.search(empty, 1).hasMore)
        try { BiliContentMapper.search(JsonObject(empty - "numResults"), 1); fail("must reject") }
        catch (_: AppFailure.InvalidResponse) { }
        try { BiliContentMapper.search(fixtureData("search"), 2); fail("must reject") }
        catch (_: AppFailure.InvalidResponse) { }
    }

    @Test fun archiveDoesNotFabricateTagsAndValidatesCreator() {
        val result = BiliContentMapper.archive(fixtureData("archive"), 42, 1)
        assertNull(result.videos.single().tags)
        assertNull(result.videos.single().views)
        assertEquals(330_000L, result.videos.single().durationMs)
        assertFalse(result.hasMore)
        try { BiliContentMapper.archive(fixtureData("archive"), 43, 1); fail("must reject") }
        catch (_: AppFailure.InvalidResponse) { }
    }

    @Test fun advertisedVipQualityIsNotMarkedPlayableWithoutReturnedTrack() {
        val result = BiliContentMapper.playback(fixtureData("dash"), 100)
        assertFalse(result.qualities.first { it.id == 112 }.available)
        assertTrue(result.qualities.first { it.id == 80 }.available)
        assertEquals(64, result.selectVideo(0)!!.quality) // automatic favors AVC compatibility
        assertEquals(80, result.selectVideo(80)!!.quality)
        assertEquals(64, result.selectVideo(64)!!.quality)
        assertEquals(32, result.selectVideo(40)!!.quality)
        assertEquals(30280, result.selectAudio()!!.quality)
        assertEquals(2, result.selectVideo(64)!!.urls.size)
        assertTrue(result.selectVideo(64)!!.urls.first().startsWith("https://"))
        assertFalse(result.toString().contains("synthetic"))
        assertFalse(result.selectVideo(64).toString().contains("synthetic"))
    }

    @Test fun mp4FallbackUsesBackupAndReportsActualQuality() {
        val result = BiliContentMapper.playback(fixtureData("mp4"), 100)
        assertNull(result.selectVideo(0))
        assertEquals(32, result.returnedQuality)
        assertEquals(32, result.qualities.single().id)
        assertEquals(1, result.segments.single().urls.size)
        assertFalse(result.segments.single().toString().contains("synthetic"))
    }

    @Test fun commentsDeduplicatePinnedAndHotRowsButKeepUnknownLikes() {
        val result = BiliContentMapper.comments(fixtureData("comments"), 1)
        assertEquals(listOf(1L, 2L), result.comments.map { it.id })
        assertTrue(result.comments.first().pinned)
        assertNull(result.comments.last().likes)
        assertTrue(result.hasMore)
    }

    @Test fun malformedDurationsCannotOverflowIntoPlaybackState() {
        for (input in listOf("", "-5", "foo", "9223372036854775807", "1:2:3:4", "1:9223372036854775807")) {
            assertEquals(0L, BiliContentMapper.duration(input))
        }
        assertEquals(90_000L, BiliContentMapper.duration("1:30"))
    }
}
