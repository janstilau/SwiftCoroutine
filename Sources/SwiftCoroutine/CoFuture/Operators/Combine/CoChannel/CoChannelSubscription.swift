//
//  CoChannelSubscription.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 11.06.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

#if canImport(Combine)
import Combine

@available(OSX 10.15, iOS 13.0, *)
internal final class CoChannelSubscription<S: Subscriber, T>: Subscription where S.Input == T, S.Failure == CoChannelError {
    
    private let receiver: CoChannel<T>.Receiver
    private var subscriber: S?
    
    @inlinable internal init(subscriber: S, receiver: CoChannel<T>.Receiver) {
        self.receiver = receiver
        self.subscriber = subscriber
        func subscribe() {
            // 使用 when 和 使用 on, 都是合理的命名方式.
            // whenReceive 只会填充一次回调, 然后有值确定之后, 就消耗了
            // 所以每次获取到值之后, 要主动的再次进行注册. 
            receiver.whenReceive { result in
                guard let subscriber = self.subscriber else { return }
                switch result {
                case .success(let result):
                    _ = subscriber.receive(result)
                    subscribe()
                case .failure(let error) where error == .canceled:
                    subscriber.receive(completion: .failure(error))
                case .failure:
                    subscriber.receive(completion: .finished)
                }
            }
        }
        subscribe()
    }
    
    // cancel 不要影响到 chanel 的机制, 还可能有其他的地方在使用到. 比如别的线程在 await. 
    @inlinable internal func cancel() {
        subscriber = nil
    }
    
    @inlinable internal func request(_ demand: Subscribers.Demand) {}
    
}
#endif
