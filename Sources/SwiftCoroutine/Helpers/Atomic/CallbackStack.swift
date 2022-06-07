//
//  CallbackStack.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 09.05.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

// 使用链表的方式, 将所有的回调进行了存储.
// 使用数组有什么问题????
internal struct CallbackStack<T> {
    
    private struct Node {
        let callback: (T) -> Void
        var next = 0
    }
    
    // 大量的使用了 typealias
    private typealias Pointer = UnsafeMutablePointer<Node>
    
    // 超级傻逼, 使用一个 Int 值做各种业务上的判断.
    // 谁他妈和完全和你的想法一样. 
    private var rawValue = 0
    
    private init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    @inlinable internal init(isFinished: Bool = false) {
        rawValue = isFinished ? -1 : 0
    }
    
    @inlinable internal var isEmpty: Bool { rawValue <= 0 }
    @inlinable internal var isClosed: Bool { rawValue == -1 }
    
    // 链表头插法进行存储.
    @inlinable internal mutating func append(_ callback: @escaping (T) -> Void) -> Bool {
        var pointer: Pointer!
        while true {
            let address = rawValue
            if address < 0 {
                pointer?.deinitialize(count: 1).deallocate()
                return false
            } else if pointer == nil {
                pointer = .allocate(capacity: 1)
                pointer.initialize(to: Node(callback: callback))
            }
            pointer.pointee.next = address
            if atomicCAS(&rawValue,
                         expected: address,
                         desired: Int(bitPattern: pointer)) {
                return true
            }
        }
    }
    
    // Close 返回的值, 都会紧接着一个 Finish 的调用. 也即是下面的方法.
    // 在里面, 会有内存的管理. 所以这里不会有内存泄漏的问题.
    @inlinable internal mutating func close() -> Self? {
        let old = atomicExchange(&rawValue, with: -1)
        return old > 0 ? CallbackStack(rawValue: old) : nil
    }
    
    @inlinable internal func finish(with result: T) {
        var address = rawValue
        while address > 0, let pointer = Pointer(bitPattern: address) {
            address = pointer.pointee.next
            // 真正的所有回调的触发, 是在这里.
            pointer.pointee.callback(result)
            pointer.deinitialize(count: 1).deallocate()
        }
    }
    
}
