//
//  InterfaceController.swift
//  PhilipsControllerWatch Extension
//
//  Created by Michael Mouchous on 01/10/2017.
//  Copyright © 2017 Michael Mouchous. All rights reserved.
//

import WatchKit
import Foundation


class InterfaceController: WKInterfaceController {

    let communicator = PCPhilipsCommunicator()
    @IBOutlet var picker: WKInterfacePicker!
    @IBAction func pickerDidSelect(_ value: Int) {
        communicator.getValue(for: communicator.cmds_get.keys.sorted()[value])
    }
    @IBAction func sliderDidChanged(_ value: Float) {
        let value = Int(value*10)
        communicator.postValue(for: "volume", body: "{ 'current': \(value), 'muted': false }")
    }
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        let items = communicator.cmds_get.keys.sorted().map {  (s: String) -> WKPickerItem in
            let item = WKPickerItem()
            item.title = s
            return item
        }

        picker.setItems(items)
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
