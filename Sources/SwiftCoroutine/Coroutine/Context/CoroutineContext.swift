#if SWIFT_PACKAGE
import CCoroutine
#endif

#if os(Linux)
import Glibc
#else
import Darwin
#endif

/*
 有了 CoroutineContext, 其实协程和线程就没有太大的关系了.
 每一个 Coroutine 里面, 存储了调用栈的信息, 存储了 JumpBuffer.
 所以在进行 Resume 的时候, 其实是能够完全复原出自己的执行环境的.
 */
internal final class CoroutineContext {
    
    // 对于一个 SharedCoroutioneQueue 来说, 他们是共用一个 CoroutineContext 对象的
    internal let stackSize: Int
    private let stack: UnsafeMutableRawPointer
    private let returnEnv: UnsafeMutableRawPointer // JumpBuffer 的地址.
    internal var coroutineStartFunc: (() -> Void)? // 整个协程, 其实就是一个任务块而已. 当协程完毕之后, 其实就是协程关闭的时机了. 
    
    internal init(stackSize: Int) {
        self.stackSize = stackSize
        stack = .allocate(byteCount: stackSize + .pageSize, alignment: .pageSize)
        
        returnEnv = .allocate(byteCount: .environmentSize, alignment: 16)
        mprotect(stack, .pageSize, PROT_READ)
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
         如果 startRoutineBusinessBlock 执行过程中, 没有发生过协程的切换, 那么
         returnEnv_end 的值, 就和 __start(returnEnv) 中确定的值是一致的. 在这种情况下, __start 的返回值就是 .finished
         如果发生过 wait 操作, 那么 __start 的返回值就不是 .finished.
         
         这个时候, 就需要根据 Routine 的 State 进行调度了.
         */
        __start(returnEnv, stackTop, Unmanaged.passUnretained(self).toOpaque()) {
            let returnEnv_end = Unmanaged<CoroutineContext> .fromOpaque($0!).takeUnretainedValue().startRoutineBusinessBlock()
            // 在 businessBlock 的执行过程中, returnEnv 的值其实会多次变化的.
            // 所以需要在 businessBlock() 执行结束之后, 返回当前的最新值.
            // 只有在这里, .finished 的值才会真正用作赋值操作.
            __longjmp(returnEnv_end,.finished)
        } == .finished
    }
    
    private func startRoutineBusinessBlock() -> UnsafeMutableRawPointer {
        coroutineStartFunc?()
        coroutineStartFunc = nil
        return returnEnv
    }
    
    // MARK: - Operations
    
    internal struct SuspendData {
        // JumpBuffer 的位置. 里面存储了运行环境. sp 则存储了栈的 end 位置. 
        let jumpBufferEnv: UnsafeMutableRawPointer
        // 简单来说，SP 寄存器用于跟踪当前程序运行时的堆栈位置。
        var sp: UnsafeMutableRawPointer!
    }
    
    @inlinable internal func suspend(to data: UnsafeMutablePointer<SuspendData>) {
        // 在调用 suspend 的时候, SuspendData 中记录了 JumpBuffer 的数据, 以及当前的堆栈顶端.
        // __suspend 函数, 在进行当前协程的暂停时候, 会恢复到原来的记录的 JumpBuffer 的运行状态中.
        __suspend(data.pointee.jumpBufferEnv,
                  &data.pointee.sp,
                  
                  returnEnv,
                  .suspended)
    }
    
    @inlinable internal func resume(from resumeEnv: UnsafeMutableRawPointer) -> Bool {
        __resumeTo(resumeEnv, returnEnv, .suspended) == .finished
    }
    
    deinit {
        mprotect(stack, .pageSize, PROT_READ | PROT_WRITE)
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
