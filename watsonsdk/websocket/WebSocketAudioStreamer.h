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
#import <objc/runtime.h>

#import "STTConfiguration.h"
#import "SocketRocket.h"
#import "SpeechUtility.h"

@interface WebSocketAudioStreamer : NSObject

- (BOOL)isWebSocketConnected;
- (void)connect:(STTConfiguration*)config headers:(NSDictionary*)headers completionCallback:(ClosureHandler)closureCallback;
- (void)reconnect;
- (void)disconnect:(NSString*) reason;

- (void)writeHeader;
- (void)writeData:(char*) data size: (int) size;
- (void)setRecognizeHandler:(JSONHandlerWithError)handler;
- (void)setAudioDataHandler:(DataHandler)handler;
- (void)writeEndMarker;

@end

@interface NSData (SpeechToText)

@property NSNumber *marker;

@end

@implementation NSData (SpeechToText)

static char key;

- (void)setMarker:(NSNumber*)marker {
    objc_setAssociatedObject(self, &key, marker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber*)marker {
    return objc_getAssociatedObject(self, &key);
}

@end

@interface NSMutableData (SpeechToText)

@property NSNumber *marker;

@end

@implementation NSMutableData (SpeechToText)

static char key;

- (void)setMark:(NSNumber*)marker {
    objc_setAssociatedObject(self, &key, marker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber*)marker {
    return objc_getAssociatedObject(self, &key);
}

@end
