//
//  SharedCoroutine.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 03.04.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

internal final class SharedCoroutine {
    
    internal typealias CompletionState = SharedCoroutineQueue.CompletionState
    
    private struct CachedStackBuffer {
        let startPointer: UnsafeMutableRawPointer
        let stackSize: Int
    }
    
    internal let dispatcher: SharedCoroutineDispatcher
    internal let queue: SharedCoroutineQueue
    private(set) var scheduler: CoroutineScheduler
    
    private var state: Int = .running
    private var environment: UnsafeMutablePointer<CoroutineContext.SuspendData>!
    private var stackBuffer: CachedStackBuffer!
    private var isCanceled = 0
    private var awaitTag = 0
    
    internal init(dispatcher: SharedCoroutineDispatcher, queue: SharedCoroutineQueue, scheduler: CoroutineScheduler) {
        self.dispatcher = dispatcher
        self.queue = queue
        self.scheduler = scheduler
    }
    
    // MARK: - Actions
    
    internal func start() -> CompletionState {
        performAsCurrent { perform(queue.context.start) }
    }
    
    internal func resume() -> CompletionState {
        performAsCurrent(resumeContext)
    }
    
    // 真正的协程恢复的地方.
    private func resumeContext() -> CompletionState {
        perform { queue.context.resume(from: environment.pointee._jumpBuffer) }
    }
    
    private func perform(_ block: () -> Bool) -> CompletionState {
        if block() { return .finished }
        while true {
            switch state {
            case .suspending:
                if atomicCAS(&state, expected: .suspending, desired: .suspended) {
                    return .suspended
                }
            case .running:
                return resumeContext()
            case .restarting:
                return .restarting
            default:
                return .suspended
            }
        }
    }
    
    private func suspend() {
        if environment == nil {
            environment = .allocate(capacity: 1)
            environment.initialize(to: .init())
        }
        queue.context.suspend(to: environment)
    }
    
    // MARK: - Stack
    
    internal func saveStack() {
        let size = environment.pointee._stackTop.distance(to: queue.context.stackBottom)
        let stack = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 16)
        // 不会吧所有的都存储下来, 只是把当前使用到的栈顶存储下来.
        stack.copyMemory(from: environment.pointee._stackTop, byteCount: size)
        stackBuffer = .init(startPointer: stack, stackSize: size)
    }
    
    internal func restoreStack() {
        environment.pointee._stackTop.copyMemory(from: stackBuffer.startPointer, byteCount: stackBuffer.stackSize)
        stackBuffer.startPointer.deallocate()
        stackBuffer = nil
    }
    
    deinit {
        environment?.pointee._jumpBuffer.deallocate()
        environment?.deallocate()
    }
    
}

// 真正的, 实现了 CoroutineProtocol 的实现类.
// 目前在类库里面, 只有这样的一个类, 实现了 CoroutineProtocol 的抽象.
extension SharedCoroutine: CoroutineProtocol {
    
    // Await, 参数是一个异步函数的触发器.
    // 这个异步函数, 接受一个回调, 来作为自己的 CompletionHandler
    
    /*
     { callback in
     URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
     }
     */
    internal func await<T>(_ asyncTrigger: (@escaping (T) -> Void) -> Void)
    throws -> T {
        if isCanceled == 1 { throw CoroutineError.canceled }
        state = .suspending
        
        let tagWhenTrigger = awaitTag
        var result: T!
        // 在这里, 使用异步 API 触发了异步函数.
        // 只有在异步 API 的回调里面, 才进行 resume 处理.
        asyncTrigger { value in
            while true {
                // 如果, id 已经改变了, 那么就没有必要进行 result 的赋值了.
                guard self.awaitTag == tagWhenTrigger else { return }
                
                // 唯一进行 awaitTag 改变的地方, 就是这里了.
                if atomicCAS(&self.awaitTag,
                             expected: tagWhenTrigger,
                             desired: tagWhenTrigger + 1) { break }
            }
            // 在 asyncTrigger 的异步回调里面, 是做真正的值的提取.
            // 所以, 实际上还是使用了以后的异步触发机制. 只是现在变为了, 只有异步返回之后, 才能进行后续的操作.
            result = value
            
            // 这里有点类似于条件锁, 在 commit 线程, 进行 lock 处理, 然后在异步 callback 中, 进行 unlock 的操作.
            // 这样, commit 线程才能继续进行.
            // 在异步操作完成之后, 进行调度.
            self.resumeIfSuspended()
        }
        if state == .suspending {
            // 在异步函数, 触发之后, 进行调度.
            suspend()
        }
        
        if isCanceled == 1 { throw CoroutineError.canceled }
        return result
    }
    
    internal func await<T>(on scheduler: CoroutineScheduler, task: () throws -> T)
    throws -> T {
        if isCanceled == 1 { throw CoroutineError.canceled }
        let currentScheduler = self.scheduler
        setScheduler(scheduler)
        defer { setScheduler(currentScheduler) }
        if isCanceled == 1 { throw CoroutineError.canceled }
        return try task()
        
    }
    
    private func setScheduler(_ scheduler: CoroutineScheduler) {
        self.scheduler = scheduler
        state = .restarting
        suspend()
    }
    
    internal func cancel() {
        atomicStore(&isCanceled, value: 1)
        resumeIfSuspended()
    }
    
    private func resumeIfSuspended() {
        while true {
            // 使用, atomicCAS 进行值的替换.
            // 不太明白, atomic_compare_exchange_strong 这样的意义在哪里.
            // 不过, 在协程的概念里面, 确实是听到了, 不要进行上锁, 而是进行原子操作的这样的语句.
            switch state {
            case .suspending:
                if atomicCAS(&state, expected: .suspending, desired: .running) { return }
            case .suspended:
                if atomicCAS(&state, expected: .suspended, desired: .running) {
                    // 真正的进行调度, 是在 queue 里面.
                    return queue.resume(coroutine: self)
                }
            default:
                return
            }
        }
    }
    
}

// 可以使用 Int 来当做状态值, 只是, 需要显式的进行特殊值的预先构建.
fileprivate extension Int {
    static let running = 0
    static let suspending = 1
    static let suspended = 2
    static let restarting = 3
}
