//
//  BluetoothManager.swift
//  SimpleTimerPeri
//
//  Created by Jay Tucker on 6/30/15.
//  Copyright (c) 2015 Imprivata. All rights reserved.
//

import UIKit
import CoreBluetooth

class BluetoothManager: NSObject {
    
    private let serviceUUID        = CBUUID(string: "193DB24F-E42E-49D2-9A70-6A5616863A9D")
    private let characteristicUUID = CBUUID(string: "43CDD5AB-3EF6-496A-A4CC-9933F5ADAF68")
    
    private var peripheralManager: CBPeripheralManager!
    
    private var uiBackgroundTaskIdentifier: UIBackgroundTaskIdentifier!
    
    private let maxCount = 20
    private var currentCount = 0
    
    // See:
    // http://stackoverflow.com/questions/24218581/need-self-to-set-all-constants-of-a-swift-class-in-init
    // http://stackoverflow.com/questions/24441254/how-to-pass-self-to-initializer-during-initialization-of-an-object-in-swift
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    private func timestamp() -> String {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss.SSS"
        return dateFormatter.stringFromDate(NSDate())
    }
    
    private func log(message: String) {
        print("[\(timestamp())] \(message)")
    }

    private func addService() {
        log("addService")
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        let service = CBMutableService(type: serviceUUID, primary: true)
        let characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: CBCharacteristicProperties.Write,
            value: nil,
            permissions: CBAttributePermissions.Writeable)
        service.characteristics = [characteristic]
        peripheralManager.addService(service)
    }
    
    private func startAdvertising() {
        log("startAdvertising")
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID]])
    }

    private func startCount() {
        log("startCounting")
        currentCount = 0
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            self.beginBackgroundTask()
            
            let delay = 15.0 // self.calculateDelay()
            let delayStr = String(format: "%.3f", delay)
            self.log("will start counting in \(delayStr) secs")
            
            let timer = NSTimer.scheduledTimerWithTimeInterval(delay, target: self, selector: #selector(BluetoothManager.nextCount), userInfo: nil, repeats: false)
            NSRunLoop.currentRunLoop().addTimer(timer, forMode: NSDefaultRunLoopMode)
            NSRunLoop.currentRunLoop().run()
        })
    }
    
    func nextCount() {
        currentCount += 1
        log("\(currentCount)/\(maxCount)")
        if currentCount < maxCount {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                usleep(100000)
                self.nextCount()
            })
        } else {
            endBackgroundTask()
        }
    }

    private func calculateDelay() -> Double {
        log("calculateDelay")
        let now = NSDate()
        var ti = now.timeIntervalSinceReferenceDate
        
        // round up to next send interval
        let sendInterval = 30.0
        ti = ti - (ti % sendInterval) + sendInterval
        let sendTime = NSDate(timeIntervalSinceReferenceDate: ti)
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        log("now  \(dateFormatter.stringFromDate(now))")
        log("send \(dateFormatter.stringFromDate(sendTime))")
        
        let delay = sendTime.timeIntervalSinceDate(now)
        return delay
    }
    
    private func beginBackgroundTask() {
        log("beginBackgroundTask")
        uiBackgroundTaskIdentifier = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler {
            self.endBackgroundTaskExpirationHandler()
        }
        log("uiBackgroundTaskIdentifier \(uiBackgroundTaskIdentifier)")
        backgroundTimeRemaining()
    }
    
    private func endBackgroundTask() {
        log("endBackgroundTask")
        log("uiBackgroundTaskIdentifier \(uiBackgroundTaskIdentifier)")
        backgroundTimeRemaining()
        UIApplication.sharedApplication().endBackgroundTask(uiBackgroundTaskIdentifier)
        uiBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    }
    
    private func endBackgroundTaskExpirationHandler() {
        log("endBackgroundTaskExpirationHandler")
        log("uiBackgroundTaskIdentifier \(uiBackgroundTaskIdentifier)")
        backgroundTimeRemaining()
        UIApplication.sharedApplication().endBackgroundTask(uiBackgroundTaskIdentifier)
        uiBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    }
    
    private func backgroundTimeRemaining() {
        let backgroundTimeRemaining = UIApplication.sharedApplication().backgroundTimeRemaining
        log("backgroundTimeRemaining \(backgroundTimeRemaining)")
    }

}

extension BluetoothManager: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(peripheralManager: CBPeripheralManager) {
        var caseString: String!
        switch peripheralManager.state {
        case .Unknown:
            caseString = "Unknown"
        case .Resetting:
            caseString = "Resetting"
        case .Unsupported:
            caseString = "Unsupported"
        case .Unauthorized:
            caseString = "Unauthorized"
        case .PoweredOff:
            caseString = "PoweredOff"
        case .PoweredOn:
            caseString = "PoweredOn"
        }
        log("peripheralManagerDidUpdateState \(caseString)")
        if peripheralManager.state == .PoweredOn {
            addService()
        }
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, didAddService service: CBService, error: NSError?) {
        var message = "peripheralManager didAddService "
        if error == nil {
            message += "ok"
            log(message)
            startAdvertising()
        } else {
            message = "error " + error!.localizedDescription
            log(message)
        }
    }
    
    func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
        var message = "peripheralManagerDidStartAdvertising "
        if error == nil {
            message += "ok"
        } else {
            message = "error " + error!.localizedDescription
        }
        log(message)
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequests requests: [CBATTRequest]) {
        log("peripheralManager didReceiveWriteRequests \(requests.count)")
        if requests.count == 0 {
            return
        }
        let request = requests[0] 
        peripheralManager.respondToRequest(request, withResult: CBATTError.Success)
        startCount()
    }
    
}
