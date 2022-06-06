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
    func await<T>(on scheduler: CoroutineScheduler, task: () throws -> T) throws -> T
    func cancel()
}

extension CoroutineProtocol {
    
    // 将, 当前的协程, 设置到线程里面. 
    @inlinable internal func performAsCurrent<T>(_ block: () -> T) -> T {
        let caller = pthread_getspecific(.coroutine)
        pthread_setspecific(.coroutine, Unmanaged.passUnretained(self).toOpaque())
        // 在, block 调用之后, 会让出占位的.
        defer { pthread_setspecific(.coroutine, caller) }
        return block()
    }
    
}

extension Coroutine {
    
    @inlinable internal static var currentPointer: UnsafeMutableRawPointer? {
        // 从线程中, 获取当前执行的协程对象.
        pthread_getspecific(.coroutine)
    }
    
    @inlinable internal static func current() throws -> CoroutineProtocol {
        if let pointer = currentPointer,
            let coroutine = Unmanaged<AnyObject>.fromOpaque(pointer)
                .takeUnretainedValue() as? CoroutineProtocol {
            return coroutine
        }
        throw CoroutineError.calledOutsideCoroutine
    }
    
}

extension pthread_key_t {
    
    @usableFromInline internal static let coroutine: pthread_key_t = {
        var key: pthread_key_t = .zero
        pthread_key_create(&key, nil)
        return key
    }()
}


