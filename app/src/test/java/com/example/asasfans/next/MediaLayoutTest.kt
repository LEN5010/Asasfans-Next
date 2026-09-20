package com.example.asasfans.next

import org.junit.Assert.assertEquals
import org.junit.Test

class MediaLayoutTest {
    @Test fun regularPhonesUseTwoColumns() {
        assertEquals(2, mediaColumnCount(336f))
        assertEquals(2, mediaColumnCount(388f))
    }

    @Test fun narrowScreensAndLargeTextUseOneColumn() {
        assertEquals(1, mediaColumnCount(296f))
        assertEquals(1, mediaColumnCount(388f, fontScale = 1.5f))
        assertEquals(1, mediaColumnCount(388f, fontScale = 2f))
    }

    @Test fun wideLayoutsUseLargerCardsAndBoundedColumns() {
        assertEquals(3, mediaColumnCount(800f))
        assertEquals(4, mediaColumnCount(1000f))
        assertEquals(6, mediaColumnCount(2000f))
    }

    @Test fun countsAndDurationDoNotInventStatistics() {
        assertEquals("9999", countText(9999))
        assertEquals("1.2万", countText(12_000))
        assertEquals("1.5亿", countText(150_000_000))
        assertEquals("1:01:01", timeText(3_661_000))
    }

    @Test fun widePlayerReservesVisibleControlsBeforeSizingVideo() {
        assertEquals(200f, playerFrameHeight(800f, 296f), .01f)
        assertEquals(225f, playerFrameHeight(400f, 800f), .01f)
    }

    @Test fun widePlayerReservesMoreRoomForLargeText() {
        assertEquals(104f, playerFrameHeight(800f, 296f, fontScale = 2f), .01f)
        assertEquals(1f, playerFrameHeight(800f, 90f), .01f)
    }

}
