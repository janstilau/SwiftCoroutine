//
//  AtomicInt.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 01.04.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

#if SWIFT_PACKAGE
import CCoroutine
#endif

@inlinable internal func atomicStore(_ pointer: UnsafeMutablePointer<Int>, value: Int) {
    __atomicStore(OpaquePointer(pointer), value)
}

@inlinable @discardableResult
internal func atomicAdd(_ pointer: UnsafeMutablePointer<Int>, value: Int) -> Int {
    __atomicFetchAdd(OpaquePointer(pointer), value)
}

@inlinable internal func atomicExchange(_ pointer: UnsafeMutablePointer<Int>, with value: Int) -> Int {
    __atomicExchange(OpaquePointer(pointer), value)
}

/*
 如果 ptr 指向的内存位置的当前值等于 expected 指向的值，那么就将 ptr 指向的内存位置的值设置为 desired 指向的值，然后返回 true。如果 ptr 指向的内存位置的当前值不等于 expected 指向的值，那么就将 expected 指向的值设置为 ptr 指向的内存位置的当前值，然后返回 false。

 这个函数的关键在于，比较和交换这两个操作是原子的，也就是说，在这两个操作之间，不会有其他线程修改 ptr 指向的内存位置的值。这使得 __atomicCompareExchange 函数可以在多线程环境中安全地更新共享数据。
 */
@discardableResult @inlinable
internal func atomicCAS(_ pointer: UnsafeMutablePointer<Int>, expected: Int, desired: Int) -> Bool {
    var expected = expected
    return __atomicCompareExchange(OpaquePointer(pointer), &expected, desired) != 0
}

@discardableResult @inlinable internal
func atomicUpdate(_ pointer: UnsafeMutablePointer<Int>, transform: (Int) -> Int) -> (old: Int, new: Int) {
    var oldValue = pointer.pointee, newValue: Int
    repeat { newValue = transform(oldValue) }
        while __atomicCompareExchange(OpaquePointer(pointer), &oldValue, newValue) == 0
    return (oldValue, newValue)
}
