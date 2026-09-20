package com.example.asasfans.core.database

import android.database.sqlite.SQLiteDatabase
import androidx.room.withTransaction
import java.io.File
import java.security.MessageDigest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** The only new component that knows the 1.x database schema. Never writes the source. */
class LegacyImporter(
    private val database: AsasDatabase,
    private val legacyFile: File,
    private val nowMs: () -> Long = System::currentTimeMillis,
    /** A test seam for interruption/disk failure; production keeps the default. */
    private val afterRow: suspend (Int) -> Unit = {},
) {
    private val mutex = Mutex()

    suspend fun importIfNeeded(): MigrationReceiptEntity = mutex.withLock {
        withContext(Dispatchers.IO) {
            database.assets().receipt(RECEIPT_ID)?.let { return@withContext it }
            val snapshot = readSnapshot()
            database.withTransaction {
                // Also protects against two importer instances initialized concurrently.
                database.assets().receipt(RECEIPT_ID)?.let { return@withTransaction it }
                snapshot.rows.forEachIndexed { index, row ->
                    importRow(row)
                    afterRow(index + 1)
                }
                MigrationReceiptEntity(RECEIPT_ID, snapshot.version, nowMs(), snapshot.rows.size).also {
                    database.assets().insertReceipt(it)
                }
            }
        }
    }

    private fun readSnapshot(): Snapshot {
        if (!legacyFile.exists()) return Snapshot(0, emptyList())
        // A corrupt/unreadable existing database must fail, not be treated as a new install.
        return SQLiteDatabase.openDatabase(legacyFile.path, null, SQLiteDatabase.OPEN_READONLY).use { old ->
            require(old.version in 0..3) { "旧数据库版本高于当前迁移器支持范围" }
            val tables = old.rawQuery("SELECT name FROM sqlite_master WHERE type='table'", null).use { cursor ->
                buildSet { while (cursor.moveToNext()) add(cursor.getString(0)) }
            }
            val rows = mutableListOf<LegacyRow>()
            TABLES.filter(tables::contains).forEach { table ->
                // table comes exclusively from the fixed whitelist, never from user input.
                old.rawQuery("SELECT * FROM `$table`", null).use { cursor ->
                    var index = 0
                    while (cursor.moveToNext()) {
                        check(rows.size < MAX_ROWS) { "旧数据超过单次迁移容量，请先导出后分批恢复" }
                        val values = cursor.columnNames.mapIndexed { i, name ->
                            name to if (cursor.isNull(i)) null else cursor.getString(i)
                        }.toMap()
                        rows += LegacyRow(table, index++, values)
                    }
                }
            }
            Snapshot(old.version, rows)
        }
    }

    private suspend fun importRow(row: LegacyRow) {
        val dao = database.assets()
        // Validate/convert before mutating. Only validation errors are quarantined;
        // database/IO failures must propagate and roll back the entire import.
        val converted = try {
            convert(row)
        } catch (error: IllegalArgumentException) {
            dao.insertRecovery(LegacyRecoveryEntity(
                "${row.table}:${row.index}", row.table, Json.encodeToString(row.values),
                "历史字段无效，已完整保留原始记录供恢复",
            ))
            return
        }
        converted.content?.let { dao.putContent(it) }
        converted.rule?.let { dao.insertRule(it) }
        converted.subscription?.let { dao.putSubscription(it) }
    }

    private fun convert(row: LegacyRow): Converted {
        val values = row.values
        fun required(name: String): String = requireNotNull(values[name]).also { require(it.isNotBlank()) }
        fun mid(): Long = required("mid").toLong().also { require(it > 0) }
        fun rule(kind: String, value: String) = RuleEntity(stableRuleId(kind, value), kind, value, origin = "legacy")
        return when (row.table) {
            "blackWord" -> Converted(rule = rule("WORD", required("word")))
            "blackTag" -> Converted(rule = rule("TAG", required("tag")))
            "blackMid" -> Converted(rule = rule("CREATOR", "bilibili:${mid()}"))
            "blackBvid" -> {
                val bvid = required("bvid").also { require(it.length <= 2048) }
                val id = "bilibili:$bvid"
                Converted(rule = rule("VIDEO", id), content = ContentEntity(
                    id, "bilibili", bvid, values["Title"].orEmpty().ifBlank { bvid }, "",
                    creatorName = values["Author"].orEmpty(), coverUrl = values["PicUrl"].orEmpty(),
                    category = values["Tname"].orEmpty(), durationMs = secondsToMs(values["Duration"]),
                    views = values["ViewNum"]?.toLongOrNull(), likes = values["LikeNum"]?.toLongOrNull(),
                ))
            }
            "subscribedUp" -> {
                val mid = mid().toString()
                Converted(subscription = SubscriptionEntity(
                    "bilibili:$mid", "bilibili", mid, values["name"].orEmpty(), values["face"].orEmpty(),
                    values["note"].orEmpty(), updatedAtMs = secondsToMs(values["updatedAt"]),
                ))
            }
            else -> error("Unsupported legacy table")
        }
    }

    private fun secondsToMs(value: String?): Long {
        val seconds = value?.toLongOrNull() ?: return 0
        require(seconds >= 0 && seconds <= Long.MAX_VALUE / 1000)
        return seconds * 1000
    }

    private data class LegacyRow(val table: String, val index: Int, val values: Map<String, String?>)
    private data class Snapshot(val version: Int, val rows: List<LegacyRow>)
    private data class Converted(val content: ContentEntity? = null, val rule: RuleEntity? = null, val subscription: SubscriptionEntity? = null)

    companion object {
        const val RECEIPT_ID = "legacy-blackList-v1-v3"
        private const val MAX_ROWS = 100_000
        private val TABLES = listOf("blackWord", "blackTag", "blackMid", "blackBvid", "subscribedUp")
        fun stableRuleId(kind: String, value: String): String = MessageDigest.getInstance("SHA-256")
            .digest("$kind\u0000$value".toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }
}
