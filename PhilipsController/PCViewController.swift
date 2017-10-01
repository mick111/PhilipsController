//
//  ViewController.swift
//  Philips Controller
//
//  Created by Michael Mouchous on 28/09/2017.
//  Copyright © 2017 Michael Mouchous. All rights reserved.
//

import UIKit
extension PCViewController: UIPickerViewDataSource, UIPickerViewDelegate {



    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return communicator.cmds.count
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return communicator.cmds[component].keys.count
    }


    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return communicator.cmds[component].keys.sorted()[row]
    }

    ///{ "key"  : "Standby" }
    ///{'current': targetlevel, 'muted': False}
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let cmd = communicator.cmds[component].keys.sorted()[row]
        switch (component, row) {
        case (0, _):
            communicator.getValue(for: cmd)
        case (1, 0):
            communicator.postValue(for: cmd, body: "{ 'key': 'Standby' }")
        case (1, 1):
            communicator.postValue(for: cmd, body: "{ 'current': 42, 'muted': False }")
        case (1, 2):
            communicator.postValue(for: cmd, body: "{ 'current': 42, 'muted': True }")
        default:
            break
        }
    }
}
class PCViewController: UIViewController {
    @IBOutlet weak var pickerView: UIPickerView!

    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var ha1: UITextField!
    @IBAction func saveHa1(_ sender: Any) {
        if let ha1 = ha1.text, let username = username.text {
        communicator.save(password: ha1, for: username)
        }
    }

    @IBOutlet weak var response: UITextView!
    let communicator = PCPhilipsCommunicator()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(forName: .newValue,
                                               object: communicator, queue: nil)
        { notification in
            DispatchQueue.main.async {
                self.response.text = (notification.userInfo?[.response] as? String) ?? ""
            }
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

