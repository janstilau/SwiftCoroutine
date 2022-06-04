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
    private let jumpBufferAddress: UnsafeMutableRawPointer
    internal var startTask: (() -> Void)?
    
    internal init(stackSize: Int, guardPage: Bool = true) {
        self.stackSize = stackSize
        // returnEnv 中存储的是, 寄存器的值.
        jumpBufferAddress = .allocate(byteCount: .environmentSize, alignment: 16)
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
       __assemblyStart(jumpBufferAddress,
               stackBottom,
               Unmanaged.passUnretained(self).toOpaque()) {
           __longjmp(
            // $0 就是 self 了.
            Unmanaged<CoroutineContext>
               .fromOpaque($0!)
               .takeUnretainedValue()
               .performBlock(),
            
                .finished)
       } == .finished
    }
    
    private func performBlock() -> UnsafeMutableRawPointer {
        startTask?()
        startTask = nil
        return jumpBufferAddress
    }
    
    // MARK: - Operations
    
    internal struct SuspendData {
        let _jumpBuffer: UnsafeMutableRawPointer
        var _stackTop: UnsafeMutableRawPointer!
    }
    
    // 真正的进行协程的恢复.
    @inlinable internal func resume(from env: UnsafeMutableRawPointer) -> Bool {
        __assemblySave(env, jumpBufferAddress, .suspended) == .finished
    }
    
    @inlinable internal func suspend(to data: UnsafeMutablePointer<SuspendData>) {
        // data.pointee._stackTop 唯一会修改的地方. 
        __assemblySuspend(data.pointee._jumpBuffer,
                  &data.pointee._stackTop,
                  jumpBufferAddress, .suspended)
    }
    
    @inlinable internal func suspend(to env: UnsafeMutableRawPointer) {
        __assemblySave(jumpBufferAddress, env, .suspended)
    }
    
    deinit {
        if haveGuardPage {
            mprotect(contextStack, .pageSize, PROT_READ | PROT_WRITE)
        }
        jumpBufferAddress.deallocate()
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
