package com.example.asasfans.data;

import org.junit.Test;

import java.util.Arrays;
import java.util.HashSet;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class VideoListRulesTest {
    @Test
    public void matchesBlackWord_checksTitleDescTagAndTypeName() {
        assertTrue(VideoListRules.matchesBlackWord("标题", "简介命中词", "tag", "分区", Arrays.asList("命中词")));
        assertTrue(VideoListRules.matchesBlackWord("标题", "简介", "嘉然,切片", "分区", Arrays.asList("切片")));
        assertTrue(VideoListRules.matchesBlackWord("标题", "简介", "tag", "娱乐", Arrays.asList("娱乐")));
        assertFalse(VideoListRules.matchesBlackWord("标题", "简介", "tag", "分区", Arrays.asList("不存在")));
    }

    @Test
    public void compareSubscribedUp_sortsSubscribedBeforeNormal() {
        HashSet<Long> subscribed = new HashSet<>(Arrays.asList(100L));

        assertEquals(-1, VideoListRules.compareSubscribedUp(100L, 200L, subscribed));
        assertEquals(1, VideoListRules.compareSubscribedUp(200L, 100L, subscribed));
        assertEquals(0, VideoListRules.compareSubscribedUp(100L, 100L, subscribed));
    }
}
