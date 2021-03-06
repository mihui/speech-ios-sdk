## Watson Speech iOS (Objective-C) SDK

An SDK for iOS mobile applications enabling use of the Bluemix Watson Speech To Text and Text To Speech APIs from [Watson Developer Cloud][wdc]

The SDK include support for recording and streaming audio and receiving a transcript of the audio in response.


Table of Contents
-----------------
* [Watson Developer Cloud Speech APIs][wdc]

    * [Installation](#installation)
    * [Include headers](#include-headers)
    * [Sample Applications](#sample-applications)
    * [Speech To Text](#speech-to-text)
    	* [Create a Configuration](#create-a-stt-configuration) 
    	* [Authentication options](#authentication)
    	* [Create a SpeechToText instance](#create-a-speechtotext-instance) 
    	* [List supported models](#get-a-list-of-models-supported-by-the-service) 
    	* [Get model details](#get-details-of-a-particular-model)	
    	* [Use a named model](#use-a-named-model)
    	* [Enabling audio compression](#enabling-audio-compression)
    	* [Start Audio Transcription](#start-audio-transcription)
    	* [End Audio Transcription](#end-audio-transcription)
    	* [Confidence Score](#obtain-a-confidence-score)
    	* [Speech power levels](#receive-speech-power-levels-during-the-recognize)
    	
    * [Text To Speech](#text-to-speech)
    	* [Create a Configuration](#create-a-configuration)
    	* [Set the voice](#set-the-voice)
    	* [Use Token Authentication](#use-token-authentication)
    	* [Create a TextToSpeech instance](#create-a-texttospeech-instance)
    	* [List supported voices](#get-a-list-of-voices-supported-by-the-service)
    	* [Generate and play audio](#generate-and-play-audio)
        * [Generate and play customized audio](#generate-and-play-customized-audio)

Installation
------------

**Using the framework**

1. Download the [watsonsdk.framework.zip](https://github.com/mihui/speech-ios-sdk/raw/master/watsonsdk.framework.zip) and unzip it somewhere convenient
2. Once unzipped drag the watsonsdk.framework folder into your xcode project view under the Frameworks folder.

Some additional iOS standard frameworks must be added.

1. Select your project in the Xcode file explorer and open the "Build Phases" tab. Expand the "Link Binary With Libraries" section and click the + icon

2. Add the following frameworks
	- AudioToolbox.framework
	- AVFoundation.framework
	- CFNetwork.framework
	- CoreAudio.framework
	- Foundation.framework
	- libicucore.tbd (or libicucore.dylib on older versions)
	- Quartzcore.framework
	- Security.framework


Include headers
---------------

**in Objective-C**

```objective-c
	#import <watsonsdk/SpeechToText.h>
	#import <watsonsdk/TextToSpeech.h>
```

**in Swift**

*Add the headers above for Objective-c into a bridging header file.*
	- Use SwiftSpeechHeader.h in Swift sample

#Sample Applications
====================

This repository contains a sample application demonstrating the SDK functionality. 

To run the application clone this repository and then navigate in Finder to folder containing the SDK files.

Double click on the watsonsdk.xcodeproj  to launch Xcode.

To run the sample application, change the compile target to 'watsonsdktest-objective-c' or 'watsonsdktest-swift' and run on the iPhone simulator.

Note that this is sample code and no security review has been performed on the code.

The Swift sample was tested in `Xcode 8.2.1`.

#Speech To Text 
===============

Create a STT Configuration
--------------------------

By default the Configuration will use the IBM Bluemix service API endpoint, custom endpoints can be set using `setApiURL` in most cases this is not required.

**in Objective-C**
```objective-c
	STTConfiguration *conf = [[STTConfiguration alloc] init];
```
**in Swift**
```swift
	let conf:STTConfiguration = STTConfiguration()
```

Authentication
--------------
There are currently two authentication options.

Basic Authentication, using the credentials provided by the Bluemix Service instance.

**in Objective-C**
```objective-c
	[conf setBasicAuthUsername:@"<userid>"];
	[conf setBasicAuthPassword:@"<password>"];
```

**in Swift**
```swift
	conf.basicAuthUsername = "<userid>"
	conf.basicAuthPassword = "<password>"
```

Token authentication, if a token authentication provider is running at https://my-token-factory/token 

**in Objective-C**
```objective-c
    [conf setTokenGenerator:^(void (^tokenHandler)(NSString *token)){
        NSURL *url = [[NSURL alloc] initWithString:@"https://<token-factory-url>"];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setHTTPMethod:@"GET"];
        [request setURL:url];
        
        NSError *error = [[NSError alloc] init];
        NSHTTPURLResponse *responseCode = nil;
        NSData *oResponseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseCode error:&error];
        if ([responseCode statusCode] != 200) {
            NSLog(@"Error getting %@, HTTP status code %li", url, (long)[responseCode statusCode]);
            return;
        }
        tokenHandler([[NSString alloc] initWithData:oResponseData encoding:NSUTF8StringEncoding]);
    } ];
```

**in Swift**
```swift
    ...
    confSTT.tokenGenerator = self.tokenGenerator()
    ...

    func tokenGenerator() -> ((((String?) -> Void)?)) -> Void {
        let url = URL(string: "https://<token-factory-url>")
        return ({ ( _ tokenHandler: (((_ token:String?) -> Void)?) ) -> () in
            SpeechUtility .performGet({ (data:Data?, response:URLResponse?, error:Error?) in
                if error != nil {
                    print("Error occurred while requesting token: \(error?.localizedDescription ?? "")")
                    return
                }
                guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse else {
                    print("Invalid response")
                    return
                }
                if httpResponse.statusCode != 200 {
                    print("Error response: \(httpResponse.statusCode)")
                    return
                }
                
                let token:String = String(data: data!, encoding: String.Encoding.utf8)!
                
                tokenHandler!(token)
            }, for: url, delegate: self, disableCache: true, header: nil)
        })
    }
```



Create a SpeechToText instance
------------------------------


**in Objective-C**
```objective-c
	@property SpeechToText;
	
	...
	
	self.stt = [SpeechToText initWithConfig:conf];
```

**in Swift**
```swift
	var stt:SpeechToText?
	
	...
	
	self.stt = SpeechToText(config: conf)
```

Get a list of models supported by the service
---------------------------------------------

**in Objective-C**
```objective-c
	[stt listModels:^(NSDictionary* jsonDict, NSError* err){
        
        if(err == nil)
            ... read values from NSDictionary ...

	}];
```

**in Swift**
```swift
stt?.listModels({ (jsonDict: [AnyHashable: Any]?, error: Error?) in
    
    if err == nil {
    	print(jsonDict!)
    }
})
```

Get details of a particular model
---------------------------------

Available speech recognition models can be obtained using the listModel function.

**in Objective-C**
```objective-c
	[stt listModel:^(NSDictionary* jsonDict, NSError* err){
        
        if(err == nil)
            ... read values from NSDictionary ...
	    
    	} withName:@"WatsonSpeechModel"];
```

**in Swift**
```swift
	stt?.listModel({ (jsonDict: [AnyHashable : Any]?, error: Error?) in
        	if err == nil {
	            print(jsonDict!)
        	}
	}, withName: "WatsonSpeechModel")
```


Use a named model
-----------------
The speech recognition model can be changed in the configuration. 

**in Objective-C**
```objective-c
	[conf setModelName:@"ja-JP_BroadbandModel"];
```

**in Swift**
```swift
	confSTT.modelName = "ja-JP_BroadbandModel"
```

Enabling audio compression
--------------------------
By default audio sent to the server is uncompressed PCM encoded data, compressed audio using the Opus codec can be enabled.

**in Objective-C**
```objective-c
	[conf setAudioCodec:WATSONSDK_AUDIO_CODEC_TYPE_OPUS];
```

**in Swift**
```swift
	confSTT.audioCodec = WATSONSDK_AUDIO_CODEC_TYPE_OPUS
```

Start audio transcription
-------------------------

**in Objective-C**
```objective-c
	[stt recognize:^(NSDictionary* res, NSError* err){
        
        if(err == nil) {
            SpeechToTextResult *sttResult = [stt getResult:res];
            
	    if([sttResult transcript]) {
                if([sttResult isFinal]) {
                    // final transcript
		    NSLog(@"%@", [sttResult transcript]);
                }
                else {
                    // partial transcript
		    NSLog(@"%@", [sttResult transcript]);
                }
            }
        }
        else {
            [stt stopRecordingAudio];
            [stt endConnection];
        }
    }];

```

**in Swift**
```swift
	self.sttInstance?.recognize({ (result: [AnyHashable : Any]?, error: Error?) in
            if error == nil {
                let sttResult = self.sttInstance?.getResult(result)
                guard let transcript = sttResult?.transcript else {
                    return;
                }
                if (sttResult?.isFinal)! {
                    // final transcript
                    print(sttResult?.transcript ?? "")
                }
                else {
                    // partial transcript
                    print(sttResult?.transcript ?? "")
                }
                self.result.text = transcript
            }
            else {
                self.sttInstance?.stopRecordingAudio()
                self.sttInstance?.endConnection()
            }
        })
```

End audio transcription
-----------------------

The app must explicity indicate to the SDK when transmission should be ended if the continous option is YES.

**in Objective-C**
```objective-c
	[conf setContinuous:YES];

	...
    
	[stt endTransmission];
```

**in Swift**
```swift
	conf.continuous = true

	...

	stt?.endTransmission()
```

Obtain a confidence score
-------------------------
A confidence score is available for any final transcripts (whole sentences).
This can be obtained from SpeechToTextResult instance.

**in Objective-C**
```objective-c

    SpeechToTextResult *sttResult = [stt getResult:res];

    NSLog(@"Confidence score: %@", [sttResult confidenceScore])
```

**in Swift**
```swift
	let sttResult = self.sttInstance?.getResult(result)
	print("Confidence score: \(sttResult?.confidenceScore)")
```

Receive speech power levels during the recognize
------------------------------------------------

**in Objective-C**
```objective-c
	[stt recognize:^(NSDictionary *, NSError *) {
		...
	} powerHandler:^(float power) {
		NSLog(@"Power level: %f", power);
	}];
```

**in Swift**
```swift
	self.sttInstance?.recognize({ (result: [AnyHashable : Any]?, error: Error?) in
		...
	}, powerHandler: { (power: Float) in
		print("Power level: \(power)")
	})
```

Text To Speech 
==============


Create a Configuration
----------------------

By default the Configuration will use the IBM Bluemix service API endpoint, custom endpoints can be set using `setApiURL` in most cases this is not required.

**in Objective-C**
```objective-c
	TTSConfiguration *conf = [[TTSConfiguration alloc] init];
	[conf setBasicAuthUsername:@"<userid>"];
	[conf setBasicAuthPassword:@"<password>"];
```

**in Swift**
```swift
	let conf: TTSConfiguration = TTSConfiguration()
	conf.basicAuthUsername = "<userid>"
	conf.basicAuthPassword = "<password>"
```

Set the voice
-------------
You can change the voice model used for TTS by setting it in the configuration.

**in Objective-C**
```objective-c
	[conf setVoiceName:@"en-US_MichaelVoice"];
```

**in Swift**
```swift
	conf.voiceName = "en-US_MichaelVoice"
```


Use Token Authentication
------------------------

If you use tokens (from your own server) to get access to the service, provide a token generator to the Configuration. `userid` and `password` will not be used if a token generator is provided.

**in Objective-C**
```objective-c
   [conf setTokenGenerator:^(void (^tokenHandler)(NSString *token)){
        // get a token from your server in secure way
        NSString *token = ...

        // provide the token to the tokenHandler
        tokenHandler(token);
    }];
```

Create a TextToSpeech instance 
------------------------------

**in Objective-C**
```objective-c
	self.tts = [TextToSpeech initWithConfig:conf];
```

**in Swift**
```swift
    var tts: TextToSpeech?
    
    
    ...
    self.tts = TextToSpeech(config: conf)

```

Get a list of voices supported by the service
------------------------------

**in Objective-C**
```objective-c
	[tts listVoices:^(NSDictionary* jsonDict, NSError* err){
        
        if(err == nil)
            ... read values from NSDictionary ...

    }];
```

**in Swift**
```swift
	tts?.listVoices({ (jsonDict:[AnyHashable: Any]?, error:Error?) in
            if error == nil {
                print(jsonDict!)
            }
        })
```

Generate and play audio
-----------------------

**in Objective-C**
```objective-c
	[self.tts synthesize:^(NSData *data, NSError *reqErr) {
    	
    	// request error
    	if(reqErr){
            NSLog(@"Error requesting data: %@", [reqErr description]);
            return;
        }

        // play audio and log when playing has finished
        [self.tts playAudio:^(NSError *err) {
            if(err)
                NSLog(@"error playing audio %@", [err localizedDescription]);
            else
            	NSLog(@"audio finished playing");
            
        } withData:data];
        
    } theText:@"Hello World"];
```


**in Swift**
```swift

	tts?.synthesize({ (data: NSData!, reqError: NSError!) -> Void in
        if reqError == nil{
		tts?.playAudio({ (error: NSError!) -> Void in
			if error == nil{
				... do something after the audio has played ...
			}
			else{
				... data error handling ...
			}
		}, withData: data)
        }
        else
        	... request error handling ...

	}, theText: "Hello World")

```

Generate and play customized audio
----------------------------------

**in Objective-C**
```objective-c
    [self.tts synthesize:^(NSData *data, NSError *reqErr) {
        
        // request error
        if(reqErr){
            NSLog(@"Error requesting data: %@", [reqErr description]);
            return;
        }

        // play audio and log when playing has finished
        [self.tts playAudio:^(NSError *err) {
            if(err)
                NSLog(@"error playing audio %@", [err localizedDescription]);
            else
                NSLog(@"audio finished playing");
            
        } withData:data];
        
    } theText:@"Hello World" customizationId:@"your-customization-id"];
```


**in Swift**
```swift

    tts?.synthesize({ (data: NSData!, reqError: NSError!) -> Void in
        if reqError == nil{
            tts?.playAudio({ (error: NSError!) -> Void in
                if error == nil{
                    ... do something after the audio has played ...
                }
                else{
                    ... data error handling ...
                }
            }, withData: data)
        }
        else
            ... request error handling ...

    }, theText: "Hello World", customizationId: "your-customization-id")

```

[wdc]: http://www.ibm.com/smarterplanet/us/en/ibmwatson/developercloud/apis/#!/speech-to-text


## Open Source @ IBM
[Find more open source projects on the IBM Github Page.](http://ibm.github.io/)

## Copyright and license

Copyright 2017 IBM Corporation under [the Apache 2.0 license](LICENSE).
