//
//  CoroutineContext.swift
//  SwiftCoroutine iOS
//
//  Created by Alex Belozierov on 08.12.2019.
//  Copyright © 2019 Alex Belozierov. All rights reserved.
//

#if SWIFT_PACKAGE
import CCoroutine
#endif

#if os(Linux)
import Glibc
#else
import Darwin
#endif
/*
 CoroutineContext 会在一个 CoroutioneQueue 中存在.
 也就是说, CoroutioneQueue 所管理的所有协程, 都是重用了同样的一个调用栈.
 每个协程被调度的时候, 将自己记录的调用栈信息, 覆盖到 contextStack 上面去.
 */
internal final class CoroutineContext {
    
    internal let haveGuardPage: Bool
    internal let stackSize: Int
    private let contextStack: UnsafeMutableRawPointer
    private let contextJumpBuffer: UnsafeMutableRawPointer
    internal var coroutineMainTask: (() -> Void)?
    
    internal init(stackSize: Int, guardPage: Bool = true) {
        self.stackSize = stackSize
        contextJumpBuffer = .allocate(byteCount: .environmentSize, alignment: 16)
        haveGuardPage = guardPage
        if guardPage {
            contextStack = .allocate(byteCount: stackSize + .pageSize, alignment: .pageSize)
            mprotect(contextStack, .pageSize, PROT_READ)
        } else {
            contextStack = .allocate(byteCount: stackSize, alignment: .pageSize)
        }
    }
    
    // 栈空间, 是从高到低的.
    // 所以加过去, 高的地方是栈底空间.
    @inlinable internal var stackBottom: UnsafeMutableRawPointer {
        .init(contextStack + stackSize)
    }
    
    // MARK: - Start
    
    @inlinable internal func start() -> Bool {
        /*
         这里很绕.
         __assemblyStart 中记录了当前的运行状态, 然后在里面, 调用了 __longjmp, __longjmp 中调用了协程的主任务.
         然后协程的启动任务如果 wait, 会导致 __assemblyStart 返回, -1, 而这个时候, 协程的启动任务还没有运行结束, 这是因为, 协程的主任务, 是运行在协程环境里面.
         当协程的主任务主任务执行完毕后, __longjmp 可以继续执行, 切换会线程主环境中. 这就是协程执行完毕之后, 可以自动切换到正常环境的原因所在.
         */
        let coroutineResult =
        __assemblyStart(contextJumpBuffer,
                        stackBottom,
                        Unmanaged.passUnretained(self).toOpaque()) {
            // 在协程环境中, 执行 performBlock
            // 执行结束之后, 跳转回线程的主环境, 这也就是, 为什么协程任务执行完毕之后, 可以正常回复到原有环境的原因.
            __longjmp(
                Unmanaged<CoroutineContext>
                    .fromOpaque($0!)
                    .takeUnretainedValue()
                    .performBlock(),
                
                    .finished)
        }
        
        return coroutineResult == .finished
    }
    
    /*
     mainTask 就是 self.movies = try self.dataManager.getPopularMovies().await().
     DispatchQueue.main.startCoroutine {
     self.movies = try self.dataManager.getPopularMovies().await()
     }
     
     startCoroutine 是先创建好协程的执行环境, 主要是函数调用栈, 然后才执行的协程主任务.
     */
    private func performBlock() -> UnsafeMutableRawPointer {
        /*
         在执行, startTask 的时候, 就可能发生了协程的切换了.
         在执行, startTask 的过程中, 有可能会进入到 suspend 的状态. 这个时候, 还是会进入到 contextJumpBuffer 存储的原有环境的.
         这个时候, __assemblyStart 的返回值, 就是 suspended
         */
        coroutineMainTask?()
        coroutineMainTask = nil
        return contextJumpBuffer
    }
    
    // MARK: - Operations
    
    internal struct SuspendData {
        let _jumpBuffer: UnsafeMutableRawPointer
        var _stackTop: UnsafeMutableRawPointer!
    }
    
    /*
     进行协程的恢复, 要记录 Queue 的 JumpBuffer, 然后切换到协程的环境里面.
     */
    @inlinable internal func resume(from jumpToEnv: UnsafeMutableRawPointer) -> Bool {
        /*
         __longjmp(
         Unmanaged<CoroutineContext>
         .fromOpaque($0!)
         .takeUnretainedValue()
         .performBlock(),
         
         .finished)
         */
        
        /*
         __assemblyResume 是跳转到协程环境里面, 但是当他返回的时候, 是在线程主环境中返回的.
         当他能够返回的时候:
         1. 跳转到的协程执行完毕了, 这个时候返回 .finished
         2. 跳转到的协程被暂停了, 这个时候返回 .suspended
         对于协程的切换, 一定是线程主环境, 切换到协程, 然后协程切换到主环境. 不可能是协程直接切换到协程.

         __assemblyResume 的返回值, 是 longjmp 到 contextJumpBuffer 的时候给的第二个参数.
         如果是协程执行完毕了, 是在 __start 中的 longjmp 中, 传递过来的 .finished.
         如果是协程暂停了, 是在 __assemblySuspend 中的 longjmp 中, 传递过来的 .suspended
         */
        let resumeResult = __assemblyResume(jumpToEnv, contextJumpBuffer, .suspended)
        return  resumeResult == .finished
    }
    
    /*
     进行协程的暂停, 要记录协程中的环境, 然后切换到 Queue 的 JumpBuffer 所记录的环境上.
     */
    @inlinable internal func suspend(to data: UnsafeMutablePointer<SuspendData>) {
        // data.pointee._stackTop 唯一会修改的地方. 在里面, 用特殊的技巧, 记录了当前的调用栈栈顶的位置.
        __assemblySuspend(data.pointee._jumpBuffer,
                          &data.pointee._stackTop,
                          contextJumpBuffer, .suspended)
    }
    
    deinit {
        if haveGuardPage {
            /*
             mprotect()函数把自start开始的、长度为len的内存区的保护属性修改为prot指定的值。
             prot可以取以下几个值，并且可以用“|”将几个属性合起来使用：
             1）PROT_READ：表示内存段内的内容可写；
             2）PROT_WRITE：表示内存段内的内容可读；
             3）PROT_EXEC：表示内存段中的内容可执行；
             4）PROT_NONE：表示内存段中的内容根本没法访问。
             */
            mprotect(contextStack, .pageSize, PROT_READ | PROT_WRITE)
        }
        contextJumpBuffer.deallocate()
        contextStack.deallocate()
    }
}

extension Int32 {
    
    fileprivate static let suspended: Int32 = -1
    fileprivate static let finished: Int32 = 1
    
}

extension CoroutineContext.SuspendData {
    internal init() {
        self = .init(_jumpBuffer: .allocate(byteCount: .environmentSize, alignment: 16), _stackTop: nil)
    }
}
