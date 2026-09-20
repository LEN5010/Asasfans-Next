# Synthetic playback fixture

`playback-test.mp4` is an eight-second, locally generated H.264/AAC test pattern with silent audio. It contains no third-party media or account data, is packaged only in the test APK, and is not a build artifact for distribution.

Reproduction:

```sh
ffmpeg -f lavfi -i testsrc2=size=160x90:rate=15 \
  -f lavfi -i anullsrc=r=44100:cl=mono -t 8 \
  -c:v libx264 -pix_fmt yuv420p -preset fast -crf 32 \
  -c:a aac -b:a 24k -movflags +faststart playback-test.mp4
```

The instrumentation test serves it through a local range-aware MockWebServer and exercises the real Media3 decoder and video surface. This does not prove live Bilibili playback, DASH synchronization, or long-duration stability.
