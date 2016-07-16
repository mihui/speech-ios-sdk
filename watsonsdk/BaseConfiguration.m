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

#import "BaseConfiguration.h"

@implementation BaseConfiguration

@synthesize basicAuthUsername = _basicAuthUsername;
@synthesize basicAuthPassword = _basicAuthPassword;
@synthesize token = _token;

- (id) init {
    self = [super init];
    _token = nil;
    _xWatsonLearningOptOut = NO;
    return self;
}

- (void)invalidateToken {
    _token = nil;
}

- (void)requestToken:(void (^)(BaseConfiguration *))completionHandler refreshCache:(BOOL) refreshCachedToken {
    if (self.tokenGenerator) {
        if (!_token || refreshCachedToken) {
            self.tokenGenerator(^(NSString *token) {
                _token = token;
                completionHandler(self);
            });
        } else {
            completionHandler(self);
        }
    } else {
        completionHandler(self);
    }
}

- (NSMutableDictionary*) createRequestHeaders {
    NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
    if (self.tokenGenerator) {
        if (self.token) {
            [headers setObject:self.token forKey:@"X-Watson-Authorization-Token"];
        }
    } else if(self.basicAuthPassword && self.basicAuthUsername) {
        NSString *authStr = [NSString stringWithFormat:@"%@:%@", self.basicAuthUsername,self.basicAuthPassword];
        NSData *authData = [authStr dataUsingEncoding:NSUTF8StringEncoding];
        NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64Encoding]];
        [headers setObject:authValue forKey:@"Authorization"];
    }
    
    return headers;
}


/**
 *  setApiUrl - override setter so we can update the NSURL endpoint
 *
 *  @param apiURL NSString*
 */
- (void)setApiURL:(NSString*)apiURLStr {
    _apiURL = apiURLStr;
    [self setApiEndpoint:[NSURL URLWithString:apiURLStr]];
}

/**
 *  common method for building URL
 *
 *  @param servicePath   NSString*
 *  @param parameters    NSDictionary*
 *
 *  @return NSURL*
 */
- (NSURL*)getRequestURL:(NSString*) servicePath params:(NSDictionary*)parameters {
    return [self getRequestURL:servicePath params:parameters isWebSocket:NO];
}

/**
 *  common method for building URL
 *
 *  @param servicePath      NSString*
 *  @param parameters       NSDictionary*
 *  @param isUsingWebSocket BOOL
 *
 *  @return NSURL*
 */
- (NSURL*)getRequestURL:(NSString*) servicePath params:(NSDictionary*)parameters isWebSocket:(BOOL) isUsingWebSocket {
    NSString *serviceParameters = [self buildQueryString: parameters];
    NSString *urlString = [NSString stringWithFormat:@"%@://%@%@%@%@", isUsingWebSocket ? WEBSOCKETS_SCHEME : self.apiEndpoint.scheme, self.apiEndpoint.host, self.apiEndpoint.path, servicePath, serviceParameters];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSLog(@"URL: %@", url);
    return url;
}

/**
 *  Build query string
 *
 *  @param parameters NSDictionary*
 *
 *  @return NSString*
 */
- (NSString*)buildQueryString:(NSDictionary*)parameters {
    if(parameters == nil || [parameters count] == 0) {
        NSLog(@"query string is empty");
        return @"";
    }
    int paramCount = 0;
    NSMutableString *paramString = [NSMutableString stringWithString:@""];
    for (NSString *key in parameters) {
        [paramString appendFormat:@"%@%@=%@", paramCount++ == 0 ? @"?" : @"&", key, [[parameters objectForKey:key] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }
    NSLog(@"query string--->%@", paramString);
    return paramString;
}

@end
