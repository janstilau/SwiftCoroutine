#if SWIFT_PACKAGE
import CCoroutine
#endif

#if os(Linux)
import Glibc
#else
import Darwin
#endif

internal final class CoroutineContext {
    
    internal let haveGuardPage: Bool
    // 栈大小.
    internal let stackSize: Int
    // 开辟的栈地址.
    private let stackAddress: UnsafeMutableRawPointer
    // 协程跳转前的环境, jumpbuffer
    private let returnEnv: UnsafeMutableRawPointer
    // 协程真正的任务.
    internal var block: (() -> Void)?
    
    internal init(stackSize: Int, guardPage: Bool = true) {
        self.stackSize = stackSize
        returnEnv = .allocate(byteCount: .environmentSize, alignment: 16)
        haveGuardPage = guardPage
        if guardPage {
            stackAddress = .allocate(byteCount: stackSize + .pageSize, alignment: .pageSize)
            mprotect(stackAddress, .pageSize, PROT_READ)
        } else {
            stackAddress = .allocate(byteCount: stackSize, alignment: .pageSize)
        }
    }
    
    @inlinable internal var stackBottom: UnsafeMutableRawPointer {
        .init(stackAddress + stackSize)
    }
    
    // MARK: - Start
    
    @inlinable internal func start() -> Bool {
        __start(returnEnv, stackBottom, Unmanaged.passUnretained(self).toOpaque()) {
            // performBlock 返回了之前存储的 returnEnv, 然后给 __longjmp 传递 finished
            // 这也就是 start 方法的返回值了
            __longjmp(Unmanaged<CoroutineContext>
                .fromOpaque($0!)
                .takeUnretainedValue()
                .performBlock(), .finished)
        } == .finished
    }
    
    // 上面 __longjmp 的返回值是 returnEnv, 是在 _start 里面, 存储的 returnEnv
    /*
     __start(returnEnv 方法, 保存当前的环境, 然后调用 performBlock
     所以, start 的真实作用是, 保存当前的环境, 然后开启一个协程环境, 调用传递过来的闭包. 最后, 闭包调用结束之后, 会跳转回原来的环境.
     并且, 闭包会在执行完毕之后, 主动进行 = nil 的操作, 清空引用.
     */
    private func performBlock() -> UnsafeMutableRawPointer {
        block?()
        block = nil
        return returnEnv
    }
    
    // MARK: - Operations
    
    internal struct SuspendData {
        let stackTop: UnsafeMutableRawPointer
        var sp: UnsafeMutableRawPointer!
    }
    
    @inlinable internal func resume(from env: UnsafeMutableRawPointer) -> Bool {
        __save(env, returnEnv, .suspended) == .finished
    }
    
    @inlinable internal func suspend(to data: UnsafeMutablePointer<SuspendData>) {
        __suspend(data.pointee.stackTop, &data.pointee.sp, returnEnv, .suspended)
    }
    
    @inlinable internal func suspend(to env: UnsafeMutableRawPointer) {
        __save(returnEnv, env, .suspended)
    }
    
    deinit {
        if haveGuardPage {
            mprotect(stackAddress, .pageSize, PROT_READ | PROT_WRITE)
        }
        returnEnv.deallocate()
        stackAddress.deallocate()
    }
    
}

extension Int32 {
    
    fileprivate static let suspended: Int32 = -1
    fileprivate static let finished: Int32 = 1
    
}

extension CoroutineContext.SuspendData {
    
    internal init() {
        self = .init(stackTop: .allocate(byteCount: .environmentSize, alignment: 16), sp: nil)
    }
    
}
