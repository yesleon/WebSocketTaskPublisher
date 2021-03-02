//
//  File.swift
//  
//
//  Created by 許立衡 on 2021/3/2.
//

import Foundation


public protocol WebSocketTask {
    func send(_ message: URLSessionWebSocketTask.Message, completion: @escaping () -> Void)
    func ping(completion: @escaping () -> Void)
}

extension WebSocketTask {
    
    public func send(_ message: URLSessionWebSocketTask.Message) {
        send(message) { }
    }
    
    public func ping() {
        ping { }
    }
}

extension URLSessionWebSocketTask: WebSocketTask {
    
    public func send(_ message: Message, completion: @escaping () -> Void) {
        send(message, completionHandler: { _ in completion() })
    }
    
    public func ping(completion: @escaping () -> Void) {
        sendPing(pongReceiveHandler: { _ in completion() })
    }
}
