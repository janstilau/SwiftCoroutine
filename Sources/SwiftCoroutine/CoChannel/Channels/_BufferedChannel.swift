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
    
    // MARK: - receive
    
    internal override func awaitReceive() throws -> T {
        switch atomic.update({ count, state in
            // 如果, state 为 0, 也就是还在使用的状态.
            // 这个时候, count 可以是负数, 当是负数的时候, 就代表着有需求, 但是当前没有值.
            // 当有值到达的时候, 就使用存储的需求回调, 消耗掉这个值就可以了.
            if state == 0 { return (count - 1, 0) }
            return (Swift.max(0, count - 1), state)
        }).old {
        case (let count, let state) where count > 0:
            defer { if count == 1, state == 1 { finish() } }
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
        let (count, state) = atomic.update { count, state in
            state == 0 ? (Swift.max(0, count), 1) : (count, state)
        }.old
        guard state == 0 else { return false }
        if count < 0 {
            for _ in 0..<count.magnitude {
                consumeCallbacks.blockingPop()(.failure(.closed))
            }
        } else if count > 0 {
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
