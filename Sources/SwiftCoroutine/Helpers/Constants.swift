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

extension Int {
    
    //系统页大小 
    internal static let pageSize = sysconf(_SC_PAGESIZE)
    // sysconf(_SC_NPROCESSORS_ONLN)的返回值真正的代表了系统 当前可用的核数.
    internal static let processorsNumber = sysconf(_SC_NPROCESSORS_ONLN)
    
}

#endif

extension Int {
    
    internal static let environmentSize = MemoryLayout<jmp_buf>.size
    
}
