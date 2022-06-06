//
//  CoFuturePublisher.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 15.03.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

#if canImport(Combine)
import Combine

@available(OSX 10.15, iOS 13.0, *)
internal final class CoFuturePublisher<Output> {
    
    internal typealias Failure = Error
    
    internal let future: CoFuture<Output>
    
    @inlinable internal init(future: CoFuture<Output>) {
        self.future = future
    }
    
}

@available(OSX 10.15, iOS 13.0, *)
extension CoFuturePublisher: Publisher {
    
    // 这是一个头结点, 所有没有向前进行挂钩的逻辑. 
    @inlinable internal func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
        let subscription = CoFutureSubscription(subscriber: subscriber,
                                                future: future)
        subscriber.receive(subscription: subscription)
    }
    
}

#endif
