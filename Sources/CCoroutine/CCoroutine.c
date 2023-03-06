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

// MARK: - context


/*
 _setjmp, _longjmp
 
 `_setjmp` 函数是一个用于跳转的函数，它可以把程序的执行控制转移到一个先前通过 `_setjmp` 函数保存的位置。
 在 C 语言中，通过 `_setjmp` 函数保存的信息包括当前堆栈帧、寄存器信息以及执行控制的程序计数器等信息。

 具体来说，当 `_setjmp` 函数被调用时，它会保存当前的 CPU 寄存器、栈指针以及程序计数器等寄存器信息，这些信息被保存在一个称为 `jmp_buf` 的缓冲区中。同时，`_setjmp` 函数还会返回一个非零值，用于标识该缓冲区的状态。

 当程序需要跳转到之前保存的位置时，可以通过调用 `longjmp` 函数并传入相应的 `jmp_buf` 缓冲区来实现。
 `longjmp` 函数会使用缓冲区中保存的信息来恢复 CPU 寄存器、栈指针以及程序计数器等寄存器的值，以实现程序跳转的功能。

 总之，`_setjmp` 函数对存储 CPU 寄存器、栈指针以及程序计数器等寄存器信息，用于实现程序跳转的功能。
 
 CPU 寄存器 状态.
 栈指针 状态. 不过这里面的栈, 会有原本的线程的调用栈, 也会有每个协程自己的调用栈. 协程中非常重要的一点, 就是将调用栈进行了分别的存储.
 PC 程序计数器里面则是存储程序运行的位置, 通过该状态, 才能继续原本的运行指令.
 
 通常用于信号处理程序。调用 _setjmp() 会使其在 env 中保存当前堆栈环境。随后调用 _longjmp() 可以恢复之前保存的堆栈环境。
 简单来说，_setjmp() 函数用于保存当前的程序状态，而 _longjmp() 函数则可以将程序状态恢复到之前由 _setjmp() 保存的状态。
 
 #include <stdio.h>
 #include <setjmp.h>

 static jmp_buf buf;

 void second(void) {
     printf("second\n");         // 打印
     longjmp(buf,1);             // 跳回setjmp的调用处 - 使得setjmp返回值为1
 }

 void first(void) {
     second();
     printf("first\n");          // 不会执行到这里
 }

 int main() {
     if (!setjmp(buf))
         first();                // 进入first函数
     else                        // 当longjmp跳转回，执行这里
         printf("main\n");       // 打印

     return 0;
 }
 
 setjmp() 函数的返回值取决于它是如何被调用的。
 如果是直接调用 setjmp()，则返回值为 0。
 但是，如果是通过调用 longjmp() 函数来恢复程序状态时，setjmp() 的返回值将为 longjmp() 函数的第二个参数。
 */
/*
 stack, param, block 都是传递给这个内联汇编的参数。
 __asm__ (
     "mov sp, %0\n" // 将 stack 的值移动到寄存器 sp 中，设置栈顶为 stack 的值
     "mov x0, %1\n" // 将 param 的值移动到寄存器 x0 中，作为函数调用的第一个参数
     "blr %2"        // 执行寄存器 block 中地址指向的函数
     :: "r"(stack), "r"(param), "r"(block)
 );
 */
int __start(void* jumpBuffer, const void* routineStack, const void* param, const void (*routineStart)(const void*)) {
    int n = _setjmp(jumpBuffer);
    if (n) {
        // n 不为 0, 则是跳转回来的操作.
        return n;
    }
    
#if defined(__x86_64__)
    __asm__ ("movq %0, %%rsp" :: "g"(routineStack));
    routineStart(param);
#elif defined(__arm64__)
    __asm__ (
             "mov sp, %0\n"
             "mov x0, %1\n"
             "blr %2" :: "r"(stack), "r"(param), "r"(block));
#endif
    // 这里的 return 没有意义, 只是为了编译正确.
    // 上面的 __asm__ 其实已经完成了 _longjmp 的作用.
    return 0;
}

void __suspend(void* jumpBuffer, void** sp, void* retJumpBuffer, int retVal) {
    int n = _setjmp(jumpBuffer);
    if (n) {
        // n 不为 0, 则是跳转回来的操作.
        return;
    }
    
    // 这是一个比较 tricky 的点, 使用下一个指针位置, 来存储了当前运行到的堆栈位置信息.
    char x;
    *sp = (void*)&x;
    _longjmp(retJumpBuffer, retVal);
}

int __resumeTo(void* resumeJumpBuffer, void* saveJumpBuffer, int retVal) {
    int n = _setjmp(saveJumpBuffer);
    if (n) {
        // n 不为 0, 则是跳转回来的操作.
        return n;
    }
    
    // 使用 _longjmp 不需要返回值了.
    _longjmp(resumeJumpBuffer, retVal);
}

/*
 __start
 __suspend
 __replaceTo
 
 这三个函数中, 都进行了指令的跳转.
 当这几个函数返回的时候, 其实是指令跳转回来后, _longjmp 的中带过来的返回值.
 */




void __longjmp(void* returnJumpBuffer, int retVal) {
    _longjmp(returnJumpBuffer, retVal);
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

/*
 atomic_compare_exchange_strong 是 C++ 中的一个原子操作函数，它用于比较并交换两个值。它有三个参数：expected，desired 和 memory_order。如果当前的值与 expected 相等，则将其替换为 desired 值。否则，将当前值复制到 expected 中1。

 这个函数的行为就像下面的代码是以原子方式执行的：

 if (memcmp(obj, expected, sizeof *obj) == 0)
     memcpy(obj, &desired, sizeof *obj);
 else
     memcpy(expected, obj, sizeof *obj);
 
 atomic_compare_exchange_strong 函数的返回值是一个布尔值，表示操作是否成功。

 如果当前值与 expected 相等，则将其替换为 desired 值并返回 true。否则，将当前值复制到 expected 中并返回 false。
 
 说实话, 这个函数有问题. expected 还能当输出参数, 让这个参数变得复杂. 
 */
int __atomicCompareExchange(_Atomic long* value, long* expected, long desired) {
    return atomic_compare_exchange_strong(value, expected, desired);
}
