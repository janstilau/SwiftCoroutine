//
//  Constants.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 10.03.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

#if os(Linux)
import Glibc

extension Int {
    
    internal static let pageSize = sysconf(Int32(_SC_PAGESIZE))
    internal static let processorsNumber = sysconf(Int32(_SC_NPROCESSORS_ONLN))
    
}

#else
import Darwin

// 这种, 专门为类型添加 static 常量的写法, 非常常见.

extension Int {
    
     
    /*
     pageSize：这是系统的页面大小，单位是字节。页面是操作系统用于管理内存的基本单位。在大多数系统中，页面大小通常是 4KB 或者 8KB。sysconf(_SC_PAGESIZE) 是一个系统调用，用于获取页面大小。

     processorsNumber：这是系统中在线处理器（即可用的 CPU 核心）的数量。sysconf(_SC_NPROCESSORS_ONLN) 是一个系统调用，用于获取在线处理器的数量。
     */
    internal static let pageSize = sysconf(_SC_PAGESIZE)
    internal static let processorsNumber = sysconf(_SC_NPROCESSORS_ONLN)
    
}

#endif

extension Int {
    
    internal static let environmentSize = MemoryLayout<jmp_buf>.size
    
}
