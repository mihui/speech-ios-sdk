/**
 * Copyright IBM Corporation 2017
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

#import "TTSConfiguration.h"

@implementation TTSConfiguration

- (id)init {
    self = [super init];

    // set default values
    [self setApiEndpoint:[NSURL URLWithString:WATSONSDK_DEFAULT_TTS_API_ENDPOINT]];
    [self setVoiceName:WATSONSDK_DEFAULT_TTS_VOICE];
    [self setAudioCodec:WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS];

    return self;
}

#pragma mark convenience methods for obtaining service URLs

- (NSURL*) getVoicesServiceURL {
    return [self getRequestURL:WATSONSDK_SERVICE_PATH_VOICES params:nil];
}

/**
 *  Get synthesize URL
 *
 *  @param text            NSString*
 *
 *  @return NSURL*
 */
- (NSURL*)getSynthesizeURL:(NSString*) text {
    NSDictionary *query = @{ @"voice": self.voiceName, @"accept": self.audioCodec, @"text": text };
    return [self getRequestURL:WATSONSDK_SERVICE_PATH_SYNTHESIZE params:query];
}

/**
 *  Get synthesize URL of customize id
 *
 *  @param text            NSString*
 *  @param customizationId NSString*
 *
 *  @return NSURL*
 */
- (NSURL*)getSynthesizeURL:(NSString*) text customizationId:(NSString*) customizationId {
    if(customizationId == nil) {
        return [self getSynthesizeURL:text];
    }
    NSDictionary *query = @{ @"voice": self.voiceName, @"accept": self.audioCodec, @"text": text, @"customization_id": customizationId };
    return [self getRequestURL:WATSONSDK_SERVICE_PATH_SYNTHESIZE params:query];
}

/**
 *  Get customization URL
 *
 *  @return NSURL*
 */
- (NSURL*)getCustomizationURL {
    return [self getRequestURL:WATSONSDK_SERVICE_PATH_CUSTOMIZATIONS params:nil];
}

/**
 *  Get customization URL by specifying customization id
 *
 *  @param customizationId NSString*
 *
 *  @return NSURL*
 */
- (NSURL*)getCustomizationURL:(NSString*) customizationId {
    return [self getRequestURL:[NSString stringWithFormat:@"%@/%@", WATSONSDK_SERVICE_PATH_CUSTOMIZATIONS, customizationId] params:nil];
}

/**
 *  Get pronunciation URL
 *
 *  @param text NSString*
 *
 *  @return NSString*
 */
- (NSURL*)getPronunciationURL: (NSString*) text {
    NSDictionary *query = @{ @"text": text };
    return [self getRequestURL:WATSONSDK_SERVICE_PATH_PRONUNCIATION params:query];
}

/**
 *  Get pronunciation URL
 *
 *  @param text      NSString*
 *  @param theVoice  NSString*
 *  @param theFormat NSString*
 *  @deprecated
 *
 *  @return NSURL*
 */
- (NSURL*)getPronunciationURL: (NSString*) text parameters:(NSDictionary*) theParameters {
    NSMutableDictionary *query = [NSMutableDictionary dictionaryWithDictionary:theParameters];
    [query setObject:text forKey:@"text"];
    return [self getRequestURL:WATSONSDK_SERVICE_PATH_PRONUNCIATION params:query];
}

@end
