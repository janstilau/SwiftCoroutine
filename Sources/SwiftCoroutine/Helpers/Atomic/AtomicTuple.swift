//
//  AtomicTuple.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 17.04.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

// 垃圾设计. 
internal struct AtomicTuple {
    
    internal typealias Tuple = (Int32, Int32)
    // 真正的存储, 是一个 64 位的 Int, 刚好可以作为一个 Tuple 使用.
    // 这里, 直接使用一个 Tuple 有什么问题??
    private(set) var rawValue = 0
    
    @inline(__always) internal var value: Tuple {
        get { unsafeBitCast(rawValue, to: Tuple.self) }
        set { atomicStore(&rawValue, value: unsafeBitCast(newValue, to: Int.self)) }
    }
    
    @discardableResult
    internal mutating func update(_ transform: (Tuple) -> Tuple) -> (old: Tuple, new: Tuple) {
        let (old, new) = atomicUpdate(&rawValue) {
            let tuple = unsafeBitCast($0, to: Tuple.self)
            return unsafeBitCast(transform(tuple), to: Int.self)
        }
        return (unsafeBitCast(old, to: Tuple.self), unsafeBitCast(new, to: Tuple.self))
    }
    
    @discardableResult
    internal mutating func update(keyPath: WritableKeyPath<Tuple, Int32>, with value: Int32) -> Int32 {
        update {
            var tuple = $0
            tuple[keyPath: keyPath] = value
            return tuple
        }.old[keyPath: keyPath]
    }
    
}
