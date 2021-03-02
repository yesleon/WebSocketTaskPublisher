//
//  WebSocketPublisher.swift
//  WebSocketPublisher
//
//  Created by 許立衡 on 2021/2/28.
//

import Combine
import Foundation

public struct WebSocketTaskPublisher: Publisher {
    public typealias Output = URLSessionWebSocketTask.Message
    public typealias Failure = Error
    
    private class Subscription<S: Subscriber>: Combine.Subscription where S.Failure == Error, S.Input == URLSessionWebSocketTask.Message {
        
        var task: URLSessionWebSocketTask?
        let subscriber: S
        
        init(task: URLSessionWebSocketTask, subscriber: S) {
            self.task = task
            self.subscriber = subscriber
        }
        
        func request(_ demand: Subscribers.Demand) {
            
            if let limit = demand.max {
                guard limit > 0 else { return }
            }
            task?.receive { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let message):
                    let additionalDemand = self.subscriber.receive(message)
                    if let demand = demand.max, let additionalDemand = additionalDemand.max {
                        self.request(.max(demand + additionalDemand))
                    } else {
                        self.request(.unlimited)
                    }
                case .failure(let error):
                    self.subscriber.receive(completion: .failure(error))
                    self.cancel()
                }
            }
        }
        
        func cancel() {
            task?.cancel(with: .normalClosure, reason: nil)
            task = nil
        }
    }
    
    let session: URLSession
    let request: URLRequest
    let taskConfigurationHandler: (WebSocketTask) -> Void
    
    init(session: URLSession, request: URLRequest, taskConfigurationHandler: @escaping (WebSocketTask) -> Void) {
        self.session = session
        self.request = request
        self.taskConfigurationHandler = taskConfigurationHandler
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        let task = session.webSocketTask(with: request)
        task.resume()
        taskConfigurationHandler(task)
        let subscription = Subscription(task: task, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

extension URLSession {
    
    public func webSocketTaskPublisher(with request: URLRequest, taskConfigurationHandler: @escaping (WebSocketTask) -> Void) -> WebSocketTaskPublisher {
        
        .init(session: self, request: request, taskConfigurationHandler: taskConfigurationHandler)
    }
    
    public func webSocketTaskPublisher(with url: URL, taskConfigurationHandler: @escaping (WebSocketTask) -> Void) -> WebSocketTaskPublisher {
        
        .init(session: self, request: .init(url: url), taskConfigurationHandler: taskConfigurationHandler)
    }
}
