package com.example.asasfans.bili;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class BiliVideoRepository {
    private static final String VIEW_URL = "https://api.bilibili.com/x/web-interface/wbi/view";
    private static final String PLAY_URL = "https://api.bilibili.com/x/player/wbi/playurl";

    private final BiliApiClient apiClient;
    private final BiliAuthRepository authRepository;
    private final WbiSigner wbiSigner;

    public BiliVideoRepository(BiliApiClient apiClient, BiliAuthRepository authRepository, WbiSigner wbiSigner) {
        this.apiClient = apiClient;
        this.authRepository = authRepository;
        this.wbiSigner = wbiSigner;
    }

    public BiliModels.VideoViewResponse getVideoView(String bvid) throws IOException {
        ensureWbiKeys();
        Map<String, String> params = new HashMap<>();
        params.put("bvid", bvid);
        String url = BiliApiClient.appendQuery(VIEW_URL, wbiSigner.signToQuery(params));
        BiliModels.VideoViewResponse response = apiClient.get(url, videoReferer(bvid), BiliModels.VideoViewResponse.class);
        ensureSuccess(response);
        return response;
    }

    public BiliModels.PlayUrlResponse getDashPlayUrl(String bvid, long cid) throws IOException {
        return getDashPlayUrl(bvid, cid, 80);
    }

    public BiliModels.PlayUrlResponse getDashPlayUrl(String bvid, long cid, int qn) throws IOException {
        Map<String, String> params = basePlayParams(bvid, cid);
        params.put("fnval", "16");
        params.put("qn", String.valueOf(qn <= 0 ? 80 : qn));
        return getPlayUrl(bvid, params);
    }

    public BiliModels.PlayUrlResponse getMp4PlayUrl(String bvid, long cid) throws IOException {
        return getMp4PlayUrl(bvid, cid, 64);
    }

    public BiliModels.PlayUrlResponse getMp4PlayUrl(String bvid, long cid, int qn) throws IOException {
        Map<String, String> params = basePlayParams(bvid, cid);
        params.put("fnval", "1");
        params.put("qn", String.valueOf(qn <= 0 ? 64 : qn));
        params.put("platform", "html5");
        params.put("high_quality", "1");
        return getPlayUrl(bvid, params);
    }

    public String pickDashVideoUrl(BiliModels.PlayUrlResponse response) {
        return pickDashVideoUrl(response, 0);
    }

    public String pickDashVideoUrl(BiliModels.PlayUrlResponse response, int requestedQn) {
        if (response == null || response.data == null || response.data.dash == null || response.data.dash.video == null) {
            return "";
        }
        BiliModels.DashMedia best = null;
        for (BiliModels.DashMedia video : response.data.dash.video) {
            if (video == null || video.baseUrl == null) {
                continue;
            }
            if (requestedQn > 0 && video.id == requestedQn && video.codecs != null && video.codecs.startsWith("avc1")) {
                return video.baseUrl;
            }
            if (requestedQn > 0 && video.id != requestedQn) {
                continue;
            }
            if (best == null) {
                best = video;
                continue;
            }
            if (video.codecs != null && video.codecs.startsWith("avc1")) {
                if (best.codecs == null || !best.codecs.startsWith("avc1") || video.id > best.id) {
                    best = video;
                }
            } else if ((best.codecs == null || !best.codecs.startsWith("avc1")) && video.id > best.id) {
                best = video;
            }
        }
        return best == null ? "" : best.baseUrl;
    }

    public List<BiliModels.VideoQuality> buildQualityOptions(BiliModels.PlayUrlResponse response) {
        List<BiliModels.VideoQuality> options = new ArrayList<>();
        options.add(new BiliModels.VideoQuality(0, "自动", true));
        if (response == null || response.data == null) {
            return options;
        }
        Set<Integer> added = new LinkedHashSet<>();
        if (response.data.acceptQuality != null && !response.data.acceptQuality.isEmpty()) {
            for (int i = 0; i < response.data.acceptQuality.size(); i++) {
                int qn = response.data.acceptQuality.get(i);
                if (added.add(qn)) {
                    String description = response.data.acceptDescription != null && i < response.data.acceptDescription.size()
                            ? response.data.acceptDescription.get(i)
                            : qualityName(qn);
                    options.add(new BiliModels.VideoQuality(qn, description, false));
                }
            }
            return options;
        }
        if (response.data.dash != null && response.data.dash.video != null) {
            List<Integer> qns = new ArrayList<>();
            for (BiliModels.DashMedia media : response.data.dash.video) {
                if (media != null && media.baseUrl != null && added.add(media.id)) {
                    qns.add(media.id);
                }
            }
            Collections.sort(qns, Comparator.reverseOrder());
            for (int qn : qns) {
                options.add(new BiliModels.VideoQuality(qn, qualityName(qn), false));
            }
        }
        return options;
    }

    public String pickDashAudioUrl(BiliModels.PlayUrlResponse response) {
        if (response == null || response.data == null || response.data.dash == null || response.data.dash.audio == null) {
            return "";
        }
        List<BiliModels.DashMedia> audios = response.data.dash.audio;
        BiliModels.DashMedia best = null;
        for (BiliModels.DashMedia audio : audios) {
            if (audio == null || audio.baseUrl == null) {
                continue;
            }
            if (best == null || audio.id == 30280 || (best.id != 30280 && audio.id > best.id)) {
                best = audio;
            }
        }
        return best == null ? "" : best.baseUrl;
    }

    public String pickMp4Url(BiliModels.PlayUrlResponse response) {
        if (response == null || response.data == null || response.data.durl == null || response.data.durl.isEmpty()) {
            return "";
        }
        BiliModels.Durl durl = response.data.durl.get(0);
        if (durl.url != null && !durl.url.isEmpty()) {
            return durl.url;
        }
        if (durl.backupUrl != null && !durl.backupUrl.isEmpty()) {
            return durl.backupUrl.get(0);
        }
        return "";
    }

    public static String videoReferer(String bvid) {
        return "https://www.bilibili.com/video/" + bvid;
    }

    public static String qualityName(int qn) {
        switch (qn) {
            case 6:
                return "240P 极速";
            case 16:
                return "360P 流畅";
            case 32:
                return "480P 清晰";
            case 64:
                return "720P 高清";
            case 74:
                return "720P60";
            case 80:
                return "1080P 高清";
            case 112:
                return "1080P+";
            case 116:
                return "1080P60";
            case 120:
                return "4K 超清";
            case 125:
                return "HDR";
            case 126:
                return "杜比视界";
            case 127:
                return "8K 超高清";
            case 129:
                return "HDR Vivid";
            default:
                return qn + "P";
        }
    }

    private BiliModels.PlayUrlResponse getPlayUrl(String bvid, Map<String, String> params) throws IOException {
        ensureWbiKeys();
        String url = BiliApiClient.appendQuery(PLAY_URL, wbiSigner.signToQuery(params));
        BiliModels.PlayUrlResponse response = apiClient.get(url, videoReferer(bvid), BiliModels.PlayUrlResponse.class);
        ensureSuccess(response);
        return response;
    }

    private Map<String, String> basePlayParams(String bvid, long cid) {
        Map<String, String> params = new HashMap<>();
        params.put("bvid", bvid);
        params.put("cid", String.valueOf(cid));
        params.put("fnver", "0");
        params.put("fourk", "0");
        params.put("otype", "json");
        return params;
    }

    private void ensureWbiKeys() throws IOException {
        if (wbiSigner.hasFreshKeys()) {
            return;
        }
        BiliModels.NavResponse nav = authRepository.getNav();
        if (nav == null || nav.data == null || nav.data.wbiImg == null) {
            throw new BiliException(nav == null ? -1 : nav.code, nav == null ? "WBI key 获取失败" : nav.message);
        }
        wbiSigner.setKeys(nav.data.wbiImg.imgUrl, nav.data.wbiImg.subUrl);
    }

    private void ensureSuccess(BiliModels.BaseResponse response) throws BiliException {
        if (response == null || response.code != 0) {
            throw new BiliException(response == null ? -1 : response.code, response == null ? "Bilibili API 请求失败" : response.message);
        }
    }
}
