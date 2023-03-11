
/*
 为什么一定要这种基础的数据结构呢.
 但是 Combine 里面, 都是自己定义的.
 
 Array 的操作, 会引起复制???
 Swfit 里面, 确实是没有链表这种数据结构 .
 */
internal struct CallbackStack<T> {
    
    private typealias Pointer = UnsafeMutablePointer<Node>
    
    private struct Node {
        // T 的价值, 就体现在这里.
        let callback: (T) -> Void
        var next = 0
    }
    
    private var rawValue = 0
    
    private init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    @inlinable internal init(isFinished: Bool = false) {
        rawValue = isFinished ? -1 : 0
    }
    
    @inlinable internal var isEmpty: Bool { rawValue <= 0 }
    @inlinable internal var isClosed: Bool { rawValue == -1 }
    
    // 使用了头插法.
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
            if atomicCAS(&rawValue, expected: address, desired: Int(bitPattern: pointer)) {
                return true
            }
        }
    }
    
    // Close 将自身状态改变了之后, 返回了原来的链表地址.
    @inlinable internal mutating func close() -> Self? {
        let old = atomicExchange(&rawValue, with: -1)
        return old > 0 ? CallbackStack(rawValue: old) : nil
    }
    
    // 然后在 finish 的时候, 才真正进行了内存的清理.
    // 所以一定要调用 finish 才可以. 
    @inlinable internal func finish(with result: T) {
        var address = rawValue
        while address > 0, let pointer = Pointer(bitPattern: address) {
            address = pointer.pointee.next
            // 在这里触发了真正的回调调用.
            pointer.pointee.callback(result)
            // Deinit 必须调用, 不知道 Swfit 在里面的实现细节. 
            pointer.deinitialize(count: 1).deallocate()
        }
    }
    
}
