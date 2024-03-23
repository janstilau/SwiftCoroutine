#include "CCoroutine.h"
#import <stdatomic.h>
#include <setjmp.h>

// MARK: - context

/*
 在 Swift 中，协程的实现通常依赖于底层的系统调用和汇编语言。这些函数的主要目的是保存和恢复协程的执行环境，包括寄存器的值和栈指针。

 __start：这个函数用于启动一个新的协程。它首先使用 _setjmp 函数保存当前的执行环境（包括寄存器的值和栈指针）。然后，它使用汇编代码将栈指针设置为新的协程的栈，然后调用 block 函数开始执行新的协程。

 __suspend：这个函数用于暂停当前的协程。它首先使用 _setjmp 函数保存当前的执行环境，然后将栈指针保存在 sp 参数中，最后使用 _longjmp 函数恢复之前保存的执行环境，从而返回到上一个协程。

 __save：这个函数用于保存当前的协程的执行环境。它使用 _setjmp 函数保存当前的执行环境，然后使用 _longjmp 函数恢复之前保存的执行环境。

 __longjmp：这个函数用于恢复之前保存的协程的执行环境。它使用 _longjmp 函数恢复之前保存的执行环境。

 这些函数的实现使用了 _setjmp 和 _longjmp 这两个函数，这两个函数是用于实现非本地跳转的。_setjmp 函数用于保存当前的执行环境，_longjmp 函数用于恢复之前保存的执行环境。这两个函数通常用于实现异常处理和协程。

 需要注意的是，这些函数的实现使用了汇编代码，这意味着它们是平台相关的。在这个例子中，这些函数的实现是针对 x86_64 和 ARM64 这两个平台的。
 */

/*
 _setjmp 和 _longjmp 是 C 语言中用于实现非本地跳转的两个函数。非本地跳转是一种可以从一个函数跳转到另一个函数的控制流机制，这种跳转不受函数调用和返回的限制。

 _setjmp 函数用于保存当前的执行环境，包括寄存器的值、栈指针和程序计数器等。这些信息被保存在一个 jmp_buf 类型的变量中。_setjmp 函数在首次调用时返回 0，如果后续由 _longjmp 跳转回来，_setjmp 会返回一个非零值。

 _longjmp 函数用于恢复之前由 _setjmp 保存的执行环境，并跳转到 _setjmp 所在的位置继续执行。_longjmp 接受两个参数，第一个参数是之前 _setjmp 保存的 jmp_buf 变量，第二个参数是要传递给 _setjmp 的返回值（不能为0，如果为0则会被转换为1）。

 这两个函数通常用于实现异常处理和协程。在异常处理中，可以使用 _setjmp 在可能出现异常的地方保存执行环境，然后在异常处理代码中使用 _longjmp 跳转回来。在协程中，可以使用 _setjmp 和 _longjmp 在多个协程之间切换执行环境。

 需要注意的是，_setjmp 和 _longjmp 只保存和恢复执行环境，不包括堆栈中的数据。因此，在跳转之后，原来函数中的局部变量可能会丢失或被破坏。
 */


/*
 保存, 当前的环境.
 然后 routineStack 作为新的函数栈.
 routineContext 作为函数的参数.
 调用 block 这个函数. 
 */
int __start(void* ret, const void* routineStack, const void* routineContext, const void (*block)(const void*)) {
    int n = _setjmp(ret);
    // 如果 n 不为 0, 就是从 longjump 跳转回来的.
    // 如果是 0, 那么就是在启动协程.
    if (n) return n;
#if defined(__x86_64__)
    __asm__ ("movq %0, %%rsp" :: "g"(stack));
    block(param);
    
/*
 "mov sp, %0\n"：这行代码将 stack 的值（即新的协程的栈顶地址）移动到栈指针 sp 中。这样，新的协程就可以在自己的栈空间中运行了。

 "mov x0, %1\n"：这行代码将 param 的值移动到寄存器 x0 中。在 ARM64 架构中，x0 寄存器通常用于传递函数的第一个参数。

 "blr %2"：这行代码通过链接寄存器 lr 跳转到 block 指向的函数，并在返回时跳回 blr 指令之后的代码。这样，新的协程就开始执行了。

 总的来说，这段代码的作用是设置新的协程的栈空间，并开始执行新的协程。
 */
#elif defined(__arm64__)
    __asm__ (
             "mov sp, %0\n"
             "mov x0, %1\n"
             "blr %2" :: "r"(routineStack), "r"(routineContext), "r"(block));
#endif
    return 0;
}

void __suspend(void* saveEnv, void** sp, void* gotoEnv, int retVal) {
    if (_setjmp(saveEnv)) return;
    char x; *sp = (void*)&x;
    // 这里, 保存完数据之后, 其实是跳转回原来的 retJumpBuffer 记录的位置了.
    _longjmp(gotoEnv, retVal);
}

int __save(void* gotoEnv, void* saveEnv, int retVal) {
    int n = _setjmp(saveEnv);
    if (n) return n;
    _longjmp(gotoEnv, retVal);
}

void __longjmp(void* env, int retVal) {
    _longjmp(env, retVal);
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
