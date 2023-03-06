//
//  CoroutineProtocol.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 07.03.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif

@usableFromInline internal protocol CoroutineProtocol: AnyObject {
    
    typealias StackSize = Coroutine.StackSize
    
    func await<T>(_ callback: (@escaping (T) -> Void) -> Void) throws -> T
    
    func await<T>(on scheduler: CoroutineScheduler,
                  task: () throws -> T) throws -> T
    
    func cancel()
    
}

extension CoroutineProtocol {
    
    // 在这里, 完成了线程上面, 当前运行协程状态的记录.
    // 这样的写法很好, 将操作前后将要完成的动作, 统一的进行了管理.
    // 将真正的业务动作, 放到了 block 内进行执行. 这样各个函数之间的责任更加的明确.
    @inlinable internal func performAsCurrent<T>(_ block: () -> T) -> T {
        let caller = pthread_getspecific(.coroutine)
        pthread_setspecific(.coroutine, Unmanaged.passUnretained(self).toOpaque())
        
        // 在 Block 的结束的时候, 其实会进行当前协程的回撤动作. 
        defer { pthread_setspecific(.coroutine, caller) }
        return block()
    }
    
}

extension Coroutine {
    
    // 在刚开始, 是没有这个值的. 这个值只会在上面 performAsCurrent 中进行赋值.
    @inlinable internal static var currentPointer: UnsafeMutableRawPointer? {
        pthread_getspecific(.coroutine)
    }
    
    @inlinable internal static func current() throws -> CoroutineProtocol {
        if let pointer = currentPointer,
           let coroutine = Unmanaged<AnyObject>.fromOpaque(pointer)
            .takeUnretainedValue() as? CoroutineProtocol {
            return coroutine
        }
        // 一定要在当前的 Thread 中进行 CoroutineProtocol 的赋值.
        // 因为实际上, 协程是要进行自己调用环境的单独存储的, 如果没有打造这个环境, 是不应该进行协程的逻辑的触发的. 
        throw CoroutineError.calledOutsideCoroutine
    }
    
}

extension pthread_key_t {
    // 创建了一个 pthread_getspecific 所使用的特定的数据类型.
    @usableFromInline internal static let coroutine: pthread_key_t = {
        var key: pthread_key_t = .zero
        pthread_key_create(&key, nil)
        return key
    }()
}


