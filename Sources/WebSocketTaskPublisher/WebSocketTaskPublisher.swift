//
//  WebSocketTaskPublisher.swift
//  WebSocketTaskPublisher
//
//  Created by Li-Heng Hsu on 2021/2/28.
//

import Combine
import Foundation

import Darwin

extension UnsafeMutablePointer where Pointee == os_unfair_lock_s {
    internal init() {
        let l = UnsafeMutablePointer.allocate(capacity: 1)
        l.initialize(to: os_unfair_lock())
        self = l
    }
    
    internal func cleanupLock() {
        deinitialize(count: 1)
        deallocate()
    }
    
    internal func lock() {
        os_unfair_lock_lock(self)
    }
    
    internal func tryLock() -> Bool {
        let result = os_unfair_lock_trylock(self)
        return result
    }
    
    internal func unlock() {
        os_unfair_lock_unlock(self)
    }
}

typealias Lock = os_unfair_lock_t

extension URLSession {
    
    
    /// Returns a publisher that wraps a URL session WebSocket task for a given URL.
    ///
    /// The publisher publishes data when the task receives messages, or terminates if the task closes or fails with an error.
    /// - Parameters:
    ///     - url: The URL for which to create a WebSocket task.
    ///     - taskConfigurationHandler: The URL request for which to create a data task.
    /// - Parameter task: The created WebSocket task, presented as a protocol.
    /// - Returns: A publisher that wraps a WebSocket task for the URL request.
    public func webSocketTaskPublisher(
        for url: URL,
        taskConfigurationHandler: @escaping (_ task: WebSocketTask) -> Void
    ) -> WebSocketTaskPublisher {
        
        let request = URLRequest(url: url)
        return WebSocketTaskPublisher(request: request, session: self, taskConfigurationHandler: taskConfigurationHandler)
    }
    
    /// Returns a publisher that wraps a URL session WebSocket task for a given URL request.
    ///
    /// The publisher publishes data when the task receives messages, or terminates if the task closes or fails with an error.
    /// - Parameters:
    ///     - request: The URL request for which to create a WebSocket task.
    ///     - taskConfigurationHandler: The URL request for which to create a data task.
    ///     - task: The created WebSocket task, presented as a protocol.
    /// - Returns: A publisher that wraps a WebSocket task for the URL request.
    public func webSocketTaskPublisher(
        for request: URLRequest,
        taskConfigurationHandler: @escaping (_ task: WebSocketTask) -> Void
    ) -> WebSocketTaskPublisher {
        
        return WebSocketTaskPublisher(request: request, session: self, taskConfigurationHandler: taskConfigurationHandler)
    }
    
    public struct WebSocketTaskPublisher: Publisher {
        public typealias Output = URLSessionWebSocketTask.Message
        public typealias Failure = Error
        
        
        public let request: URLRequest
        public let session: URLSession
        public let taskConfigurationHandler: (WebSocketTask) -> Void
        
        public init(
            request: URLRequest,
            session: URLSession,
            taskConfigurationHandler: @escaping (WebSocketTask) -> Void
        ) {
            self.request = request
            self.session = session
            self.taskConfigurationHandler = taskConfigurationHandler
        }
        
        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            subscriber.receive(subscription: Inner(self, subscriber, taskConfigurationHandler))
        }
        
        private typealias Parent = WebSocketTaskPublisher
        private final class Inner<Downstream: Subscriber>: Subscription where
            Downstream.Input == Parent.Output,
            Downstream.Failure == Parent.Failure {
            typealias Input = Downstream.Input
            typealias Failure = Downstream.Failure
            
            private let lock: Lock
            private var parent: Parent?             // GuardedBy(lock)
            private var downstream: Downstream?     // GuardedBy(lock)
            private var demand: Subscribers.Demand  // GuardedBy(lock)
            private var task: URLSessionWebSocketTask!   // GuardedBy(lock)
            private let taskConfigurationHandler: (WebSocketTask) -> Void
            
            init(_ parent: Parent, _ downstream: Downstream, _ taskConfigurationHandler: @escaping (WebSocketTask) -> Void) {
                self.lock = Lock()
                self.parent = parent
                self.downstream = downstream
                self.demand = .max(0)
                self.taskConfigurationHandler = taskConfigurationHandler
            }
            
            deinit {
                lock.cleanupLock()
            }
            
            // MARK: - Upward Signals
            func request(_ d: Subscribers.Demand) {
                precondition(d > 0, "Invalid request of zero demand")
                
                lock.lock()
                guard let p = parent else {
                    // We've already been cancelled so bail
                    lock.unlock()
                    return
                }
                
                // Avoid issues around `self` before init by setting up only once here
                if self.task == nil {
                    let task = p.session.webSocketTask(
                        with: p.request
                    )
                    self.task = task
                }
                
                self.demand += d
                let task = self.task!
                lock.unlock()
                
                task.resume()
                task.receive(completionHandler: handleReceivedMessage(result:))
                taskConfigurationHandler(task)
            }
            
            private func handleReceivedMessage(result: Result<Output, Failure>) {
                lock.lock()
                guard demand > 0,
                      parent != nil,
                      task != nil,
                      let ds = downstream
                else {
                    lock.unlock()
                    return
                }
                
                demand -= 1
                lock.unlock()
                
                switch result {
                case .success(let message):
                    let more = ds.receive(message)
                    
                    lock.lock()
                    demand += more
                    lock.unlock()
                    
                    task.receive(completionHandler: handleReceivedMessage(result:))
                    
                case .failure(let error):
                    ds.receive(completion: .failure(error))
                }
                
            }
            
            func cancel() {
                lock.lock()
                guard parent != nil else {
                    lock.unlock()
                    return
                }
                parent = nil
                downstream = nil
                demand = .max(0)
                let task = self.task
                self.task = nil
                lock.unlock()
                task?.cancel(with: .normalClosure, reason: nil)
            }
        }
    }
}
