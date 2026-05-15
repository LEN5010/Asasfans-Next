package com.example.asasfans.bili;

import org.junit.Test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import static org.junit.Assert.assertEquals;

public class BiliVideoRepositoryTest {
    @Test
    public void pickDashVideoUrl_prefersAvcTrack() {
        BiliVideoRepository repository = new BiliVideoRepository(null, null, null);
        BiliModels.PlayUrlResponse response = new BiliModels.PlayUrlResponse();
        response.data = new BiliModels.PlayUrlData();
        response.data.dash = new BiliModels.Dash();
        response.data.dash.video = new ArrayList<>();
        response.data.dash.video.add(media(80, "hev1.1.6.L120.90", "hevc-80"));
        response.data.dash.video.add(media(32, "avc1.64001F", "avc-32"));
        response.data.dash.video.add(media(64, "avc1.640028", "avc-64"));

        assertEquals("avc-64", repository.pickDashVideoUrl(response));
    }

    @Test
    public void pickDashAudioUrl_prefers30280ThenHighest() {
        BiliVideoRepository repository = new BiliVideoRepository(null, null, null);
        BiliModels.PlayUrlResponse response = new BiliModels.PlayUrlResponse();
        response.data = new BiliModels.PlayUrlData();
        response.data.dash = new BiliModels.Dash();
        response.data.dash.audio = Arrays.asList(
                media(30216, "mp4a.40.2", "audio-30216"),
                media(30280, "mp4a.40.2", "audio-30280"),
                media(30232, "mp4a.40.2", "audio-30232")
        );

        assertEquals("audio-30280", repository.pickDashAudioUrl(response));
    }

    @Test
    public void pickDashVideoUrl_usesRequestedQnWhenAvailable() {
        BiliVideoRepository repository = new BiliVideoRepository(null, null, null);
        BiliModels.PlayUrlResponse response = new BiliModels.PlayUrlResponse();
        response.data = new BiliModels.PlayUrlData();
        response.data.dash = new BiliModels.Dash();
        response.data.dash.video = Arrays.asList(
                media(80, "avc1.640028", "avc-80"),
                media(64, "avc1.64001F", "avc-64")
        );

        assertEquals("avc-64", repository.pickDashVideoUrl(response, 64));
    }

    @Test
    public void buildQualityOptions_usesAcceptQualityDescriptions() {
        BiliVideoRepository repository = new BiliVideoRepository(null, null, null);
        BiliModels.PlayUrlResponse response = new BiliModels.PlayUrlResponse();
        response.data = new BiliModels.PlayUrlData();
        response.data.acceptQuality = Arrays.asList(80, 64);
        response.data.acceptDescription = Arrays.asList("1080P 高清", "720P 高清");

        List<BiliModels.VideoQuality> options = repository.buildQualityOptions(response);

        assertEquals(0, options.get(0).qn);
        assertEquals("自动", options.get(0).description);
        assertEquals(80, options.get(1).qn);
        assertEquals("1080P 高清", options.get(1).description);
        assertEquals(64, options.get(2).qn);
    }

    @Test
    public void pickMp4Url_fallsBackToBackupUrl() {
        BiliVideoRepository repository = new BiliVideoRepository(null, null, null);
        BiliModels.PlayUrlResponse response = new BiliModels.PlayUrlResponse();
        response.data = new BiliModels.PlayUrlData();
        BiliModels.Durl durl = new BiliModels.Durl();
        durl.backupUrl = Arrays.asList("backup-mp4");
        response.data.durl = Arrays.asList(durl);

        assertEquals("backup-mp4", repository.pickMp4Url(response));
    }

    private static BiliModels.DashMedia media(int id, String codecs, String url) {
        BiliModels.DashMedia media = new BiliModels.DashMedia();
        media.id = id;
        media.codecs = codecs;
        media.baseUrl = url;
        return media;
    }
}
