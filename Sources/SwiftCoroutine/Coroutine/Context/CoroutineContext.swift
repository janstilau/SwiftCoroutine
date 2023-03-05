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
    internal let stackSize: Int
    private let stack: UnsafeMutableRawPointer
    private let returnEnv: UnsafeMutableRawPointer
    internal var businessBlock: (() -> Void)?
    
    internal init(stackSize: Int, guardPage: Bool = true) {
        self.stackSize = stackSize
        returnEnv = .allocate(byteCount: .environmentSize, alignment: 16)
        haveGuardPage = guardPage
        if guardPage {
            stack = .allocate(byteCount: stackSize + .pageSize, alignment: .pageSize)
            mprotect(stack, .pageSize, PROT_READ)
        } else {
            stack = .allocate(byteCount: stackSize, alignment: .pageSize)
        }
    }
    
    @inlinable internal var stackTop: UnsafeMutableRawPointer {
        .init(stack + stackSize)
    }
    
    // MARK: - Start
    
    @inlinable internal func start() -> Bool {
        // Unmanaged.passUnretained(self).toOpaque() 当做后面传入 Block 的参数
        // Unmanaged<CoroutineContext> .fromOpaque($0!).takeUnretainedValue() 则是恢复成为 Self
        // 这是为了使用 C 风格代码做的转化.
        // 直接调用传递过来的闭包, 是一件麻烦的事情, 之所以这样转化, 就是使用面向对象的方式, 来进行管理.
        
        /*
         将当前的运行环境, 存储到 returnEnv 中,
         将自己当前维护的堆栈当做新的运行堆栈, 然后执行存储的 businessBlock
         businessBlock 运行结束之后, 使用 __longjmp 跳转回原本的运行环境中.
         
         不过, businessBlock 的运行过程中, 如果使用了 wait, 还会造成运行环境的切换.
         */
        __start(returnEnv, stackTop, Unmanaged.passUnretained(self).toOpaque()) {
            let returnEnv_end = Unmanaged<CoroutineContext> .fromOpaque($0!).takeUnretainedValue().performBlock()
            __longjmp(returnEnv_end,.finished)
        } == .finished
    }
    
    private func performBlock() -> UnsafeMutableRawPointer {
        businessBlock?()
        businessBlock = nil
        return returnEnv
    }
    
    // MARK: - Operations
    
    internal struct SuspendData {
        // JumpBuffer 的位置.
        let jumpBufferEnv: UnsafeMutableRawPointer
        // 简单来说，SP 寄存器用于跟踪当前程序运行时的堆栈位置。
        var sp: UnsafeMutableRawPointer!
    }
    
    @inlinable internal func resume(from env: UnsafeMutableRawPointer) -> Bool {
        __save(env, returnEnv, .suspended) == .finished
    }
    
    @inlinable internal func suspend(to data: UnsafeMutablePointer<SuspendData>) {
        // 在调用 suspend 的时候, SuspendData 中记录了 JumpBuffer 的数据, 以及当前的堆栈顶端.
        __suspend(data.pointee.jumpBufferEnv,
                  &data.pointee.sp,
                  returnEnv,
                  .suspended)
    }
    
    @inlinable internal func suspend(to env: UnsafeMutableRawPointer) {
        __save(returnEnv, env, .suspended)
    }
    
    deinit {
        if haveGuardPage {
            mprotect(stack, .pageSize, PROT_READ | PROT_WRITE)
        }
        returnEnv.deallocate()
        stack.deallocate()
    }
    
}

extension Int32 {
    
    fileprivate static let suspended: Int32 = -1
    fileprivate static let finished: Int32 = 1
    
}

extension CoroutineContext.SuspendData {
    
    internal init() {
        self = .init(jumpBufferEnv: .allocate(byteCount: .environmentSize, alignment: 16),
                     sp: nil)
    }
    
}
