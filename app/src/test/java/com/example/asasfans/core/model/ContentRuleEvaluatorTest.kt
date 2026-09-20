package com.example.asasfans.core.model

import org.junit.Assert.*
import org.junit.Test

class ContentRuleEvaluatorTest {
    private val video = Video(ContentId.bilibili("BV1MBeq6rEz2"), "歌切", Creator(id = "123", name = "UP"),
        description = "这是一段录播", category = "音乐", tags = listOf("嘉然", "切片"))

    @Test fun wordsDoNotMatchTagsButMatchDescriptionAndCategory() {
        assertFalse(check(ContentRule("1", RuleKind.WORD, "嘉然")).blocked)
        assertEquals("简介", check(ContentRule("1", RuleKind.WORD, "录播")).matches.single().field)
        assertEquals("分区", check(ContentRule("1", RuleKind.WORD, "音乐")).matches.single().field)
    }
    @Test fun tagsMatchExactly() {
        assertFalse(check(ContentRule("1", RuleKind.TAG, "切")).blocked)
        assertTrue(check(ContentRule("1", RuleKind.TAG, " 切片 ")).blocked)
    }
    @Test fun unknownTagsAreNotKnownEmptyTags() {
        val rule = listOf(ContentRule("1", RuleKind.TAG, "嘉然"))
        assertTrue(ContentRuleEvaluator.evaluate(video.copy(tags = null), rule, 1).tagsUnknown)
        assertFalse(ContentRuleEvaluator.evaluate(video.copy(tags = emptyList()), rule, 1).tagsUnknown)
    }
    @Test fun disabledAndExpiredRulesDoNotBlock() {
        assertFalse(check(ContentRule("1", RuleKind.WORD, "歌切", enabled = false)).blocked)
        assertFalse(check(ContentRule("1", RuleKind.WORD, "歌切", expiresAtMs = 10)).blocked)
        assertTrue(check(ContentRule("1", RuleKind.WORD, "歌切", expiresAtMs = 11)).blocked)
    }
    @Test fun scopedIdentifiersCannotBlockAnotherSource() {
        val rule = listOf(ContentRule("1", RuleKind.CREATOR, "bilibili:123"))
        assertTrue(ContentRuleEvaluator.evaluate(video, rule, 1).blocked)
        assertFalse(ContentRuleEvaluator.evaluate(video.copy(creator = video.creator.copy(source = "other")), rule, 1).blocked)
    }
    @Test fun builtInMemberPolicyPreservesLegacyBehavior() {
        val cases = listOf(video.copy(title = "珈乐"), video.copy(creator = video.creator.copy(id = "351609538")),
            video.copy(description = "CAROL"), video.copy(tags = listOf("Carol")))
        cases.forEach { assertEquals(ContentRuleEvaluator.BUILT_IN_CAROL_RULE,
            ContentRuleEvaluator.evaluate(it, emptyList(), 1).matches.single().ruleId) }
    }
    @Test fun queryKeepsRelativeDatesInsteadOfFreezingRequestUrl() {
        assertEquals(30, QuerySpec(keyword = "嘉然", days = 30).days)
        assertThrows(IllegalArgumentException::class.java) { QuerySpec(version = 2) }
        assertThrows(IllegalArgumentException::class.java) { QuerySpec(days = -1) }
    }
    @Test fun contentIdentityRoundTripsWithoutSignedMediaUrls() {
        assertEquals(video.id, ContentId.fromKey(video.id.key))
        assertThrows(IllegalArgumentException::class.java) { ContentId("bili:evil", "1") }
    }
    private fun check(rule: ContentRule) = ContentRuleEvaluator.evaluate(video, listOf(rule), 10)
}
