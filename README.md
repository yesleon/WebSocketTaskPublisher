# WebSocketTaskPublisher

This module let you use Combine for WebSocket tasks.

## Usage

```swift
let url = URL(string: "wss://example.com")!

self.subscription = URLSession.shared
    .webSocketTaskPublisher(for: url, taskConfigurationHandler: { task in
    
        // Optionally use or retain the generated task here.
        task.send(.string("Something something"))
        task.ping()
        self.webSocketTask = task
    })
    .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
            break
        case .failure(let error):
        
            // Handle all errors here.
            print(error)
        }
    }, receiveValue: { message in
    
        // Receive all messages here.
        print(message)
    })
```
