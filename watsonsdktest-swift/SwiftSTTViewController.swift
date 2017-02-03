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

import UIKit

typealias TokenHandler = ((((String?) -> Void)?)) -> Void

class SwiftSTTViewController: UIViewController, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate, URLSessionTaskDelegate {

    var sttLanguageModels: NSArray?
    var sttInstance: SpeechToText?

    @IBOutlet var modelSelectorButton: UIButton!
    @IBOutlet weak var pickerViewContainer: UIView!
    @IBOutlet var soundbar: UIView!
    @IBOutlet var result: UILabel!
    var pickerView: UIPickerView!
    let pickerViewHeight:CGFloat = 250.0
    let pickerViewAnimationDuration: TimeInterval = 0.5
    let pickerViewAnimationDelay: TimeInterval = 0.1
    let pickerViewPositionOffset: CGFloat = 33.0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let credentialFilePath = Bundle.main.path(forResource: "Credentials", ofType: "plist")
        let credentials = NSDictionary(contentsOfFile: credentialFilePath!)

        let confSTT: STTConfiguration = STTConfiguration()
        confSTT.basicAuthUsername = credentials!["STTUsername"] as! String
        confSTT.basicAuthPassword = credentials!["STTPassword"] as! String
        confSTT.audioCodec = WATSONSDK_AUDIO_CODEC_TYPE_OPUS
        confSTT.modelName = WATSONSDK_DEFAULT_STT_MODEL

//        confSTT.tokenGenerator = self.tokenGenerator()

        self.sttInstance = SpeechToText(config: confSTT)

        self.sttInstance?.listModels({ (jsonDict: [AnyHashable: Any]?, error: Error?) in
            if error == nil {
                self.modelHandler(jsonDict!)
            }
            else{
                self.result.text = error?.localizedDescription
            }
        })
    }

    // start recording
    @IBAction func onStartRecording(_ sender: AnyObject) {
        self.sttInstance?.recognize({ (result:[AnyHashable: Any]?, error: Error?) in
            if(error == nil) {
                let sttResult = self.sttInstance?.getResult(result)

                guard let transcript = sttResult?.transcript else {
                    return;
                }
                self.result.text = transcript
                
            }
            else{
                print("Error from the SDK: %@", error?.localizedDescription ?? "")
                self.sttInstance?.stopRecordingAudio()
                self.sttInstance?.endConnection()
            }
        }) { (power: Float) -> Void in
                var frame = self.soundbar.frame
                var w = CGFloat.init(3*(70 + power))
                
                if w > self.pickerViewContainer.frame.width {
                    w = self.pickerViewContainer.frame.width
                }

                frame.size.width = w
                self.soundbar.frame = frame
                self.soundbar.center = CGPoint(x: self.view.frame.size.width / 2, y: self.soundbar.center.y);
        }
    }
    
    @IBAction func onSelectingModel(_ sender: AnyObject) {
        self.hidePickerView(false, withAnimation: true)
    }
    
    func onHidingPickerView(){
        self.hidePickerView(true, withAnimation: true)
    }

    func onSelectedModel(_ row: Int){
        guard let models = self.sttLanguageModels else{
            return
        }
        let model = models.object(at: row) as! NSDictionary
        let modelName:String = model.object(forKey: "name") as! String
        let modelDesc:String = model.object(forKey: "description") as! String
        self.modelSelectorButton.setTitle(modelDesc, for: UIControlState())
        self.sttInstance?.config.modelName = modelName
    }
    
    func modelHandler(_ dict: [AnyHashable: Any]){
        self.sttLanguageModels = dict["models"] as? NSArray
        self.getUIPickerViewInstance().backgroundColor = UIColor.white
        self.hidePickerView(true, withAnimation: false)

        self.view.addSubview(self.getUIPickerViewInstance())
        var row = 0
        if let list = self.sttLanguageModels{
            for i in 0 ..< list.count{
                if (list.object(at: i) as AnyObject).object(forKey: "name") as? String == self.sttInstance?.config.modelName{
                    row = i
                }
            }
        }
        else{
            row = (self.sttLanguageModels?.count)! - 1
        }
        self.getUIPickerViewInstance().selectRow(row, inComponent: 0, animated: false)
        self.onSelectedModel(row)
    }

    // Example of token generator
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

    func getUIPickerViewInstance() -> UIPickerView{
        guard let _ = self.pickerView else{
            let pickerViewframe = CGRect(x: 0, y: UIScreen.main.bounds.height - self.pickerViewHeight + self.pickerViewPositionOffset, width: UIScreen.main.bounds.width, height: self.pickerViewHeight)
            self.pickerView = UIPickerView(frame: pickerViewframe)
            self.pickerView.dataSource = self
            self.pickerView.delegate = self
            self.pickerView.isOpaque = true
            self.pickerView.showsSelectionIndicator = true
            self.pickerView.isUserInteractionEnabled = true
            return self.pickerView
        }
        return self.pickerView
    }

    func hidePickerView(_ hide: Bool, withAnimation: Bool){
        if withAnimation{
            UIView.animate(withDuration: self.pickerViewAnimationDuration, delay: self.pickerViewAnimationDelay, options: UIViewAnimationOptions(), animations: { () -> Void in
                var frame = self.getUIPickerViewInstance().frame
                if hide{
                    frame.origin.y = UIScreen.main.bounds.height
                }
                else{
                    self.getUIPickerViewInstance().isHidden = hide
                    frame.origin.y = UIScreen.main.bounds.height - self.pickerViewHeight + self.pickerViewPositionOffset
                }
                self.getUIPickerViewInstance().frame =  frame
                }) { (Bool) -> Void in
                    self.getUIPickerViewInstance().isHidden = hide
            }
        }
        else{
            self.getUIPickerViewInstance().isHidden = hide
        }
    }
    
    // UIPickerView delegate methods
    func numberOfComponents(in pickerView: UIPickerView) -> Int{
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int{
        guard let models = self.sttLanguageModels else {
            return 0
        }
        return models.count
    }
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 50
    }
    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        return self.pickerViewHeight
    }
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        var tView: UILabel? = view as? UILabel
        if tView == nil {
            tView = UILabel()
            tView?.font = UIFont(name: "Helvetica", size: 12)
            tView?.numberOfLines = 1
        }
        let model = self.sttLanguageModels?.object(at: row) as? NSDictionary
        tView?.text = model?.object(forKey: "description") as? String
        return tView!
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.onSelectedModel(row)
        self.hidePickerView(true, withAnimation: true)
    }
    // UIPickerView delegate methods
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

