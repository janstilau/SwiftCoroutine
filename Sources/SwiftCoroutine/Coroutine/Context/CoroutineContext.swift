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

internal final class CoroutineContext {
    
    internal let haveGuardPage: Bool
    internal let stackSize: Int
    private let contextStack: UnsafeMutableRawPointer
    private let contextJumpBuffer: UnsafeMutableRawPointer
    internal var startTask: (() -> Void)?
    
    internal init(stackSize: Int, guardPage: Bool = true) {
        self.stackSize = stackSize
        // returnEnv 中存储的是, 寄存器的值.
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
         开启一个新的协程.
         在开启一个新的协程的时候, 是将当前 Queue 中的 JumpBuffer 环境进行了保存.
        */
        
        /*
         __assemblyStart 的流程.
         1. 将开启协程的状态, 保存到 contextJumpBuffer 中.
         2. 然后通过 __longjmp(self.performBlock(),.finished)) 来执行协程的启动 task.
         如果这个 task 中没有异步函数, 那么 finished 的就是 __assemblyStart 这个函数的返回值. 最后和 .finished 判断为 true, 代表着这个协程执行完毕了.
         如果这个 task 中有异步函数. 那么 performBlock 其实不能够顺利执行完毕的. 所以这个 __assemblyStart 还没有返回值.
         这个时候, 程序会通过下面的方法, 跳转回 contextJumpBuffer 中, __assemblyStart 的返回值是 suspended. 所以通过 start() 返回 false, 表示协程还没有结束.
         __assemblySuspend(data.pointee._jumpBuffer,
                   &data.pointee._stackTop,
                   contextJumpBuffer, .suspended)
         
         当, resume 的时候,
         */
       let coroutineResult =
        __assemblyStart(contextJumpBuffer,
               stackBottom,
               Unmanaged.passUnretained(self).toOpaque()) {
           
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
     startTask 就是这里的闭包对象.
     DispatchQueue.main.startCoroutine {
         self.movies = try self.dataManager.getPopularMovies().await()
     }
     */
    private func performBlock() -> UnsafeMutableRawPointer {
        /*
         在执行, startTask 的时候, 就可能发生了协程的切换了.
         在执行, startTask 的过程中, 有可能会进入到 suspend 的状态. 这个时候, 还是会进入到 contextJumpBuffer 存储的原有环境的.
         这个时候, __assemblyStart 的返回值, 就是 suspended
         */
        startTask?()
        startTask = nil
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
        // 这里, __assemblyResume 只所以能够返回 finished, 是 performBlock 执行到最后了, 可以返回 __longjmp 的第二个参数了.
        // finish 的条件, 就是 start 中, performBlock 执行完了才可以.
        __assemblyResume(jumpToEnv, contextJumpBuffer, .suspended) == .finished
    }
    
    /*
     进行协程的暂停, 要记录协程中的环境, 然后切换到 Queue 的 JumpBuffer 所记录的环境上.
     */
    @inlinable internal func suspend(to data: UnsafeMutablePointer<SuspendData>) {
        // data.pointee._stackTop 唯一会修改的地方. 
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
