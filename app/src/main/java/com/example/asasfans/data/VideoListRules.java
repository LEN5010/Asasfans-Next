package com.example.asasfans.data;

import java.util.Locale;
import java.util.Set;

public class VideoListRules {
    private VideoListRules() {
    }

    public static boolean matchesBlackWord(String title, String desc, String tag, String tname, Iterable<String> words) {
        String haystack = normalize(title) + "\n" + normalize(desc) + "\n" + normalize(tag) + "\n" + normalize(tname);
        for (String word : words) {
            String normalized = normalize(word);
            if (!normalized.isEmpty() && haystack.contains(normalized)) {
                return true;
            }
        }
        return false;
    }

    public static int compareSubscribedUp(long leftMid, long rightMid, Set<Long> subscribedMids) {
        boolean leftSubscribed = subscribedMids.contains(leftMid);
        boolean rightSubscribed = subscribedMids.contains(rightMid);
        if (leftSubscribed == rightSubscribed) {
            return 0;
        }
        return leftSubscribed ? -1 : 1;
    }

    private static String normalize(String value) {
        return value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
    }
}
