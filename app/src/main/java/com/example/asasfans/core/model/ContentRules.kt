package com.example.asasfans.core.model

import java.util.Locale
import kotlinx.serialization.Serializable

@Serializable
enum class RuleKind { VIDEO, CREATOR, WORD, TAG }

@Serializable
data class ContentRule(
    val id: String,
    val kind: RuleKind,
    val value: String,
    val enabled: Boolean = true,
    val expiresAtMs: Long? = null,
)

data class RuleMatch(val ruleId: String, val field: String, val reason: String)

data class RuleEvaluation(val matches: List<RuleMatch>, val tagsUnknown: Boolean) {
    val blocked: Boolean get() = matches.isNotEmpty()
}

/** All feeds share this evaluator, including the existing built-in member policy. */
object ContentRuleEvaluator {
    const val BUILT_IN_CAROL_RULE = "builtin:carol"

    fun evaluate(video: Video, rules: List<ContentRule>, nowMs: Long): RuleEvaluation {
        val matches = mutableListOf<RuleMatch>()
        val wordFields = listOf("标题" to video.title, "简介" to video.description, "分区" to video.category)
        val tags = video.tags?.map(::normalize)?.toSet()
        rules.filter { it.enabled && (it.expiresAtMs == null || it.expiresAtMs > nowMs) }.forEach { rule ->
            val value = normalize(rule.value)
            if (value.isEmpty()) return@forEach
            val field = when (rule.kind) {
                RuleKind.VIDEO -> if (rule.value == video.id.key ||
                    (video.id.source == "bilibili" && rule.value == video.id.value)) "视频" else null
                RuleKind.CREATOR -> if (rule.value == video.creator.key ||
                    (video.creator.source == "bilibili" && rule.value == video.creator.id)) "UP" else null
                RuleKind.WORD -> wordFields.firstOrNull { normalize(it.second).contains(value) }?.first
                RuleKind.TAG -> if (tags?.contains(value) == true) "Tag" else null
            }
            if (field != null) matches += RuleMatch(rule.id, field, "命中${field}屏蔽规则：${rule.value}")
        }
        // Preserve 1.x policy until an explicit product decision changes this default.
        val carolFields = wordFields.take(2) + listOf(
            "Tag" to video.tags.orEmpty().joinToString(","), "UP 名称" to video.creator.name,
        )
        val carolField = if (video.creator.source == "bilibili" && video.creator.id == "351609538") "UP" else
            carolFields.firstOrNull { (_, text) -> normalize(text).let { "珈乐" in it || "carol" in it } }?.first
        if (carolField != null) matches += RuleMatch(BUILT_IN_CAROL_RULE, carolField, "当前默认成员过滤规则")
        return RuleEvaluation(matches, video.tags == null && rules.any {
            it.kind == RuleKind.TAG && it.enabled && (it.expiresAtMs == null || it.expiresAtMs > nowMs)
        })
    }

    fun parseLegacyTags(value: String): List<String> = value.replace("'", "").split(',')
        .map(::normalize).filter(String::isNotEmpty).distinct()

    private fun normalize(value: String) = value.trim().lowercase(Locale.ROOT)
}
