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

#import "TTSCustomVoice.h"

@implementation TTSCustomVoice

@synthesize name = _name;
@synthesize language = _language;
@synthesize description = _description;
@synthesize words = _words;

- (id) init {
    self = [super init];
    _name = @"";
    _language = @"";
    _description = @"";
    _words = [[NSArray alloc] init];
    return self;
}

-(NSData*)producePostData {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:3];
    if(![[self name] isEqualToString:@""])
        [dict setObject:[self name] forKey:@"name"];
    if(![[self description] isEqualToString:@""])
        [dict setObject:[self description] forKey:@"description"];
    if(![[self language] isEqualToString:@""])
        [dict setObject:[self language] forKey:@"language"];

    if([[self words] count] > 0)
        [dict setObject:[self words] forKey:@"words"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    NSLog(@"Produced data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    return data;
}
@end
