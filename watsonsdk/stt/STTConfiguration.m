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

#import "STTConfiguration.h"

@implementation STTConfiguration

@synthesize audioSampleRate = _audioSampleRate;
@synthesize audioFrameSize = _audioFrameSize;

/**
 *  Initialize parameters with default values according to Speech Service documentation
 *
 *  @return id
 */
- (id)init {
    self = [super init];

    // set default values according to the service
    [self setApiEndpoint:[NSURL URLWithString:WATSONSDK_DEFAULT_STT_API_ENDPOINT]];
    [self setModelName:WATSONSDK_DEFAULT_STT_MODEL];
    [self setAudioCodec:WATSONSDK_AUDIO_CODEC_TYPE_PCM];
    [self setAudioSampleRate:WATSONSDK_AUDIO_SAMPLE_RATE_PCM];
    [self setAudioFrameSize:WATSONSDK_AUDIO_FRAME_SIZE_PCM];

    [self setInterimResults: NO];
    [self setContinuous: NO];
    [self setInactivityTimeout:[NSNumber numberWithInt:WATSONSDK_INACTIVITY_TIMEOUT]];

    [self setKeywordsThreshold:[NSNumber numberWithDouble:-1]];
    [self setMaxAlternatives:[NSNumber numberWithInt:1]];
    [self setWordAlternativesThreshold:[NSNumber numberWithDouble:-1]];
    [self setKeywords:nil];
    [self setProfanityFilter:YES];
    [self setSmartFormatting:NO];
    [self setTimestamps:NO];
    [self setWordConfidence:NO];

    return self;
}


#pragma mark convenience methods for obtaining service URLs

/**
 *  Service URL of loading model
 *
 *  @return NSURL*
 */
- (NSURL*)getModelsServiceURL {
    return [self getRequestURL:WATSONSDK_SERVICE_PATH_MODELS params:nil];
}

/**
 *  Service URL of loading model with model name
 *
 *  @param modelName NSString*
 *
 *  @return NSURL
 */
- (NSURL*)getModelServiceURL:(NSString*) modelName {
    return [self getRequestURL:[NSString stringWithFormat:@"%@/%@", WATSONSDK_SERVICE_PATH_MODELS, modelName] params:nil];
}

/**
 *  WebSockets URL of Speech Recognition
 *
 *  @return NSURL*
 */
- (NSURL*)getWebSocketRecognizeURL {
    if([self.modelName isEqualToString:WATSONSDK_DEFAULT_STT_MODEL]) {
        return [self getRequestURL:WATSONSDK_SERVICE_PATH_RECOGNIZE params:nil isWebSocket:YES];
    }
    return [self getRequestURL:WATSONSDK_SERVICE_PATH_RECOGNIZE params: @{ @"model": self.modelName } isWebSocket:YES];
}

/**
 *  Organize JSON string for start message of WebSockets
 *
 *  @return NSString*
 */
- (NSString*)getStartMessage {
    NSString *jsonString = @"";

    NSMutableDictionary *inputParameters = [[NSMutableDictionary alloc] init];
    [inputParameters setValue:@"start" forKey:@"action"];
    [inputParameters setValue:[NSString stringWithFormat:@"%@;rate=%d", self.audioCodec, self.audioSampleRate] forKey:@"content-type"];
    
    if(self.interimResults) {
        [inputParameters setValue:@"true" forKey:@"interim_results"];
    }

    if([self.inactivityTimeout intValue] != WATSONSDK_INACTIVITY_TIMEOUT) {
        [inputParameters setValue:self.inactivityTimeout forKey:@"inactivity_timeout"];
    }

    if(self.continuous) {
        [inputParameters setValue:@"true" forKey:@"continuous"];
    }

    if([self.maxAlternatives intValue] > 1) {
        [inputParameters setValue:self.maxAlternatives forKey:@"max_alternatives"];
    }

    if([self.keywordsThreshold doubleValue] >= 0 && [self.keywordsThreshold doubleValue] <= 1) {
        [inputParameters setValue:self.keywordsThreshold forKey:@"keywords_threshold"];
    }

    if([self.wordAlternativesThreshold doubleValue] >= 0 && [self.wordAlternativesThreshold doubleValue] <= 1) {
        [inputParameters setValue:self.wordAlternativesThreshold forKey:@"word_alternatives_threshold"];
    }

    if(self.keywords && [self.keywords count] > 0) {
        [inputParameters setValue:self.keywords forKey:@"keywords"];
    }

    if(self.smartFormatting) {
        [inputParameters setValue:@"true" forKey:@"smart_formatting"];
    }

    if(self.timestamps) {
        [inputParameters setValue:@"true" forKey:@"timestamps"];
    }
    
    if(self.profanityFilter == NO) {
        [inputParameters setValue:@"false" forKey:@"profanity_filter"];
    }

    if(self.wordConfidence) {
        [inputParameters setValue:@"false" forKey:@"word_confidence"];
    }

    if([NSJSONSerialization isValidJSONObject:inputParameters]){
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:inputParameters options:NSJSONWritingPrettyPrinted error:&error];
        if(error == nil)
            jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return jsonString;
}

/**
 *  Write stop message to WebSocket
 *
 *  @return NSData*
 */
- (NSData *)getStopMessage {
    NSData *data = nil;
    data = [NSMutableData dataWithLength:0];
    // JSON format does not work because we're sending out the binary
//    NSMutableDictionary *inputParameters = [[NSMutableDictionary alloc] init];
//    [inputParameters setValue:@"stop" forKey:@"action"];
//
//    if([NSJSONSerialization isValidJSONObject:inputParameters]){
//        NSError *error = nil;
//        data = [NSJSONSerialization dataWithJSONObject:inputParameters options:NSJSONWritingPrettyPrinted error:&error];
//    }
//
//    if(data == nil) {
//        data = [NSMutableData dataWithLength:0];
//    }

    return data;
}

@end
