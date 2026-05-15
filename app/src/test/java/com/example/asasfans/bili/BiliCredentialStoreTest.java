package com.example.asasfans.bili;

import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

public class BiliCredentialStoreTest {
    @Test
    public void parseSetCookieHeader_extractsNameAndValue() {
        BiliCredentialStore.CookiePair pair = BiliCredentialStore.parseSetCookieHeader(
                "SESSDATA=abc%2Cdef; Path=/; Domain=.bilibili.com; HttpOnly"
        );

        assertEquals("SESSDATA", pair.name);
        assertEquals("abc%2Cdef", pair.value);
    }

    @Test
    public void parseSetCookieHeader_ignoresInvalidCookie() {
        assertNull(BiliCredentialStore.parseSetCookieHeader(""));
        assertNull(BiliCredentialStore.parseSetCookieHeader("HttpOnly; Path=/"));
    }

    @Test
    public void cookiePairToString_redactsSensitiveValue() {
        BiliCredentialStore.CookiePair pair = BiliCredentialStore.parseSetCookieHeader("bili_jct=secret;");

        assertEquals("bili_jct=<redacted>", pair.toString());
    }
}
