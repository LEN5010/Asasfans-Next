package com.example.asasfans.core.data

import androidx.room.withTransaction
import com.example.asasfans.core.database.*
import com.example.asasfans.core.model.*
import java.util.UUID

/** Local-only following and rules; never invokes Bilibili write endpoints. */
class CurationRepository(private val database: AsasDatabase, private val awaitReady: suspend () -> Unit) {
    private val dao = database.assets()
    val subscriptions = dao.subscriptions()
    val rules = dao.rules()
    suspend fun subscribe(creator: Creator) {
        require(creator.id.toLongOrNull()?.let { it > 0 } == true)
        awaitReady()
        database.withTransaction {
            val previous = dao.subscription(creator.key)
            dao.putSubscription(previous?.copy(name = creator.name.ifBlank { previous.name },
                avatarUrl = creator.avatarUrl.ifBlank { previous.avatarUrl }) ?: SubscriptionEntity(
                creator.key, creator.source, creator.id, creator.name, creator.avatarUrl, updatedAtMs = System.currentTimeMillis()))
        }
    }
    suspend fun unsubscribe(key: String) { awaitReady(); dao.deleteSubscription(key) }
    suspend fun addRule(kind: RuleKind, value: String) {
        require(value.isNotBlank() && value.length <= 256)
        if (kind == RuleKind.CREATOR) require(value.toLongOrNull()?.let { it > 0 } == true)
        if (kind == RuleKind.VIDEO) require(value.matches(Regex("BV[0-9A-Za-z]{10}")))
        awaitReady()
        dao.insertRule(RuleEntity(UUID.randomUUID().toString(), kind.name, value.trim()))
    }
    suspend fun removeRule(id: String) { awaitReady(); dao.deleteRule(id) }
    suspend fun toggleRule(rule: RuleEntity) { awaitReady(); dao.putRule(rule.copy(enabled = !rule.enabled)) }
}
