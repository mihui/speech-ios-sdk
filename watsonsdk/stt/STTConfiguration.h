/**
 * Copyright IBM Corporation 2015
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

#import <Foundation/Foundation.h>
#import "AuthConfiguration.h"

// URLS
#define WATSONSDK_DEFAULT_STT_API_ENDPOINT @"https://stream.watsonplatform.net/speech-to-text/api/"
#define WATSONSDK_SERVICE_PATH_MODELS @"/v1/models"
#define WATSONSDK_SERVICE_PATH_v1 @"/v1"
#define WATSONSDK_SERVICE_PATH_RECOGNIZE @"/recognize"
#define WEBSOCKETS_SCHEME @"wss://"

// codecs
#define WATSONSDK_AUDIO_CODEC_TYPE_PCM @"audio/l16;rate=16000"
//#define WATSONSDK_AUDIO_CODEC_TYPE_WAV @"audio/wav"
//#define WATSONSDK_AUDIO_CODEC_TYPE_FLAC @"audio/flac"
#define WATSONSDK_AUDIO_CODEC_TYPE_OPUS @"audio/ogg;codecs=opus"
#define WATSONSDK_AUDIO_FRAME_SIZE 160
#define WATSONSDK_AUDIO_SAMPLE_RATE 16000.0

// models
#define WATSONSDK_DEFAULT_STT_MODEL @"en-US_BroadbandModel"

#define WATSONSDK_STREAM_MARKER_DATA 1
#define WATSONSDK_STREAM_MARKER_END 2

@interface STTConfiguration : AuthConfiguration

@property NSString *modelName;
@property NSString *audioCodec;
@property BOOL interimResults;
@property BOOL continuous;
@property NSNumber *inactivityTimeout;
@property NSNumber *connectionTimeout;
@property NSNumber *keywordsThreshold;
@property NSNumber *maxAlternatives;
@property NSNumber *wordAlternativesThreshold;
@property NSArray *keywords;

@property float audioSampleRate;
@property int audioFrameSize;

- (id)init;
- (NSURL*)getModelsServiceURL;
- (NSURL*)getModelServiceURL:(NSString*) modelName;
- (NSURL*)getWebSocketRecognizeURL;
- (NSString *)getStartMessage;
- (NSData *)getStopMessage;

@end
