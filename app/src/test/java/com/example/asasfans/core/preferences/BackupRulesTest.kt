package com.example.asasfans.core.preferences

import android.app.Application
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.example.asasfans.R
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.xmlpull.v1.XmlPullParser

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class BackupRulesTest {
    @Test fun backupAllowListsDoNotIncludeCredentialsOrWebViewCookies() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val allowed = setOf("database:.", "file:datastore/", "sharedpref:video_playback_mode.xml")
        for (resource in listOf(R.xml.backup_rules, R.xml.data_extraction_rules)) {
            val included = mutableListOf<String>()
            context.resources.getXml(resource).use { parser ->
                while (parser.eventType != XmlPullParser.END_DOCUMENT) {
                    if (parser.eventType == XmlPullParser.START_TAG && parser.name == "include") {
                        included += "${parser.getAttributeValue(null, "domain")}:${parser.getAttributeValue(null, "path")}"
                    }
                    parser.next()
                }
            }
            assertTrue(included.isNotEmpty())
            assertEquals(allowed, included.toSet())
            assertFalse(included.any { it.startsWith("root:") || it.contains("bili_credentials") })
        }
    }
}
