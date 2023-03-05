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
int __start(void* jumpBuffer, const void* stack, const void* param, const void (*block)(const void*)) {
    int n = _setjmp(jumpBuffer);
    if (n) return n;
#if defined(__x86_64__)
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

void __suspend(void* jumpBuffer, void** sp, void* retJumpBuffer, int retVal) {
    if (_setjmp(jumpBuffer)) {
        return;
    }
    // 这是一个比较 tricky 的点, 使用下一个指针位置, 来存储了当前运行到的堆栈位置信息. 
    char x;
    *sp = (void*)&x;
    _longjmp(retJumpBuffer, retVal);
}

int _replaceTo(void* resumeJumpBuffer, void* saveJumpBuffer, int retVal) {
    int n = _setjmp(saveJumpBuffer);
    if (n) return n;
    // 这里居然没有报错, 不用返回 Int 值.
    _longjmp(resumeJumpBuffer, retVal);
}

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
