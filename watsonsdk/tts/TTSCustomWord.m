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

#import "TTSCustomWord.h"

@implementation TTSCustomWord

@synthesize word = _word;
@synthesize translation = _translation;

- (id) init {
    self = [super init];
    if(self){
        _translation = @"";
        _word = @"";
    }
    return self;
}
- (id) initWithWord: (NSString*) text translation:(NSString*) translation{
    self = [super init];
    if(self){
        _word = text;
        _translation = translation;
    }
    return self;
}

+ (id) initWithWord: (NSString*) text translation:(NSString*) translation{
    TTSCustomWord *customWord = [[TTSCustomWord alloc] initWithWord:text translation: translation];
    return customWord;
}

-(NSMutableDictionary*)produceDictionary {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:2];
    if(![[self word] isEqualToString:@""])
        [dict setObject:[self word] forKey:@"word"];
    if(![[self translation] isEqualToString:@""])
        [dict setObject:[self translation] forKey:@"translation"];

    NSLog(@"Produced dictionary: %@", dict);
    return dict;
}

-(NSData*)producePostData {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:2];
    [dict setObject:[self translation] forKey:@"translation"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    NSLog(@"Produced data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    return data;
}

@end
