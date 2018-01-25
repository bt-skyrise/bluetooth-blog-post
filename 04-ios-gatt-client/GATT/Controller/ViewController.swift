//
//  ViewController.swift
//  GATT
//
//  Created by Konrad Roj on 24.11.2017.
//  Copyright © 2017 Skyrise.tech. All rights reserved.
//

import UIKit
import CoreBluetooth
import BlueCapKit

public enum CapError: Error {
    case serviceNotFound
}

class ViewController: UIViewController {
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var arg1TextField: UITextField!
    @IBOutlet weak var arg2TextField: UITextField!
    @IBOutlet weak var resultLabel: UILabel!
    
    private let manager = CentralManager()
    
    private var peripheral: Peripheral?
    private var arg1Char: Characteristic?
    private var arg2Char: Characteristic?
    private var resultChar: Characteristic?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        connectButton.titleLabel?.numberOfLines = 3
        connectButton.titleLabel?.lineBreakMode = .byWordWrapping
        connectButton.titleLabel?.textAlignment = .center
        
        arg1TextField.delegate = self
        arg2TextField.delegate = self
        
        arg1TextField.becomeFirstResponder()
        
        setNeedsStatusBarAppearanceUpdate()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    @IBAction func tapToConnectAction(_ sender: Any) {
        setupGatt()
    }

}

private extension ViewController {
    
    func prepareUI() {
        self.setInitialTextFieldValues()
        
        writeArg1(text: arg1TextField.text!)
        writeArg2(text: arg2TextField.text!)
    }
    
    func setInitialTextFieldValues() {
        self.arg1TextField.text = "0"
        self.arg2TextField.text = "0"
    }
    
}

private extension ViewController {
    
    func setupGatt() {
        let stateChangeFuture = manager.whenStateChanges()
        let scanStream = stateChangeFuture.flatMap { [unowned self] state -> FutureStream<Peripheral> in
            switch state {
            case .poweredOn:
                return self.manager.startScanning(forServiceUUIDs: [GattUUID.service])
            case .poweredOff, .unauthorized, .unsupported, .resetting, .unknown:
                self.disconnectFromGatt()
                throw CapError.serviceNotFound
            }
        }
        
        let peripherialStream = scanStream.flatMap { [unowned self] discoveredPeripheral  -> FutureStream<Void> in
            self.manager.stopScanning()
            
            self.peripheral = discoveredPeripheral
            
            return self.peripheral!.connect(connectionTimeout: 10, capacity: 5)
        }
        
        let discoveryStream = peripherialStream.flatMap { [unowned self] () -> Future<Void> in
            return (self.peripheral?.discoverServices([GattUUID.service]))!
        }.flatMap { [unowned self] () -> Future<Void> in
            let service = self.peripheral?.services(withUUID: GattUUID.service)?.first
            
            DispatchQueue.main.async {
                self.connectButton.setTitle("Connected: \(service!.uuid)", for: .normal)
            }
            
            return service!.discoverCharacteristics([GattUUID.arg1, GattUUID.arg2, GattUUID.result])
        }
        
        _ = discoveryStream.andThen { [unowned self] in
            let service = self.peripheral?.services(withUUID: GattUUID.service)?.first
            
            guard let resultCharacteristic = service?.characteristics(withUUID: GattUUID.result)?.first else {
                self.disconnectFromGatt()
                return
            }
            
            guard let arg1Characteristic = service?.characteristics(withUUID: GattUUID.arg1)?.first else {
                self.disconnectFromGatt()
                return
            }
            
            guard let arg2Characteristic = service?.characteristics(withUUID: GattUUID.arg2)?.first else {
                self.disconnectFromGatt()
                return
            }
            
            self.resultChar = resultCharacteristic
            self.arg1Char = arg1Characteristic
            self.arg2Char = arg2Characteristic
            
            self.prepareUI()
        }
    }
    
    func disconnectFromGatt() {
        manager.disconnectAllPeripherals()
        manager.removeAllPeripherals()
        manager.invalidate()
        
        peripheral = nil
        arg1Char = nil
        arg2Char = nil
        resultChar = nil
        
        self.connectButton.setTitle("Disconnected, tap to reconnect", for: .normal)
        self.setInitialTextFieldValues()
    }
    
    func readResult() {
        let readFuture = self.resultChar?.read(timeout: 5)
        readFuture?.onSuccess { [unowned self] (_) in
            let uint: [UInt8] = [UInt8](self.resultChar!.dataValue!)
            DispatchQueue.main.async {
                self.resultLabel.text = String(describing: uint.first ?? 0)
            }
        }
        readFuture?.onFailure { (_) in
            print("read error")
        }
    }
    
    private func writeArg1(text: String) {
        let uint = text.map { (val) -> UInt8 in
            return UInt8(String(val))!
        }
        
        let data = Data(bytes: uint, count: MemoryLayout<UInt8>.size)
        let writeFuture = self.arg1Char?.write(data: data)
        writeFuture?.onSuccess(completion: { [unowned self] (_) in
            print("write succes")
            
            self.readResult()
        })
        writeFuture?.onFailure(completion: { (e) in
            print("write failed")
        })
    }
    
    private func writeArg2(text: String) {
        let uint = text.map { (val) -> UInt8 in
            return UInt8(String(val))!
        }
        
        let data = Data(bytes: uint, count: MemoryLayout<UInt8>.size)
        let writeFuture = self.arg2Char?.write(data: data)
        writeFuture?.onSuccess(completion: { [unowned self] (_) in
            print("write succes")
            
            self.readResult()
        })
        writeFuture?.onFailure(completion: { (e) in
            print("write failed")
        })
    }
    
}

extension ViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        textField.text = string

        if textField.text?.count == 0 {
            textField.text = "0"
        }
        
        if textField == arg1TextField {
            writeArg1(text: textField.text!)
        } else {
            writeArg2(text: textField.text!)
        }
        
        return false
    }
    
}
