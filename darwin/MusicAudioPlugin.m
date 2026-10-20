// Player registration is adapted from just_audio 0.10.6 (MIT).
// Copyright (c) 2019-2020 Ryan Heise and the project contributors.
// See third_party/just_audio-LICENSE.
#import "MusicAudioPlugin.h"
#import <just_audio/AudioPlayer.h>
#import <MediaToolbox/MediaToolbox.h>
#include <stdatomic.h>
#include <math.h>

typedef struct {
    _Atomic(float) gain;
    AudioStreamBasicDescription format;
} MusicGain;

static void GainInit(MTAudioProcessingTapRef tap, void *clientInfo, void **storage) {
    *storage = clientInfo;
}

static void GainFinalize(MTAudioProcessingTapRef tap) {
    free(MTAudioProcessingTapGetStorage(tap));
}

static void GainPrepare(MTAudioProcessingTapRef tap, CMItemCount frames,
                        const AudioStreamBasicDescription *format) {
    ((MusicGain *)MTAudioProcessingTapGetStorage(tap))->format = *format;
}

static void GainUnprepare(MTAudioProcessingTapRef tap) {}

static void GainProcess(MTAudioProcessingTapRef tap, CMItemCount frames,
                        MTAudioProcessingTapFlags flags, AudioBufferList *buffers,
                        CMItemCount *framesOut, MTAudioProcessingTapFlags *flagsOut) {
    OSStatus status = MTAudioProcessingTapGetSourceAudio(
        tap, frames, buffers, flagsOut, NULL, framesOut);
    if (status != noErr) { *framesOut = 0; return; }
    MusicGain *state = MTAudioProcessingTapGetStorage(tap);
    float gain = atomic_load_explicit(&state->gain, memory_order_relaxed);
    if (gain == 1) return;
    // The tap delivers native PCM. Bound amplified peaks to the PCM range.
    for (UInt32 b = 0; b < buffers->mNumberBuffers; b++) {
        AudioBuffer buffer = buffers->mBuffers[b];
        UInt32 count = (UInt32)*framesOut * buffer.mNumberChannels;
        if (state->format.mFormatFlags & kAudioFormatFlagIsFloat) {
            if (state->format.mBitsPerChannel == 32) {
                float *samples = buffer.mData;
                for (UInt32 i = 0; i < count; i++)
                    samples[i] = fmaxf(-1, fminf(1, samples[i] * gain));
            } else if (state->format.mBitsPerChannel == 64) {
                double *samples = buffer.mData;
                for (UInt32 i = 0; i < count; i++)
                    samples[i] = fmax(-1, fmin(1, samples[i] * gain));
            }
        } else if (state->format.mFormatFlags & kAudioFormatFlagIsSignedInteger) {
            if (state->format.mBitsPerChannel == 16) {
                int16_t *samples = buffer.mData;
                for (UInt32 i = 0; i < count; i++)
                    samples[i] = (int16_t)fmax(-32768, fmin(32767, samples[i] * gain));
            } else if (state->format.mBitsPerChannel == 32) {
                int32_t *samples = buffer.mData;
                for (UInt32 i = 0; i < count; i++)
                    samples[i] = (int32_t)fmax(INT32_MIN, fmin(INT32_MAX, (double)samples[i] * gain));
            }
        }
    }
}

// The per-player method channel remains owned by just_audio.
@interface AudioPlayer (MusicMethods)
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result;
@end

@interface MusicGainPlayer : AudioPlayer
@end

@implementation MusicGainPlayer {
    MTAudioProcessingTapRef _tap;
    __weak AVPlayerItem *_gainItem;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if (![call.method isEqualToString:@"setVolume"]) {
        [super handleMethodCall:call result:result];
        return;
    }
    double volume = [call.arguments[@"volume"] doubleValue];
    AVPlayerItem *item = self.player.currentItem;
    if (_gainItem != item) {
        if (_tap) { CFRelease(_tap); _tap = NULL; }
        _gainItem = nil;
    }
    if (volume > 1 && item && !_tap) {
        AVAssetTrack *track = [item.asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
        if (!track) {
            result([FlutterError errorWithCode:@"music_gain" message:@"无法读取音频轨道" details:nil]);
            return;
        }
        MusicGain *gain = calloc(1, sizeof(MusicGain));
        atomic_init(&gain->gain, (float)volume);
        MTAudioProcessingTapCallbacks callbacks = {
            kMTAudioProcessingTapCallbacksVersion_0, gain,
            GainInit, GainFinalize, GainPrepare, GainUnprepare, GainProcess
        };
        OSStatus status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &_tap);
        if (status != noErr) {
            free(gain);
            result([FlutterError errorWithCode:@"music_gain" message:@"无法调整音频增益" details:@(status)]);
            return;
        }
        AVMutableAudioMixInputParameters *input =
            [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:track];
        input.audioTapProcessor = _tap;
        AVMutableAudioMix *mix = [AVMutableAudioMix audioMix];
        mix.inputParameters = @[input];
        item.audioMix = mix;
        _gainItem = item;
    }
    if (_tap) {
        MusicGain *gain = MTAudioProcessingTapGetStorage(_tap);
        atomic_store_explicit(&gain->gain, (float)MAX(1, volume), memory_order_relaxed);
    }
    // AVPlayer.volume is restricted to 0..1; the tap handles the extra gain.
    NSMutableDictionary *arguments = [call.arguments mutableCopy];
    arguments[@"volume"] = @(MIN(1, volume));
    [super handleMethodCall:[FlutterMethodCall methodCallWithMethodName:@"setVolume" arguments:arguments]
                    result:result];
}

- (void)dealloc {
    if (_tap) CFRelease(_tap);
}
@end

@implementation MusicAudioPlugin {
    NSObject<FlutterPluginRegistrar> *_registrar;
    NSMutableDictionary<NSString *, MusicGainPlayer *> *_players;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel
        methodChannelWithName:@"com.ryanheise.just_audio.methods"
        binaryMessenger:registrar.messenger];
    MusicAudioPlugin *instance = [[self alloc] init];
    instance->_registrar = registrar;
    instance->_players = [NSMutableDictionary dictionary];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSDictionary *args = call.arguments;
    NSString *playerId = args[@"id"];
    if ([call.method isEqualToString:@"init"]) {
        if (_players[playerId]) {
            result([FlutterError errorWithCode:@"error" message:@"Platform player already exists" details:nil]);
            return;
        }
        _players[playerId] = [[MusicGainPlayer alloc]
            initWithRegistrar:_registrar playerId:playerId
            loadConfiguration:args[@"audioLoadConfiguration"]
            useLazyPreparation:[args[@"useLazyPreparation"] boolValue]];
        result(nil);
    } else if ([call.method isEqualToString:@"disposePlayer"]) {
        [_players[playerId] dispose:NO];
        [_players removeObjectForKey:playerId];
        result(@{});
    } else if ([call.method isEqualToString:@"disposeAllPlayers"]) {
        for (MusicGainPlayer *player in _players.allValues) [player dispose:NO];
        [_players removeAllObjects];
        result(@{});
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)dealloc {
    for (MusicGainPlayer *player in _players.allValues) [player dispose:YES];
}
@end
