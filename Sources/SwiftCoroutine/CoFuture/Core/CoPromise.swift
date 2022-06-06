/// A promise to provide a result later.
///
/// `CoPromise` is a subclass of `CoFuture` that allows to deliver the result.
/// You can set the result to `CoPromise` only once, other attempts will be ignored.

public final class CoPromise<Value>: CoFuture<Value> {}


// Promise 是一个通用的概念, CoPromise 就是利用这个概念, 给 Future 提供了更加友好的接口. 
extension CoPromise {
    
    public convenience init() {
        self.init(_result: nil)
    }
    
    @inlinable public func complete<E: Error>(with result: Result<Value, E>) {
        switch result {
        case .success(let value): setResult(.success(value))
        case .failure(let error): setResult(.failure(error))
        }
    }
    
    @inlinable public func success(_ value: Value) {
        setResult(.success(value))
    }
    
    @inlinable public func fail(_ error: Error) {
        setResult(.failure(error))
    }
    
    @inlinable public func complete(with future: CoFuture<Value>) {
        // 一个联动的机制.
        // 被关联的 Future 对象的 Result 回调中, 是将结果, 设置给当前 Future 对象的 Result.
        future.addCallback(setResult)
    }
}
