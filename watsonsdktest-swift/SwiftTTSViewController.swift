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

class SwiftTTSViewController: UIViewController, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate, UIGestureRecognizerDelegate {

    var ttsVoices: NSArray?
    var ttsInstance: TextToSpeech?

    @IBOutlet var voiceSelectorButton: UIButton!
    @IBOutlet weak var pickerViewContainer: UIView!
    @IBOutlet var ttsField: UITextView!

    var pickerView: UIPickerView!
    let pickerViewHeight:CGFloat = 250.0
    let pickerViewAnimationDuration: TimeInterval = 0.5
    let pickerViewAnimationDelay: TimeInterval = 0.1
    let pickerViewPositionOffset: CGFloat = 33.0

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let credentialFilePath = Bundle.main.path(forResource: "Credentials", ofType: "plist")
        let credentials = NSDictionary(contentsOfFile: credentialFilePath!)
        
        let confTTS: TTSConfiguration = TTSConfiguration()
        confTTS.basicAuthUsername = credentials?["TTSUsername"] as! String
        confTTS.basicAuthPassword = credentials?["TTSPassword"] as! String
        confTTS.audioCodec = WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS
        confTTS.voiceName = WATSONSDK_DEFAULT_TTS_VOICE

        self.ttsInstance = TextToSpeech(config: confTTS)
        self.ttsInstance?.listVoices({ (jsonDict:[AnyHashable: Any]?, error:Error?) in
            if error == nil {
                self.voiceHandler(jsonDict!)
            }
            else{
                self.ttsField.text = error?.localizedDescription
            }
        })
    }
    // dismiss keyboard when the background is touched
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.ttsField.endEditing(true)
    }
    // start recording
    @IBAction func onStartSynthesizing(_ sender: AnyObject) {
        self.ttsInstance?.synthesize({ (data: Data?, reqError: Error?) in
            if reqError == nil {
                self.ttsInstance?.playAudio({ (error: Error?) in
                    if error == nil{
                        print("Audio finished playing")
                    }
                    else{
                        print("Error playing audio %@", error?.localizedDescription ?? "")
                    }

                    }, with: data)
            }
            else {
                print("Error requesting data: %@", reqError?.localizedDescription ?? "")
            }
        }, theText: self.ttsField.text)
    }
    // show picker view when the button is clicked
    @IBAction func onSelectingModel(_ sender: AnyObject) {
        self.hidePickerView(false, withAnimation: true)
    }
    
    // hide picker view
    func onHidingPickerView(){
        self.hidePickerView(true, withAnimation: true)
    }
    
    // set voice name when the picker view data is changed
    func onSelectedModel(_ row: Int){
        guard let voices = self.ttsVoices else{
            return
        }
        let voice = voices.object(at: row) as! NSDictionary
        let voiceName:String = voice.object(forKey: "name") as! String
        let voiceGender:String = voice.object(forKey: "gender") as! String
        self.voiceSelectorButton.setTitle(String(format: "%@: %@", voiceGender, voiceName), for: UIControlState())
        self.ttsInstance?.config.voiceName = voiceName
    }

    // setup picker view after the response is back
    func voiceHandler(_ dict: [AnyHashable: Any]){
        self.ttsVoices = dict["voices"] as? NSArray
        self.getUIPickerViewInstance().backgroundColor = UIColor.white
        self.hidePickerView(true, withAnimation: false)
        
        let gestureRecognizer:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(SwiftTTSViewController.pickerViewTapGestureRecognized(_:)))
        gestureRecognizer.delegate = self
        self.getUIPickerViewInstance().addGestureRecognizer(gestureRecognizer);

        self.view.addSubview(self.getUIPickerViewInstance())
        var row = 0
        if let list = self.ttsVoices{
            for i in 0 ..< list.count{
                if (list.object(at: i) as AnyObject).object(forKey: "name") as? String == self.ttsInstance?.config.voiceName{
                    row = i
                }
            }
        }
        else{
            row = (self.ttsVoices?.count)! - 1
        }
        self.getUIPickerViewInstance().selectRow(row, inComponent: 0, animated: false)
        self.onSelectedModel(row)
    }

    // get picker view initialized
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
    
    // display/show picker view with animations
    func hidePickerView(_ hide: Bool, withAnimation: Bool){
        if withAnimation{
            UIView.animate(withDuration: self.pickerViewAnimationDuration, delay: self.pickerViewAnimationDelay, options: UIViewAnimationOptions(), animations: { () -> Void in
                var frame = self.getUIPickerViewInstance().frame
                if hide{
                    frame.origin.y = (UIScreen.main.bounds.height)
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

    func pickerViewTapGestureRecognized(_ sender: UIGestureRecognizer){
        self.onSelectedModel(self.getUIPickerViewInstance().selectedRow(inComponent: 0))
    }

    // UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    // UIGestureRecognizerDelegate

    // UIPickerView delegate methods
    func numberOfComponents(in pickerView: UIPickerView) -> Int{
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int{
        guard let voices = self.ttsVoices else {
            return 0
        }
        return voices.count
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
        let model = self.ttsVoices?.object(at: row) as? NSDictionary
        tView?.text = String(format: "%@: %@", (model?.object(forKey: "gender") as? String)!, (model?.object(forKey: "name") as? String)!)
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
