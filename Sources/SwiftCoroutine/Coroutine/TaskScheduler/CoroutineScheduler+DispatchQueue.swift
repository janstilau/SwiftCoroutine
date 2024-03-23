
import Foundation

/*
 如果是主队列, 就有一个判断. 否则直接 dispatch.
 */
extension DispatchQueue: CoroutineScheduler {
    
    @inlinable public func scheduleTask(_ task: @escaping () -> Void) {
        if self === DispatchQueue.main {
            Thread.isMainThread ? task() : async(execute: task)
        } else {
            async(execute: task)
        }
    }
}
