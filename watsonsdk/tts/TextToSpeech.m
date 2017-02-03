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

#import "TextToSpeech.h"
#import "OpusHelper.h"

typedef void (^PlayAudioCallbackBlockType)(NSError*);

@interface TextToSpeech()<AVAudioPlayerDelegate>
@property OpusHelper* opus;
@property (strong, nonatomic) AVAudioPlayer *audioPlayer;
@property (nonatomic,copy) PlayAudioCallbackBlockType playAudioCallback;
@property (assign, nonatomic) long sampleRate;
@end

@implementation TextToSpeech
@synthesize audioPlayer;
@synthesize playAudioCallback;
@synthesize sampleRate;

/**
 *  Static method to return a SpeechToText object given the service url
 *
 *  @param newURL the service url for the STT service
 *
 *  @return SpeechToText
 */
+(id)initWithConfig:(TTSConfiguration *)config {
    
    TextToSpeech *watson = [[self alloc] initWithConfig:config] ;
    watson.sampleRate = 0;
    return watson;
}

/**
 *  init method to return a SpeechToText object given the service url
 *
 *  @param newURL the service url for the STT service
 *
 *  @return SpeechToText
 */
- (id)initWithConfig:(TTSConfiguration *)config {
    
    self.config = config;
    self.sampleRate = 0;
    // setup opus helper
    self.opus = [[OpusHelper alloc] init];
    
    return self;
}


- (void)synthesize:(DataHandlerWithError) synthesizeHandler theText:(NSString*) text {
    NSMutableDictionary* optHeader = nil;
    if([self.config xWatsonLearningOptOut]) {
        optHeader = [[NSMutableDictionary alloc] init];
        [optHeader setObject:@"true" forKey:@"X-Watson-Learning-Opt-Out"];
    }

    [self performDataGet:synthesizeHandler forURL:[self.config getSynthesizeURL:text] disableCache:NO header:optHeader];
}

- (void)synthesize:(DataHandlerWithError) synthesizeHandler theText:(NSString*) text customizationId:(NSString*) customizationId {
    NSMutableDictionary* optHeader = nil;
    if([self.config xWatsonLearningOptOut]) {
        optHeader = [[NSMutableDictionary alloc] init];
        [optHeader setObject:@"true" forKey:@"X-Watson-Learning-Opt-Out"];
    }
    [self performDataGet:synthesizeHandler forURL:[self.config getSynthesizeURL:text customizationId:customizationId] disableCache:NO header:optHeader];
}

/**
 *  listVoices - List voices supported by the service
 *
 *  @param handler(JSONHandlerType) block to be called when response has been received from the service
 */
- (void)listVoices:(JSONHandlerWithError)handler {
    [SpeechUtility performGet:handler forURL:[self.config getVoicesServiceURL] config:[self config] delegate:self];
}

/**
 *  Creates a new empty custom voice model that is owned by the requesting user
 *
 *  @param customVoice          TTSCustomVoice*
 *  @param customizationHandler JSONHandlerType
 */
- (void)createVoiceModelWithCustomVoice: (TTSCustomVoice*) customVoice handler: (JSONHandlerWithError) customizationHandler {
    NSData* postData = [customVoice producePostData];
    [self performRequest:HTTP_METHOD_POST handler:customizationHandler forURL:[self.config getCustomizationURL] data:postData];
}

/**
 *  Query customized voice models
 *
 *  @param handler JSONHandlerType
 */
- (void)listCustomizedVoiceModels: (JSONHandlerWithError) handler {
    [SpeechUtility performGet:handler forURL:[self.config getCustomizationURL] config:[self config] delegate:self];
}

/**
 *  Simple pronunciation query
 *
 *  @param handler JSONHandlerWithError
 *  @param theText NSString*
 */
- (void)queryPronunciation: (JSONHandlerWithError) handler text:(NSString*) theText {
    [SpeechUtility performGet:handler forURL:[self.config getPronunciationURL: theText] config:[self config] delegate:self];
}

/**
 *  Pronunciation query with parameters
 *
 *  @param handler    JSONHandlerWithError
 *  @param theText    NSString*
 *  @param parameters NSDictionary*
 */
- (void)queryPronunciation: (JSONHandlerWithError) handler text:(NSString*) theText parameters:(NSDictionary*) theParameters {
    [SpeechUtility performGet:handler forURL:[self.config getPronunciationURL: theText parameters:theParameters] config:[self config] delegate:self];
}

/**
 *  Pronunciation query with parameters
 *
 *  @param handler         JSONHandlerWithError
 *  @param theText         NSString*
 *  @param theVoice        NSString*
 *  @param theFormat       NSString*
 *  @param customizationId NSString*
 */
- (void)queryPronunciation: (JSONHandlerWithError) handler text:(NSString*) theText voice: (NSString*) theVoice format: (NSString*) theFormat customizationId: (NSString*) customizationId {
    [SpeechUtility performGet:handler forURL:[self.config getRequestURL:WATSONSDK_SERVICE_PATH_PRONUNCIATION params:@{ @"voice": theVoice, @"format": theFormat, @"customization_id": customizationId }] config:[self config] delegate:self];
}

- (void)addWord:(NSString *)customizationId word:(TTSCustomWord *)customWord handler:(JSONHandlerWithError)customizationHandler {
    NSData* postData = [customWord producePostData];
    NSURL *url = [self.config getCustomizationURL: [NSString stringWithFormat:@"%@/words/%@", customizationId, [[customWord word] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    [self performRequest:HTTP_METHOD_PUT handler:customizationHandler forURL: url data:postData];
}

- (void)addWords:(NSString *)customizationId voice:(TTSCustomVoice *)customVoice handler:(JSONHandlerWithError)customizationHandler {
    NSData* postData = [customVoice producePostData];
    [self performRequest:HTTP_METHOD_POST handler:customizationHandler forURL:[self.config getCustomizationURL: [NSString stringWithFormat:@"%@/words", customizationId]] data:postData];
}

- (void)deleteWord:(NSString *)customizationId word:(NSString *) wordString handler:(JSONHandlerWithError)customizationHandler {
    NSURL *url = [self.config getCustomizationURL: [NSString stringWithFormat:@"%@/words/%@", customizationId, [wordString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    [self performRequest:HTTP_METHOD_DELETE handler:customizationHandler forURL: url data:nil];
}

- (void)listWords:(NSString *)customizationId handler:(JSONHandlerWithError)customizationHandler {
    [SpeechUtility performGet:customizationHandler forURL:[self.config getCustomizationURL: [NSString stringWithFormat:@"%@/words", customizationId]] config:[self config] delegate:self disableCache:YES header:nil];
}

- (void)listWord:(NSString *)customizationId word:(NSString *) wordString handler:(JSONHandlerWithError)customizationHandler {
    NSURL *url = [self.config getCustomizationURL: [NSString stringWithFormat:@"%@/words/%@", customizationId, [wordString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    [self performRequest:HTTP_METHOD_GET handler:customizationHandler forURL: url data:nil];
}

- (void)updateVoiceModelWithCustomVoice:(NSString *)customizationId voice:(TTSCustomVoice *)customVoice handler:(JSONHandlerWithError)customizationHandler {
    NSData* postData = [customVoice producePostData];
    [self performRequest:HTTP_METHOD_POST handler: customizationHandler forURL:[self.config getCustomizationURL: customizationId] data:postData];
}

- (void)deleteVoiceModel:(NSString *)customizationId handler:(JSONHandlerWithError)customizationHandler {
    [self performRequest:HTTP_METHOD_DELETE handler: customizationHandler forURL:[self.config getCustomizationURL: customizationId] data:nil];
}

#pragma mark private methods

/**
 *  Play audio data
 *
 *  @param audioHandler Audio handler
 *  @param audio        Audio data
 *  @param rate         Sample rate
 */
- (void) playAudio:(void (^)(NSError*)) audioHandler withData:(NSData *) audio sampleRate:(long) rate {
    self.playAudioCallback = audioHandler;
    
    self.sampleRate = rate;

    if([self.config.audioCodec isEqualToString:WATSONSDK_TTS_AUDIO_CODEC_TYPE_WAV]){
        NSError * err;

        audio = [self stripAndAddWavHeader:audio];
        self.audioPlayer = [[AVAudioPlayer alloc] initWithData:audio error:&err];

        if (!self.audioPlayer)
            self.playAudioCallback(err);
        else
            [self.audioPlayer play];
        
    } else if ([self.config.audioCodec isEqualToString:WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS]) {
        NSError * err = nil;

        // convert audio to PCM and add wav header
        audio = [self.opus opusToPCM:audio sampleRate:self.sampleRate];
        audio = [SpeechUtility addWavHeader:audio rate:self.sampleRate];

        self.audioPlayer = [[AVAudioPlayer alloc] initWithData:audio error:&err];
        [self.audioPlayer setDelegate:self];
        if (!self.audioPlayer)
            self.playAudioCallback(err);
        else
            [self.audioPlayer play];
    }
}

/**
 *  Play audio data
 *
 *  @param audioHandler Audio handler
 *  @param audio        Audio data
 */
- (void) playAudio:(void (^)(NSError*)) audioHandler withData:(NSData *) audio {
    if([self.config.audioCodec isEqualToString:WATSONSDK_TTS_AUDIO_CODEC_TYPE_WAV]){
        self.sampleRate = WATSONSDK_TTS_AUDIO_CODEC_TYPE_WAV_SAMPLE_RATE;
    }
    else if ([self.config.audioCodec isEqualToString:WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS]) {
        self.sampleRate = WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS_SAMPLE_RATE;
    }
    [self playAudio:audioHandler withData:audio sampleRate: self.sampleRate];
}

- (void)stopAudio {
    [self.audioPlayer stop];
    [self.audioPlayer setDelegate:nil];
    self.audioPlayer = nil;
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player
                                 error:(NSError *)error {
    self.playAudioCallback(error);
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player
                       successfully:(BOOL)flag {
   self.playAudioCallback(nil);
}

/**
 *  stripAndAddWavHeader - removes the wav header and metadata from downloaded TTS wav file which does not contain file length
 *  iOS avaudioplayer will not play the wav without the correct headers so we must recreate them
 *
 *  @param wav NSData containing audio
 *
 *  @return NSData with corrected wav header
 */
-(NSData*) stripAndAddWavHeader:(NSData*) wav {

    int headerSize = 44;
    int metadataSize = 48;

    if(sampleRate == 0 && [wav length] > 28)
        [wav getBytes:&sampleRate range: NSMakeRange(24, 4)]; // Read wav sample rate from 24

    NSData *wavNoheader = [NSMutableData dataWithData:[wav subdataWithRange:NSMakeRange(headerSize+metadataSize, [wav length])]];
    
    NSMutableData *newWavData;
    newWavData = [SpeechUtility addWavHeader:wavNoheader rate:sampleRate];

    return newWavData;
}

-(void) saveAudio:(NSData*) audio toFile:(NSString*) path {
    
    [audio writeToFile:path atomically:true];
}

/**
 *  performGet - shared method for performing GET requests to a given url calling a handler parameter with the result
 *
 *  @param handler DataHandlerType
 *  @param url     url to perform GET request on
 */
- (void) performDataGet:(DataHandlerWithError)handler forURL:(NSURL*)url disableCache:(BOOL) withoutCache header:(NSDictionary*) extraHeader {
    [self.config requestToken:^(BaseConfiguration *config) {
        // Create and set authentication headers
        NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
        
        if(withoutCache)
            [defaultConfigObject setURLCache:nil];
        NSMutableDictionary* headers = [config createRequestHeaders];
        if(config.xWatsonLearningOptOut) {
            [headers setObject:@"true" forKey:@"X-Watson-Learning-Opt-Out"];
        }
        [defaultConfigObject setHTTPAdditionalHeaders:headers];
        NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: self delegateQueue: [NSOperationQueue mainQueue]];
        NSURLSessionDataTask * dataTask = [defaultSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [SpeechUtility processData:handler config:config response:response data:data error:error];
        }];
        
        [dataTask resume];
    } refreshCache:NO];
}

/**
 *  performRequest - shared method for performing RESTful requests to a given url calling a handler parameter with the result
 *
 *  @param method               restful method
 *  @param customizationHandler data handler
 *  @param url                  URL
 *  @param httpBody             content
 */
- (void) performRequest: (NSString*) method handler: (JSONHandlerWithError)customizationHandler forURL:(NSURL*)url data: (NSData*) httpBody {
    // Create and set authentication headers
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];

    [self.config requestToken:^(BaseConfiguration *config) {
        NSDictionary* headers = [config createRequestHeaders];
        [defaultConfigObject setHTTPAdditionalHeaders:headers];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod: method];

        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:httpBody];

        NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: self delegateQueue: [NSOperationQueue mainQueue]];
        NSURLSessionDataTask * dataTask = [defaultSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [SpeechUtility processJSON:customizationHandler response:response data:data error:error];
        }];

        [dataTask resume];
    } refreshCache:NO];
}

@end
