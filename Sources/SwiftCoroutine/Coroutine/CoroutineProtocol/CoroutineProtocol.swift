#if os(Linux)
import Glibc
#else
import Darwin
#endif

@usableFromInline internal protocol CoroutineProtocol: AnyObject {
    
    typealias StackSize = CoroutineSpace.StackSize
    
    func await<T>(_ callback: (@escaping (T) -> Void) -> Void) throws -> T
    func await<T>(on scheduler: CoroutineScheduler, task: () throws -> T) throws -> T
    func cancel()
}

extension CoroutineProtocol {
    
    /*
     Task 里面的实现, 应该也是这样的. 就是将自己藏到了一个地方, 而这个地方, 刚好是自己的执行线程环境.
     这样虽然是类方法, 但是不同的协程在运行的时候, 其实是找到了不同的对象, 然后访问这个对象的数据, 而不是同一个数据.
     */
    /*
     线程特定数据是每个线程都有自己的一份数据副本，每个线程对其的读写操作都不会影响其他线程的数据。这对于多线程编程中的数据隔离非常有用。
     */
    @inlinable internal func performAsCurrent<T>(_ block: () -> T) -> T {
        let caller = pthread_getspecific(.coroutine)
        pthread_setspecific(.coroutine, Unmanaged.passUnretained(self).toOpaque())
        defer { pthread_setspecific(.coroutine, caller) }
        // 只有在 block 运行结束后, 才会调用 defer 里面的方法.
        return block()
    }
    
}

extension CoroutineSpace {
    
    @inlinable internal static var currentPointer: UnsafeMutableRawPointer? {
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


