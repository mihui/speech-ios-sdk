/**
 * Copyright IBM Corporation 2016
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

#import "SpeechUtility.h"

@implementation SpeechUtility

/**
 *  Find proper error message with error code
 *  refer to http://tools.ietf.org/html/rfc6455
 *
 *  @param code error code
 *
 *  @return error message
 */
+ (NSString *)findUnexpectedErrorWithCode:(NSInteger)code {
    switch (code) {
        // http
        case 400:
            return @"Bad Request";
        case 401:
            return @"Unauthorized";
        case 403:
            return @"Forbidden";
        case 404:
            return @"Not Found";
        case 405:
            return @"Method Not Allowed";
        case 406:
            return @"Not Acceptable";
        case 407:
            return @"Proxy Authentication Required";
        case 408:
            return @"Request Timeout";
        case 409:
            return @"Conflict";
        case 419:
            return @"Gone";
        case 411:
            return @"Length Required";
        case 412:
            return @"Precondition Failed";
        case 413:
            return @"Request Entity Too Large";
        case 414:
            return @"Request-URI Too Long";
        case 415:
            return @"Unsupported Media Type";
        case 416:
            return @"Requested Range Not Satisfiable";
        case 417:
            return @"Expectation Failed";
        case 500:
            return @"Internal Server Error";
        case 501:
            return @"Not Implemented";
        case 502:
            return @"Bad Gateway";
        case 503:
            return @"Service Unavailable";
        case 504:
            return @"Gateway Timeout";
        case 505:
            return @"HTTP Version Not Supported";

        // websockets
        case 1001:
            return @"Stream end encountered";
        case 1002:
            return @"The endpoint is terminating the connection due to a protocol error";
        case 1003:
            return @"The endpoint is terminating the connection because it has received a type of data it cannot accept";
        case 1007:
            return @"The endpoint is terminating the connection because it has received data within a message that was not consistent with the type of the message";
        case 1008:
            return @"The endpoint is terminating the connection because it has received a message that violates its policy";
        case 1009:
            return @"The endpoint is terminating the connection because it has received a message that is too big for it to process.";
        case 1010:
            return @"The endpoint (client) is terminating the connection because it has expected the server to negotiate one or more extension, but the server didn't return them in the response message of the WebSocket handshake";
        case 1011:
            return @"The server is terminating the connection because it encountered an unexpected condition that prevented it from fulfilling the request";
        case 1015:
            return @"The connection was closed due to a failure to perform a TLS handshake";
        default:
            return @"";
    }
}

/**
 *  Produce customized error with code
 *
 *  @param code error code
 *
 *  @return customized error
 */
+ (NSError *)raiseErrorWithCode:(NSInteger)code{
    NSString* errorMessage = [SpeechUtility findUnexpectedErrorWithCode:code];

    return [SpeechUtility raiseErrorWithCode:code message:errorMessage reason:errorMessage suggestion:@""];
}

/**
 *  Produce customized error with code
 *
 *  @param code              error codde
 *  @param errorMessage      error message
 *  @param reasonMessage     reason
 *  @param suggestionMessage suggestion
 *
 *  @return customized error
 */
+ (NSError *)raiseErrorWithCode:(NSInteger)code message:(NSString *)errorMessage reason:(NSString *)reasonMessage suggestion:(NSString *)suggestionMessage{
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: errorMessage,
                               NSLocalizedFailureReasonErrorKey: reasonMessage,
                               NSLocalizedRecoverySuggestionErrorKey: suggestionMessage
                               };

    return [NSError errorWithDomain:WATSON_SDK_ERROR_DOMAIN code:code userInfo:userInfo];
}

/**
 *  Produce customized error with message
 *
 *  @param code         NSInteger
 *  @param errorMessage NSString
 *
 *  @return NSError*
 */
+ (NSError*)raiseErrorWithCode: (NSInteger)code message: (NSString*) errorMessage {
    return [SpeechUtility raiseErrorWithCode:code
                                     message:errorMessage
                                      reason:@""
                                  suggestion:@""];
}

/**
 *  Invoke proper callbacks by data in response
 *
 *  @param handler      callback
 *  @param authConfig   authentication configuration
 *  @param httpResponse response instance
 *  @param responseData response data
 *  @param requestError request error
 */
+ (void) processData: (DataHandlerWithError)handler
                  config: (BaseConfiguration*) authConfig
                response:(NSURLResponse*) httpResponse
                    data:(NSData*) responseData
                   error: (NSError*) requestError
{
    // request error
    if(requestError){
        handler(nil, requestError);
        return;
    }

    NSDictionary *responseObject = nil;
    NSError *dataError = nil;

    if ([httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *theResponse = (NSHTTPURLResponse*) httpResponse;
        NSLog(@"--> status code: %ld", (long)[theResponse statusCode]);
        
        if([theResponse statusCode] == 200 || [theResponse statusCode] == 304) {
            handler(responseData, nil);
        }
        else {
            responseObject = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&dataError];

            if(dataError) {
                NSLog(@"data error");
                handler(nil, dataError);
                return;
            }
            
            // response error handling
            // https://www.ibm.com/smarterplanet/us/en/ibmwatson/developercloud/text-to-speech/api/v1/#response-handling
            requestError = [SpeechUtility raiseErrorWithCode:[[responseObject valueForKey:@"code"] integerValue] message:[responseObject valueForKey:@"code_description"] reason:[responseObject valueForKey:@"error"] suggestion:@""];
            NSLog(@"server error");
            handler(nil, requestError);
        }
        return;
    }

    dataError = [SpeechUtility raiseErrorWithCode:0];
    handler(nil, dataError);
}

/**
 *  Invoke proper callbacks by parsing JSON data
 *
 *  @param handler      callback
 *  @param authConfig   authentication configuration
 *  @param httpResponse response instance
 *  @param responseData response data
 *  @param requestError request error
 */
+ (void) processJSON: (JSONHandlerWithError)handler
                  config: (BaseConfiguration*) authConfig
                response:(NSURLResponse*) httpResponse
                    data:(NSData*) responseData
                   error: (NSError*) requestError
{
    // request error
    if(requestError){
        handler(nil, requestError);
        return;
    }
    
    NSError *dataError = nil;
    NSDictionary *responseObject = nil;
    
    if ([httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *theResponse = (NSHTTPURLResponse*) httpResponse;
        NSLog(@"--> status code: %ld", (long)[theResponse statusCode]);

        if([theResponse statusCode] == 201 || [theResponse statusCode] == 204) {
            NSData *noContent = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
            responseObject = [NSJSONSerialization JSONObjectWithData:noContent options:NSJSONReadingMutableContainers error:&dataError];
            handler(responseObject, nil);
        }
        else{
            responseObject = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&dataError];
            if([theResponse statusCode] == 200) {
                handler(responseObject, nil);
            }
            else{
                if(dataError == nil){
                    NSLog(@"server error->%@", [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
                    // response error handling
                    // https://www.ibm.com/smarterplanet/us/en/ibmwatson/developercloud/text-to-speech/api/v1/#response-handling
                    NSString *reason = [responseObject valueForKey:@"error"];
                    NSString *description = [responseObject valueForKey:@"code_description"];
                    if(reason == nil || description == nil) {
                        NSLog(@"nil error");
                        // https://developer.ibm.com/answers/questions/284164/500-forwarding-error-and-inconsistant-error-json-s/
                        description = reason = [responseObject valueForKey:@"message"];
                    }
                    requestError = [SpeechUtility raiseErrorWithCode:[[responseObject valueForKey:@"code"] integerValue] message:description reason:reason suggestion:@""];
                    handler(nil, requestError);
                }
                else{
                    NSLog(@"data error");
                    handler(nil, dataError);
                }
            }
        }
        return;
    }
    
    dataError = [SpeechUtility raiseErrorWithCode:0];
    handler(nil, dataError);
}

/**
 *  performGet - shared method for performing GET requests to a given url calling a handler parameter with the result
 *
 *  @param handler JSONHandlerType
 *  @param url     url to perform GET request on
 */
+ (void) performGet:(JSONHandlerWithError)handler
             forURL:(NSURL*)url
             config: (BaseConfiguration*) authConfig
           delegate: (id<NSURLSessionDelegate>) sessionDelegate
             header:(NSDictionary *)extraHeader
{
    [SpeechUtility performGet:handler forURL:url config:authConfig delegate:sessionDelegate disableCache:NO header:extraHeader];
}

/**
 *  perform get with cache
 *
 *  @param handler         JSON handler
 *  @param url             request URL
 *  @param authConfig      configuration
 *  @param sessionDelegate URL session delegate
 */
+ (void) performGet:(JSONHandlerWithError)handler forURL:(NSURL*)url
             config: (BaseConfiguration*) authConfig
           delegate: (id<NSURLSessionDelegate>) sessionDelegate
{
    [SpeechUtility performGet:handler forURL:url config:authConfig delegate:sessionDelegate disableCache:NO];
}

/**
 *  perform get
 *
 *  @param handler         JSON handler
 *  @param url             request URL
 *  @param authConfig      configuration
 *  @param sessionDelegate URL session delegate
 *  @param withoutCache    disable cache
 */
+ (void) performGet:(JSONHandlerWithError)handler forURL:(NSURL*)url
             config: (BaseConfiguration*) authConfig
           delegate: (id<NSURLSessionDelegate>) sessionDelegate
       disableCache:(BOOL) withoutCache
{
    [SpeechUtility performGet:handler forURL:url config:authConfig delegate:sessionDelegate disableCache:withoutCache header:nil];
}

/**
 *  perform get with header
 *
 *  @param handler         JSON handler
 *  @param url             request URL
 *  @param authConfig      configuration
 *  @param sessionDelegate URL session delegate
 *  @param withoutCache    disable cache
 *  @param extraHeader     extra header
 */
+ (void) performGet:(JSONHandlerWithError)handler forURL:(NSURL*)url
             config: (BaseConfiguration*) authConfig
           delegate: (id<NSURLSessionDelegate>) sessionDelegate
       disableCache:(BOOL) withoutCache
             header:(NSDictionary *)extraHeader
{
    [authConfig requestToken:^(BaseConfiguration *config) {

        if([SpeechUtility isOS6]) {
            [SpeechUtility performGet:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                [SpeechUtility processJSON:handler config:config response:response data:data error:connectionError];
            } forURL:url disableCache:withoutCache configuration:config header:extraHeader];
        }
        else {
            // Create and set authentication headers
            NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];

            if(withoutCache)
                [defaultConfigObject setURLCache:nil];

            NSDictionary* headers = [config createRequestHeaders];

            [defaultConfigObject setHTTPAdditionalHeaders:headers];
            NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: sessionDelegate delegateQueue: [NSOperationQueue mainQueue]];

            NSURLSessionDataTask * dataTask = [defaultSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                [SpeechUtility processJSON:handler config:config response:response data:data error:error];
            }];

            [dataTask resume];
        }

    } refreshCache:NO];
}

/**
 *  iOS 6 compatibility
 *
 *  @param handler      data handler
 *  @param url          request URL
 *  @param withoutCache disable cache
 *  @param config       configuration
 */
+ (void)performGet:(void (^)(NSURLResponse* response, NSData* data, NSError* connectionError))handler
            forURL:(NSURL*)url
      disableCache:(BOOL) withoutCache
     configuration: (BaseConfiguration *) config
            header:(NSDictionary *)extraHeader
{
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    NSDictionary* httpHeaders = [config createRequestHeaders];

    for (NSString* key in httpHeaders) {
        [urlRequest addValue: [httpHeaders objectForKey:key] forHTTPHeaderField:key];
    }

    if(extraHeader) {
        for (NSString* key in extraHeader) {
            [urlRequest addValue:[extraHeader valueForKey:key] forHTTPHeaderField:key];
        }
    }

    [NSURLConnection sendAsynchronousRequest:urlRequest queue:[NSOperationQueue mainQueue] completionHandler:handler];
}

/**
 *  This is only for iOS 6 because the lowest target is iOS 6
 *
 *  @return BOOL
 */
+ (BOOL)isOS6 {
    return [[[UIDevice currentDevice] systemVersion] intValue] < 7;
}

+ (NSMutableData *)addWavHeader:(NSData *)wavNoheader rate:(long) sampleRate {
    
    int headerSize = 44;
    long totalAudioLen = [wavNoheader length];
    long totalDataLen = [wavNoheader length] + headerSize-8;
    long longSampleRate = (sampleRate == 0 ? 48000 : sampleRate);
    int channels = 1;
    long byteRate = 16 * 11025 * channels/8;
    
    Byte *header = (Byte*)malloc(44);
    header[0] = 'R';  // RIFF/WAVE header
    header[1] = 'I';
    header[2] = 'F';
    header[3] = 'F';
    header[4] = (Byte) (totalDataLen & 0xff);
    header[5] = (Byte) ((totalDataLen >> 8) & 0xff);
    header[6] = (Byte) ((totalDataLen >> 16) & 0xff);
    header[7] = (Byte) ((totalDataLen >> 24) & 0xff);
    header[8] = 'W';
    header[9] = 'A';
    header[10] = 'V';
    header[11] = 'E';
    header[12] = 'f';  // 'fmt ' chunk
    header[13] = 'm';
    header[14] = 't';
    header[15] = ' ';
    header[16] = 16;  // 4 bytes: size of 'fmt ' chunk
    header[17] = 0;
    header[18] = 0;
    header[19] = 0;
    header[20] = 1;  // format = 1
    header[21] = 0;
    header[22] = (Byte) channels;
    header[23] = 0;
    header[24] = (Byte) (longSampleRate & 0xff);
    header[25] = (Byte) ((longSampleRate >> 8) & 0xff);
    header[26] = (Byte) ((longSampleRate >> 16) & 0xff);
    header[27] = (Byte) ((longSampleRate >> 24) & 0xff);
    header[28] = (Byte) (byteRate & 0xff);
    header[29] = (Byte) ((byteRate >> 8) & 0xff);
    header[30] = (Byte) ((byteRate >> 16) & 0xff);
    header[31] = (Byte) ((byteRate >> 24) & 0xff);
    header[32] = (Byte) (2 * 8 / 8);  // block align
    header[33] = 0;
    header[34] = 16;  // bits per sample
    header[35] = 0;
    header[36] = 'd';
    header[37] = 'a';
    header[38] = 't';
    header[39] = 'a';
    header[40] = (Byte) (totalAudioLen & 0xff);
    header[41] = (Byte) ((totalAudioLen >> 8) & 0xff);
    header[42] = (Byte) ((totalAudioLen >> 16) & 0xff);
    header[43] = (Byte) ((totalAudioLen >> 24) & 0xff);
    
    NSMutableData *newWavData = [NSMutableData dataWithBytes:header length:44];
    [newWavData appendBytes:[wavNoheader bytes] length:[wavNoheader length]];
    return newWavData;
}

+ (void)setProximityMonitor:(BOOL)enable {
    [[UIDevice currentDevice] setProximityMonitoringEnabled:enable];
    if(enable) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(sensorStateChange:)
                                                     name:@"UIDeviceProximityStateDidChangeNotification"
                                                   object:nil];
    }
    else {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:@"UIDeviceProximityStateDidChangeNotification"
                                                      object:nil];
    }
}

+ (void)sensorStateChange:(NSNotificationCenter *)notification {
    if ([[UIDevice currentDevice] proximityState] == YES) {
        NSLog(@"Device is close to user");
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    }
    else {
        NSLog(@"Device is not close to user");
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    }
}


@end
