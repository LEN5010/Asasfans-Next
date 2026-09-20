package com.example.asasfans.core.preferences

import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test

class LegacyCacheReaderTest {
    @Test fun readsLegacyStringsAndExpiryWithoutChangingOriginal() {
        val directory = Files.createTempDirectory("asas-legacy-cache").toFile()
        try {
            val file = java.io.File(directory, "setting".hashCode().toString())
            file.writeText("yes")
            assertEquals("yes", LegacyCacheReader.read(directory, "setting", 1000))
            file.writeText("1700000000000-10 no")
            assertEquals("no", LegacyCacheReader.read(directory, "setting", 1700000005000))
            assertNull(LegacyCacheReader.read(directory, "setting", 1700000010001))
            assertEquals("1700000000000-10 no", file.readText())
            file.writeText("1700000000000-999999999999999999999 yes")
            assertNull(LegacyCacheReader.read(directory, "setting", 1700000005000))
        } finally { directory.deleteRecursively() }
    }
}
