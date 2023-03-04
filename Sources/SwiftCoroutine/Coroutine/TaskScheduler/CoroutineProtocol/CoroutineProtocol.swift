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
        defer { pthread_setspecific(.coroutine, caller) }
        return block()
    }
    
}

extension Coroutine {
    
    @inlinable internal static var currentPointer: UnsafeMutableRawPointer? {
        pthread_getspecific(.coroutine)
    }
    
    @inlinable internal static func current() throws -> CoroutineProtocol {
        // 从 rawPointer 到特定的 Swfit 的转化, 必须用到 Unmanaged 这个类.
        // A type for propagating an unmanaged object reference.
        if let pointer = currentPointer,
           let coroutine = Unmanaged<AnyObject>.fromOpaque(pointer)
            .takeUnretainedValue() as? CoroutineProtocol {
            return coroutine
        }
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


