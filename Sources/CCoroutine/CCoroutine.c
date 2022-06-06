//
//  CCoroutine.c
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 22.11.2019.
//  Copyright © 2019 Alex Belozierov. All rights reserved.
//

#include "CCoroutine.h"
#import <stdatomic.h>
#include <setjmp.h>

/*
 https://blog.csdn.net/qq_41252394/article/details/109388037
 */
// MARK: - context

// 在开始的时候, 是没有 JumpBuffer 用来跳转的.
// 代码按照代码编写顺序继续执行, 在这里, 有着主动地函数调用栈的覆盖的动作.
int __assemblyStart(void* jumpBufferAddress,
            const void* stack,
            const void* param,
            const void (*block)(const void*)) {
    // 将, 当前的运行状态, 存放到了 jumpBufferAddress 中.
    int n = _setjmp(jumpBufferAddress);
    if (n) return n;
    
    // __asm 关键字用于调用内联汇编程序，并且可在 C 或 C++ 语句合法时出现。
    #if defined(__x86_64__)
    // rsp 是存放的栈顶地址, 可以看到, 协程, 是将自己内存中 alloc 的一段空间, 当做了自己的栈顶.
    // 这样, _setjmp 的时候, 这个自定义的栈顶, 其实也就被存储到了 JumpBuffer 中了.
    __asm__ ("movq %0, %%rsp" :: "g"(stack));
    block(param);
    
    
    #elif defined(__arm64__)
    __asm__ (
    "mov sp, %0\n"
    "mov x0, %1\n"
    "blr %2" :: "r"(stack), "r"(param), "r"(block));
    #endif
    return 0;
}


// Wait 操作的实现.
void __assemblySuspend(void* toSaveEnv, void** stackTopAddress, void* jumpToEnv, int retVal) {
    if (_setjmp(toSaveEnv)) return;
    // 非常狗的一个做法, 使用一个临时变量, 来衡量出现在使用了多少栈空间. 
    char x; *stackTopAddress = (void*)&x;
    // 切换回原有的环境
    _longjmp(jumpToEnv, retVal);
}

// Resume 操作的实现.
int __assemblySave(void* jumpToEnv, void* toSavedEnv, int retVal) {
    int n = _setjmp(toSavedEnv);
    if (n) return n;
    _longjmp(jumpToEnv, retVal);
}

void __longjmp(void* jumpToEnv, int retVal) {
    _longjmp(jumpToEnv, retVal);
}

// MARK: - atomic

long __atomicExchange(_Atomic long* value, long desired) {
    return atomic_exchange(value, desired);
}

void __atomicStore(_Atomic long* value, long desired) {
    atomic_store(value, desired);
}

long __atomicFetchAdd(_Atomic long* value, long operand) {
    return atomic_fetch_add(value, operand);
}

int __atomicCompareExchange(_Atomic long* value, long* expected, long desired) {
    return atomic_compare_exchange_strong(value, expected, desired);
}
