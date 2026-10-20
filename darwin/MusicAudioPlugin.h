#include <TargetConditionals.h>
#if TARGET_OS_OSX
#import <FlutterMacOS/FlutterMacOS.h>
#else
#import <Flutter/Flutter.h>
#endif

// Keeps just_audio's playback implementation, adding PCM gain above unity.
@interface MusicAudioPlugin : NSObject<FlutterPlugin>
@end
