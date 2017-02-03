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
#import <SpeechToText.h>
#import "WebSocketAudioStreamer.h"
#import "OpusHelper.h"

#define NUM_BUFFERS 3

typedef struct
{
    AudioStreamBasicDescription  dataFormat;
    AudioQueueRef                queue;
    AudioQueueBufferRef          buffers[NUM_BUFFERS];
    AudioFileID                  audioFile;
    SInt64                       currentPacket;
    bool                         recording;
    int                          slot;
} RecordingState;

@interface SpeechToText()

@property NSString* pathPCM;
@property NSTimer *PeakPowerTimer;
@property RecordingState recordState;
@property WebSocketAudioStreamer* audioStreamer;
@property (nonatomic, copy) JSONHandlerWithError recognizeCallback;
@property (nonatomic, copy) PowerLevelHandler powerLevelCallback;

@end

@implementation SpeechToText

@synthesize recognizeCallback;
@synthesize powerLevelCallback;
@synthesize audioDataCallback;

// static for use by c code
static BOOL isNewRecordingAllowed;
static int audioFrameSize;

BOOL isPermissionGranted = NO;

id audioStreamerRef;

#pragma mark public methods

/**
 *  Static method to return a SpeechToText object given the service url
 *
 *  @param newURL the service url for the STT service
 *
 *  @return SpeechToText
 */
+(id)initWithConfig:(STTConfiguration *)config {
    SpeechToText *watson = [[self alloc] initWithConfig:config] ;
    return watson;
}

/**
 *  init method to return a SpeechToText object given the service url
 *
 *  @param newURL the service url for the STT service
 *
 *  @return SpeechToText
 */
- (id)initWithConfig:(STTConfiguration *)config {
    self.config = config;
    // set audio encoding flags so they are accessible in c audio callbacks
    audioFrameSize = config.audioFrameSize;
    isNewRecordingAllowed = YES;

    return self;
}

/**
 *  Start recognize
 */
- (void)startRecognizing {
    if(isNewRecordingAllowed) {
        // don't allow a new recording to be allowed until this transaction has completed
        isNewRecordingAllowed = NO;
        [self startRecordingAudio];
    }
}

/**
 *  stream audio from the device microphone to the STT service
 *
 *  @param recognizeHandler (^)(JSONHandlerType)
 */
- (void) recognize:(JSONHandlerWithError) recognizeHandler{
    [self recognize:recognizeHandler dataHandler:nil powerHandler:nil];
}

/**
 *  stream audio from the device microphone to the STT service
 *
 *  @param recognizeHandler JSONHandlerType
 *  @param dataHandler      data handler
 */
- (void) recognize:(JSONHandlerWithError) recognizeHandler dataHandler: (DataHandler) dataHandler {
    [self recognize:recognizeHandler dataHandler:dataHandler powerHandler:nil];
}

/**
 *  stream audio from the device microphone to the STT service
 *
 *  @param recognizeHandler JSONHandlerType
 *  @param powerHandler PowerLevelHandler
 */
- (void) recognize:(JSONHandlerWithError) recognizeHandler powerHandler: (PowerLevelHandler) powerHandler {
    [self recognize:recognizeHandler dataHandler:nil powerHandler:powerHandler];
}

/**
 *  stream audio from the device microphone to the STT service
 *
 *  @param recognizeHandler JSONHandlerType
 *  @param dataHandler DataHandler
 *  @param powerHandler PowerLevelHandler
 */
- (void) recognize:(JSONHandlerWithError) recognizeHandler dataHandler: (DataHandler) dataHandler powerHandler: (PowerLevelHandler) powerHandler {

    self.recognizeCallback = recognizeHandler;
    self.audioDataCallback = dataHandler;
    self.powerLevelCallback = powerHandler;

    if(isPermissionGranted) {
        [self startRecognizing];
        return;
    }

    if([[AVAudioSession sharedInstance] respondsToSelector:@selector(requestRecordPermission:)]) {
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            NSLog(@"Microphone access: %@", granted?@"Yes":@"No");
            isPermissionGranted = granted;
            if (granted) {
                // Permission granted
                [self startRecognizing];
            }
            else {
                // Permission denied
                NSError *recordError = [SpeechUtility raiseErrorWithCode:WATSON_PERMISSION_ERROR_CODE message:@"Permission denied"];
                self.recognizeCallback(nil, recordError);
            }
        }];
    }
    // NSError *recordError = [SpeechUtility raiseErrorWithMessage:@"A voice query is already in progress"];
    // self.recognizeCallback(nil, recordError);
}

/**
 *  send out end marker of a stream
 *
 *  @return YES if the data has been sent directly; NO if the data is bufferred because the connection is not established
 */
-(void) endTransmission {
    [[self audioStreamer] writeEndMarker];
}

/**
 *  Disconnect
 */
-(void) endConnection {
    [[self audioStreamer] disconnect:@"Manually terminating socket connection"];
}

/**
 *  stopRecording and streaming audio from the device microphone
 *
 *  @return void
 */
-(void) endRecognize {
    [self stopRecordingAudio];
    [self endTransmission];
}

/**
 *  listModels - List speech models supported by the service
 *
 *  @param handler(JSONHandlerType) block to be called when response has been received from the service
 */
- (void) listModels:(JSONHandlerWithError)handler {
    [SpeechUtility performGet:handler forURL:[self.config getModelsServiceURL] config:[self config] delegate:self];
}

/**
 *  listModel details with a given model ID
 *
 *  @param handler handler(JSONHandlerType) block to be called when response has been received from the service
 *  @param modelName the name of the model e.g. WatsonModel
 */
- (void) listModel:(JSONHandlerWithError)handler withName:(NSString*) modelName {
    
    [SpeechUtility performGet:handler forURL:[self.config getModelServiceURL:modelName] config:[self config] delegate:self];
    
}

/**
 *  getTranscript - convenience method to get the transcript from the JSON results
 *
 *  @param results NSDictionary containing parsed JSON returned from the service
 *
 *  @return NSString containing transcript
 */
-(SpeechToTextResult*) getResult:(NSDictionary*) results {
    SpeechToTextResult *sttResult = [[SpeechToTextResult alloc] init];

    if([results objectForKey:@"results"] != nil) {

        NSArray *resultArray = [results objectForKey:@"results"];

        if([resultArray count] != 0 && [resultArray objectAtIndex:0] != nil) {

            NSDictionary *result =[resultArray objectAtIndex:0];

            NSArray *alternatives = [result objectForKey:@"alternatives"];
            
            if([result objectForKey:@"final"] != nil)
                sttResult.isFinal = [[result objectForKey:@"final"] boolValue];
            
            if([result objectForKey:@"complete"] != nil)
                sttResult.isCompleted = [[result objectForKey:@"complete"] boolValue];

            if([alternatives objectAtIndex:0] != nil) {
                NSDictionary *alternative = [alternatives objectAtIndex:0];

                if([alternative objectForKey:@"transcript"] != nil) {
                    sttResult.transcript = [alternative objectForKey:@"transcript"];
                }
                if([alternative objectForKey:@"confidence"] != nil) {
                    sttResult.confidenceScore = [alternative objectForKey:@"confidence"];
                }
            }
        }
    }
    return sttResult;
}

/**
 *  getPowerLevel - listen for updates to the Db level of the speaker, can be used for a voice wave visualization
 *
 *  @param powerHandler - callback block
 */
- (void) getPowerLevel:(PowerLevelHandler) powerHandler {
    self.powerLevelCallback = powerHandler;
}

#pragma mark private methods

/**
 *  Start recording audio
 */
- (void) startRecordingAudio {
    // lets start the socket connection right away
    [self initializeStreaming];
    [self setupAudioFormat:&_recordState.dataFormat];
    
    _recordState.currentPacket = 0;
    
    OSStatus status = AudioQueueNewInput(&_recordState.dataFormat,
                                         AudioInputStreamingCallback,
                                         &_recordState,
                                         CFRunLoopGetCurrent(),
                                         kCFRunLoopCommonModes,
                                         0,
                                         &_recordState.queue);

    if(status == 0) {
        
        for(int i = 0; i < NUM_BUFFERS; i++) {
            AudioQueueAllocateBuffer(_recordState.queue, _recordState.dataFormat.mSampleRate, &_recordState.buffers[i]);
            AudioQueueEnqueueBuffer(_recordState.queue, _recordState.buffers[i], 0, NULL);
        }

        _recordState.recording = true;
        status = AudioQueueStart(_recordState.queue, NULL);
        if (status == 0) {

            UInt32 enableMetering = 1;
            status = AudioQueueSetProperty(_recordState.queue, kAudioQueueProperty_EnableLevelMetering, &enableMetering, sizeof(enableMetering));

            // start peak power timer
            if(status == 0){
                self.PeakPowerTimer = [NSTimer scheduledTimerWithTimeInterval:0.125
                                                                       target:self
                                                                     selector:@selector(samplePeakPower)
                                                                     userInfo:nil
                                                                      repeats:YES];
            }
        }
    }
}

/**
 *  Stop recording
 */
- (void) stopRecordingAudio {
    if(isNewRecordingAllowed) {
        NSLog(@"### Record stopped ###");
        return;
    }
    NSLog(@"### Stopping recording ###");
    if(self.PeakPowerTimer)
        [self.PeakPowerTimer invalidate];

    self.PeakPowerTimer = nil;

    if(_recordState.queue != NULL){
        AudioQueueReset(_recordState.queue);
    }
    if(_recordState.queue != NULL){
        AudioQueueStop(_recordState.queue, YES);
    }
    if(_recordState.queue != NULL){
        AudioQueueDispose(_recordState.queue, YES);
    }
    isNewRecordingAllowed = YES;
}

/**
 *  samplePeakPower - Get the decibel level from the AudioQueue
 */
- (void) samplePeakPower {
    AudioQueueLevelMeterState meters[1];
    UInt32 dlen = sizeof(meters);
    OSErr Status = AudioQueueGetProperty(_recordState.queue,kAudioQueueProperty_CurrentLevelMeterDB,meters,&dlen);

    if (Status == 0) {
        if(self.powerLevelCallback != nil) {
            self.powerLevelCallback(meters[0].mAveragePower);
        }
    }
}

#pragma mark audio streaming

/**
 *  Initialize streaming
 */
- (void) initializeStreaming {

    // init the websocket streamer
    self.audioStreamer = [[WebSocketAudioStreamer alloc] init];
    [self.audioStreamer setRecognizeHandler:recognizeCallback];
    [self.audioStreamer setAudioDataHandler:audioDataCallback];

    // connect if we are not connected
    if(![self.audioStreamer isWebSocketConnected]) {
        [self.config requestToken:^(BaseConfiguration *config) {
            [self.audioStreamer connect:(STTConfiguration*)config
                                headers:[config createRequestHeaders]
                     completionCallback:^(NSInteger code, NSString* reason)
            {
                [self stopRecordingAudio];
                [self endConnection];

                NSMutableDictionary *closureResult = [[NSMutableDictionary alloc] init];
                NSMutableArray *results = [[NSMutableArray alloc] init];
                NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
//                NSMutableArray *alternatives = [[NSMutableArray alloc] init];
//                NSMutableDictionary *details = [[NSMutableDictionary alloc] init];

//                [details setObject:@"" forKey:@"transcript"];
//                [details setObject:[NSNumber numberWithDouble:0.000] forKey:@"confidence"];

//                [alternatives setObject:details atIndexedSubscript:0];
//                [result setObject:alternatives forKey:@"alternatives"];
                [result setObject:[NSNumber numberWithBool:YES] forKey:@"complete"];
                [result setObject:[NSNumber numberWithBool:YES] forKey:@"final"];

                [results setObject:result atIndexedSubscript:0];
                [closureResult setObject:results forKey:@"results"];
                [closureResult setObject:[NSNumber numberWithInt:0] forKey:@"result_index"];
                self.recognizeCallback(closureResult, nil);
            }];
        } refreshCache:NO];
    }

    // Writting header
    [self.audioStreamer writeHeader];

    // set a pointer to the wsuploader class so it is accessible in the c callback
    audioStreamerRef = self.audioStreamer;
}

#pragma mark audio

- (void)setupAudioFormat:(AudioStreamBasicDescription*)format
{
    format->mSampleRate = _config.audioSampleRate;
    format->mFormatID = kAudioFormatLinearPCM;
    format->mFramesPerPacket = 1;
    format->mChannelsPerFrame = 1;
    format->mBytesPerFrame = 2;
    format->mBytesPerPacket = 2;
    format->mBitsPerChannel = 16;
    format->mReserved = 0;
    format->mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
}

#pragma mark audio callbacks

void AudioInputStreamingCallback(
                                 void *inUserData,
                                 AudioQueueRef inAQ,
                                 AudioQueueBufferRef inBuffer,
                                 const AudioTimeStamp *inStartTime,
                                 UInt32 inNumberPacketDescriptions,
                                 const AudioStreamPacketDescription *inPacketDescs)
{
    OSStatus status = 0;
    RecordingState* recordState = (RecordingState*)inUserData;

    [audioStreamerRef writeData:inBuffer->mAudioData size:inBuffer->mAudioDataByteSize];

    if(status == 0) {
        recordState->currentPacket += inNumberPacketDescriptions;
    }

    AudioQueueEnqueueBuffer(recordState->queue, inBuffer, 0, NULL);
}

@end

@implementation SpeechToTextResult

@synthesize transcript = _transcript;
@synthesize isCompleted = _isCompleted;
@synthesize isFinal = _isFinal;
@synthesize confidenceScore = _confidenceScore;

-(instancetype)init {
    if(self = [super init]) {
        self.isCompleted = NO;
        self.isFinal = NO;
        self.transcript = nil;
        self.confidenceScore = 0;
    }
    return self;
}


@end
