package com.example.asasfans.bili;

import org.junit.Test;

import java.util.HashMap;
import java.util.Map;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

public class WbiSignerTest {
    @Test
    public void mixinKey_usesBilibiliPermutation() {
        assertEquals(
                "ea1db124af3c7062474693fa704f4ff8",
                WbiSigner.mixinKey("7cd084941338484aae1ad9425b84077c4932caff0ff746eab6f01bf08b70ac45")
        );
    }

    @Test
    public void encodeURIComponent_usesUppercasePercentEscapes() {
        assertEquals("a%20b%21%2A%E4%B8%AD%E6%96%87", WbiSigner.encodeURIComponent("a b!*中文"));
    }

    @Test
    public void signToQuery_sortsParamsAndStripsUnsupportedCharacters() {
        WbiSigner signer = new WbiSigner();
        signer.setKeys(
                "https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png",
                "https://i0.hdslb.com/bfs/wbi/4932caff0ff746eab6f01bf08b70ac45.png"
        );
        Map<String, String> params = new HashMap<>();
        params.put("foo", "a b!'()*中文");
        params.put("bar", "514");

        String query = signer.signToQuery(params, 1702204169L);

        assertTrue(query.startsWith("bar=514&foo=a%20b%E4%B8%AD%E6%96%87&wts=1702204169&w_rid="));
        assertEquals(3, params.size());
    }
}
