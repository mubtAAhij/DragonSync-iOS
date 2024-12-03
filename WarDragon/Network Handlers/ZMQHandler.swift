//
//  ZMQHandler.swift
//  WarDragon
//
//  Created by Luke on 11/25/24.
//

import Foundation
import Network
import SwiftyZeroMQ5

class ZMQHandler: ObservableObject {
    @Published var isConnected = false
    public var isListeningCot = false
    
    //MARK - ZMQ setup
    
    init() {
        // Print ZeroMQ info
        let (major, minor, patch, _) = SwiftyZeroMQ.version
        print("ZeroMQ library version is \(major).\(minor) with patch level .\(patch)")
        print("SwiftyZeroMQ version is \(SwiftyZeroMQ.frameworkVersion)")
        
    }
    
    //MARK - Connection subscription
    
    func connect() {
        if isConnected {
            print("already connected, bailing")
            return
        }
        
        do {
            // Define a TCP endpoint along with the text that we are going to send/recv
            let endpoint     = "tcp://0.0.0.0:4224"
            let textToBeSent = "Testing..1-2-3"
            print("Sending message: \(textToBeSent) on \(endpoint)")
            
            // Request socket
            let context      = try SwiftyZeroMQ.Context()
            let requestor    = try context.socket(.request)
            try requestor.connect(endpoint)
            
            // Reply socket
            let replier      = try context.socket(.reply)
            try replier.bind(endpoint)
            
            // Send it without waiting and check the reply on other socket
            try requestor.send(string: textToBeSent, options: .dontWait)
            if let replyData = try replier.recv() {
                if let reply = String(data: replyData, encoding: .utf8), reply == textToBeSent {
                    print("Received reply data: \(reply)")
                    print("Match! Let's sub to drone data...")
                    disconnect()
                    subscribeToDroneData()
                } else {
                    print("Mismatch")
                }
            } else {
                print("No reply received")
            }
        } catch {
            print("Error: \(error)")
        }
    }
    
    func subscribeToDroneData() {
        do {
            let endpoint = "tcp://0.0.0.0:4224" // use as placeholder for git
            
            let context = try SwiftyZeroMQ.Context()
            let subscriber = try context.socket(.subscribe)
            
            // Connect to the endpoint
            try subscriber.connect(endpoint)
            
            // Subscribe to "AUX_ADV_IND" and "DroneID"
            try subscriber.setSubscribe("AUX_ADV_IND")
            try subscriber.setSubscribe("DroneID")
            
            print("Subscribed to AUX_ADV_IND and DroneID on \(endpoint)")
            
            while true {
                do {
                    // Unwrap the received data
                    if let message = try subscriber.recv() {
                        if let decodedMessage = String(data: message, encoding: .utf8) {
                            print("Received message: \(decodedMessage)")
                        } else {
                            print("Received non-UTF8 message")
                        }
                    } else {
                        print("No message received")
                    }
                } catch {
                    print("Error receiving message: \(error)")
                }
            }
        } catch {
            print("Error initializing subscriber: \(error)")
        }
    }
    
    
    //MARK - Disconnect and cleanup
    
    
    func disconnect() {
        isConnected = false
        isListeningCot = false
        
    }
    
    deinit {
        if isConnected {
            disconnect()
        }
    }
}
