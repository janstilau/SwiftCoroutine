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

/*
 setjmp/longjmp的典型用途是异常处理机制的实现：利用longjmp恢复程序或线程的状态，甚至可以跳过栈中多层的函数调用。
 
 setjmp
 建立本地的jmp_buf缓冲区并且初始化，用于将来跳转回此处。这个子程序[1] 保存程序的调用环境于env参数所指的缓冲区，env将被longjmp使用。如果是从setjmp直接调用返回，setjmp返回值为0。如果是从longjmp恢复的程序调用环境返回，setjmp返回非零值。
 setjmp 的返回值, 是一个非常重要的标志. 一般来说, setjmp 后面, 就是跳转逻辑了. 所以, 需要根据返回值来判断, 这是通过 longjmp 跳转回来的. 不然, 代码就永远在这循环下去了.
 
 
 _longjmp
 恢复env所指的缓冲区中的程序调用环境上下文，env所指缓冲区的内容是由setjmp子程序调用所保存。value的值从longjmp传递给setjmp。longjmp完成后，程序从对应的setjmp调用处继续执行，如同setjmp调用刚刚完成。如果value传递给longjmp为0，setjmp的返回值为1；否则，setjmp的返回值为value。
 
 如果setjmp所在的函数已经调用返回了，那么longjmp使用该处setjmp所填写的对应jmp_buf缓冲区将不再有效。这是因为longjmp所要返回的"栈帧"(stack frame)已经不再存在了，程序返回到一个不再存在的执行点，很可能覆盖或者弄坏程序栈.
 */

/*
 int n = _setjmp(contextJumpBuffer); 调用后. return n 之后的代码.
 这部分, 既不属于原有线程, 也不属于新创建出来的协程. 就是一个切换的操作.
 在 __assemblyStart 中, 由于没有一个数据结构存储协程环境, 所以主动调用了协程的启动任务, 相当于是主动进入到了协程环境.
 而协程执行完毕之后, 是主动使用 __longjmp 返回到了主线程环境.
 所以在 __assemblyStart 中, 是有着两次的环境切换的.
 
 而 suspend, resume 中, 则是保存 A 环境, 跳转到 B 环境.
 */
int __assemblyStart(void* contextJumpBuffer,
                    const void* stack,
                    const void* param,
                    const void (*block)(const void*)) {
    // 将, 当前的运行状态, 存放到了 jumpBufferAddress 中.
    int n = _setjmp(contextJumpBuffer);
    if (n) {
        // 如果, 协程的启动任务中, 没有 wait 操作, 那么整个协程任务会运行完, 这里会返回 .finished(1). __assemblyStart 的调用也就结束了.
        // 如果, 协程的启动任务中, 有 wait 操作, 这里会返回 .suspended(-1). __assemblyStart 的调用也就结束了.
        return n;
    }
    
    
    
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
void __assemblySuspend(void* coroutineJumpBuffer, void** stackTopAddress, void* contextJumpBuffer, int retVal) {
    // 当, Coroution Resume 的时候, 这里会被触发.
    // 这里统一都是会传递 .suspended, -1
    int n = _setjmp(coroutineJumpBuffer);
    if (n) {
        /*
         suspend 并不需要根据返回值来判断, 协程是否已经结束了. 这是必然的, suspend 被调用, 就是协程在等待耗时任务完成, 然后执行后面的逻辑.
         
         let (data, _, _) = try Coroutine.await { callback in
         URLSession.shared.dataTask(with: self.imageURL, completionHandler: callback).resume()
         }
         guard let image = UIImage(data: data!) else { return }
         Coroutine.await 必须在一个协程环境中运行, 它会停滞当前的协程流程, 直到 URLSession.shared.dataTask 的回调被调用.
         所以, Coroutine.await 的执行结果, 就是协程的代码, 在 int n = _setjmp(coroutineJumpBuffer); 这里就停止了, 直到在 __assemblyResume 中协程恢复.
         在协程的调用栈中, 就是 int n = _setjmp(coroutineJumpBuffer); return n. 应该是这样的一个逻辑. 是可以串联到一起的.
         */
        
        return;
    }
    
    // 使用了这种诡异的方式, 记录了当前的调用栈的栈顶地址.
    char x; *stackTopAddress = (void*)&x;
    // 切回到了线程原有的环境. 从这里可以看出, 一定是 协程 -> 线程主逻辑 -> 协程. 不会存在协程切协程.
    _longjmp(contextJumpBuffer, retVal);
}

// __assemblyResume 的返回值, 是当程序, 切回到 contextJumpBuffer 的时候. 
int __assemblyResume(void* cororoutineJumpBuffer, void* contextJumpBuffer, int retVal) {
    // 当, 协程有一次被 Suspend 的时候, 这里会被触发, .suspended, -1
    // 当, start 函数的 task 完成之后, 这里会被触发, .finished, 1, 所以 resume 会有返回 .finished 的情况存在.
    // 当, _longjmp(contextJumpBuffer) 的时候, 会跳转到, 最近一次 _setjmp(contextJumpBuffer) 的地方.
    int n = _setjmp(contextJumpBuffer);
    if (n) {
        return n;
    }
    
    // 执行到这里, 这个函数算作是没有返回.
    // 只有再次跳转到 toSavedEnv 的时候, 才能算作是这个函数有了返回值.
    _longjmp(cororoutineJumpBuffer, retVal);
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
