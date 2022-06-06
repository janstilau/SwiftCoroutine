//
//  CoFutureSubscription.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 15.03.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

#if canImport(Combine)
import Combine

@available(OSX 10.15, iOS 13.0, *)
internal final class CoFutureSubscription<S: Subscriber, T>: Subscription where S.Input == T, S.Failure == Error {
    
    private let future: CoFuture<T>
    private var subscriber: S?
    
    @inlinable internal init(subscriber: S, future: CoFuture<T>) {
        self.future = future
        self.subscriber = subscriber
        // future 添加了一个回调, 在 Result 赋值之后, 进行后续节点的值的传送.
        // 这里面, 没有 demand 的管理. 
        future.addCallback { result in
            guard let subscriber = self.subscriber else { return }
            switch result {
            case .success(let result):
                _ = subscriber.receive(result)
                subscriber.receive(completion: .finished)
            case .failure(let error):
                subscriber.receive(completion: .failure(error))
            }
        }
    }
    
    @inlinable internal func cancel() {
        subscriber = nil
    }
    
    @inlinable internal func request(_ demand: Subscribers.Demand) {}
    
}
#endif
