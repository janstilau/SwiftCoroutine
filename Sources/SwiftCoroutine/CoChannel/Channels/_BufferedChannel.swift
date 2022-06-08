//
//  _BufferedChannel.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 07.06.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

internal final class _BufferedChannel<T>: _Channel<T> {
    
    private typealias ReceiveCallback = (Result<T, CoChannelError>) -> Void
    
    private struct SendBlock {
        let element: T
        let resumeBlock: ((CoChannelError?) -> Void)?
    }
    
    private let capacity: Int
    private var consumeCallbacks = FifoQueue<ReceiveCallback>()
    private var generatorCallbacks = FifoQueue<SendBlock>()
    private var atomic = AtomicTuple() // 起始的状态是 0, 0, 前面是 count, 后面是 state
    
    internal init(capacity: Int) {
        self.capacity = max(0, capacity)
    }
    
    internal override var bufferType: CoChannel<T>.BufferType {
        switch capacity {
        case .max: return .unlimited
        case 0: return .none
        case let capacity: return .buffered(capacity: capacity)
        }
    }
    
    // MARK: - send
    
    // SendFuture 就是在 Future 的 SetResult 的时候, 触发对应的后续逻辑.
    internal override func sendFuture(_ future: CoFuture<T>) {
        future.whenSuccess { [weak self] in
            guard let self = self else { return }
            let (count, state) = self.atomic.update { count, state in
                if state != 0 { return (count, state) }
                return (count + 1, 0)
            }.old
            guard state == 0 else { return }
            
            if count < 0 {
                self.consumeCallbacks.blockingPop()(.success($0))
            } else {
                self.generatorCallbacks.push(.init(element: $0, resumeBlock: nil))
            }
        }
    }
    
    // 没有 awaitSend 中的 suspend 的操作. 返回值为 True 代表被消耗掉了, 否则就是, 满了.
    internal override func offer(_ element: T) -> Bool {
        let (count, state) = atomic.update { count, state in
            if state != 0 || count >= capacity { return (count, state) }
            return (count + 1, 0)
        }.old
        
        if state != 0 { return false }
        if count < 0 {
            consumeCallbacks.blockingPop()(.success(element))
            return true
        } else if count < capacity {
            generatorCallbacks.push(.init(element: element, resumeBlock: nil))
            return true
        }
        return false
    }
    
    // MARK: - MAIN
    
    internal override func awaitReceive() throws -> T {
        switch atomic.update({ count, state in
            // 如果, state 为 0, 也就是还在使用的状态.
            // 这个时候, count 可以是负数, 当是负数的时候, 就代表着有需求, 但是当前没有值.
            // 当有值到达的时候, 就使用存储的需求回调, 消耗掉这个值就可以了.
            if state == 0 { return (count - 1, 0) }
            return (Swift.max(0, count - 1), state)
        }).old {
            
        case (let count, let state) where count > 0:
            defer {
                if count == 1, state == 1 {
                    finish()
                }
            }
            // 在awaitReceive 中, 会是 sender 协程的唤醒操作.
            // 在 awaitSend 中, 会是 receiver 协程的唤醒操作.
            // 所以, 其实这和使用信号量, 来进行消费者生产者的同步, 没有太多的区别.
            return getCachedValue()
        case (_, 0):
            /*
             @inlinable public static func await<T>(_ callback: (@escaping (T) -> Void) -> Void) throws -> T {
             try current().await(callback)
             }
             */
            /*
             await, 在 await 中, 启动 receiveCallbacks.push 将回调进行存储.
             在 channel 接收到数据之后, 调用 receiveCallbacks 进行回调.
             receivedCallback 在 await 里面, 会进行协程的值的读取, 以及协程唤醒的逻辑.
             */
            
            // 使用 Coroutine.await 这种方式, 进行当前协程的获取.
            let result = try Coroutine.await { receivedCallback in consumeCallbacks.push(receivedCallback) }
            return try result.get()
        case (_, 1):
            throw CoChannelError.closed
        default:
            throw CoChannelError.canceled
        }
    }
    
    // 怎么解决, 同时操作 consumeCallbacks 的问题啊, 在这里在进行消耗, 在 awaitReceive 中进行添加. 在不同的协程里面运行, 不一定在同一个线程的.
    // 这样, 岂不是会有数据同步的问题.
    internal override func awaitSend(_ element: T) throws {
        switch atomic.update ({ count, state in
            // 向, Channel 中添加数据, 更新数量.
            // 如果 state 不是 0, 那么就不做任何的处理.
            if state != 0 { return (count, state) }
            return (count + 1, 0)
        }).old {
            
        case (_, 1):
            throw CoChannelError.closed
        case (_, 2):
            throw CoChannelError.canceled
        case (let count, _) where count < 0:
            // 当 Channel 接受到数据之后, 如果 count 小于 0, 则是 consumeCallbacks 已经存储了消费逻辑.
            // 弹出最顶的消费逻辑, 消耗刚刚添加进来的数据.
            consumeCallbacks.blockingPop()(.success(element))
        case (let count, _) where count < capacity:
            // 如果, 还能存储, 就缓存生成策略. 这里使用的是缓存生成方法的方式.
            generatorCallbacks.push(.init(element: element, resumeBlock: nil))
        default:
            // 非常糟糕的代码.
            /*
             SendBlock 在进行 getValue 的时候, 会调用自己的 resumeBlock
             而这个值, 是在这里填入的. 这个值是 await 的内部逻辑, 目的就是在于进行协程的唤醒.
             当, 容量不够的时候, 就进行协程的暂停, 直到 getValue 的时候, 消耗掉队列中的数据, 触发唤醒的操作.
             */
            try Coroutine.await { resumeCallBack in
                generatorCallbacks.push(.init(element: element, resumeBlock: resumeCallBack))
            }.map { throw $0 }
        }
    }
    
    
    // MARK: - receive
    
    
    // 和 Offer 对应的, 没有了 suspend 的机制.
    // 从当前队列中取值, 如果没有值了, 就是 Nil.
    internal override func poll() -> T? {
        let (count, state) = atomic.update { count, state in
            (Swift.max(0, count - 1), state)
        }.old
        
        guard count > 0 else { return nil }
        defer { if count == 1, state == 1 { finish() } }
        
        // Poll 和 await Recevice 相比, 少了等待的机制. 所以, 这个函数也就不是异步函数了.
        return getCachedValue()
    }
    
    internal override func whenReceive(_ callback: @escaping (Result<T, CoChannelError>) -> Void) {
        switch atomic.update({ count, state in
            if state == 0 { return (count - 1, 0) }
            return (Swift.max(0, count - 1), state)
        }).old {
        case (let count, let state) where count > 0:
            callback(.success(getCachedValue()))
            if count == 1, state == 1 { finish() }
        case (_, 0):
            // 如果, 当前没有值了, 那么存储 callback, 在得到新的值之后, 触发传递进来的 callback.
            consumeCallbacks.push(callback)
        case (_, 1):
            callback(.failure(.closed))
        default:
            callback(.failure(.canceled))
        }
    }
    
    internal override var count: Int {
        Int(max(0, atomic.value.0))
    }
    
    internal override var isEmpty: Bool {
        atomic.value.0 <= 0
    }
    
    private func getCachedValue() -> T {
        let block = generatorCallbacks.blockingPop()
        block.resumeBlock?(nil)
        return block.element
    }
    
    // MARK: - close
    
    internal override func close() -> Bool {
        // 如果, state 不是 0 代表着现在不是在运行态.
        // 那么保持 count, state 的值不改版
        // 否则就是从运行态到 Close 态的改变.
        let (count, state) = atomic.update { count, state in
            state == 0 ? (Swift.max(0, count), 1) : (count, state)
        }.old
        
        guard state == 0 else { return false }
        
        if count < 0 {
            /*
             // x.magnitude == 200
             For any numeric value x, x.magnitude is the absolute value of x. You can use the magnitude property in operations that are simpler to implement in terms of unsigned values, such as printing the value of an integer, which is just printing a ‘-’ character in front of an absolute value.
             let x = -200
             The global abs(_:) function provides more familiar syntax when you need to find an absolute value. In addition, because abs(_:) always returns a value of the same type, even in a generic context, using the function instead of the magnitude property is encouraged.
             */
            // 如果, count < 0, 代表着现在有消费者, 在 Close 的时候, 要通知这些消费者, 自己已经关闭了.
            // 之所以, 可以有多个消费者, 应该是生成一个 Channel 对象之后, 然后交给了好几个协程一起进行消费了.
            for _ in 0..<count.magnitude {
                consumeCallbacks.blockingPop()(.failure(.closed))
            }
        } else if count > 0 {
            // Count 大于 0, 并不代表着, 有生产者在等待着消费.
            // 只有当缓存的数据, 大于的 Capacity 的数据的时候, 生产者才会陷入到 await 的状态. 这个时候, resumeBlock 才有值.
            // 不过, 这里统一的调用一次, 也没有太大的问题.
            generatorCallbacks.forEach { $0.resumeBlock?(.closed) }
        } else {
            finish()
        }
        return true
    }
    
    // 恶心的写法, 0 代表正常, 1 代表已经关闭, 2 代表已经取消.
    internal override var isClosed: Bool {
        atomic.value.1 == 1
    }
    
    internal override var isCanceled: Bool {
        atomic.value.1 == 2
    }
    
    // MARK: - cancel
    
    internal override func cancel() {
        let count = atomic.update { _ in (0, 2) }.old.0
        if count < 0 {
            for _ in 0..<count.magnitude {
                consumeCallbacks.blockingPop()(.failure(.canceled))
            }
        } else if count > 0 {
            for _ in 0..<count {
                generatorCallbacks.blockingPop().resumeBlock?(.canceled)
            }
        }
        finish()
    }
    
    deinit {
        while let block = consumeCallbacks.pop() {
            block(.failure(.canceled))
        }
        consumeCallbacks.free()
        generatorCallbacks.free()
    }
}
