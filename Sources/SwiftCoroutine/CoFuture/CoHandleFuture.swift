//
//  CoHandleFuture.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 06.01.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

class CoHandleFuture<Output>: CoFuture<Output> {
    
    private let parent: CoFuture<Output>
    
    @inlinable init(parent: CoFuture<Output>, handler: @escaping OutputHandler) {
        self.parent = parent
        super.init(mutex: parent.mutex)
        subscribe(with: handler)
    }
    
    @inlinable override var result: OutputResult? {
        parent.result
    }
    
    private func subscribe(with handler: @escaping OutputHandler) {
        mutex.lock()
        if let result = result {
            mutex.unlock()
            return handler(result)
        }
        subscribe(with: identifier, handler: handler)
        parent.subscribe(with: identifier) { [unowned self] in
            self.complete(with: $0)
        }
        mutex.unlock()
    }
    
    deinit {
        parent.unsubscribe(identifier)
    }
    
}