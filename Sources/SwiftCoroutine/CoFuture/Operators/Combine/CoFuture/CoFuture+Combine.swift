#if canImport(Combine)
import Combine

@available(OSX 10.15, iOS 13.0, *)
extension CoFuture {
    
    // MARK: - publisher
    
    /// Returns a publisher that emits result of this `CoFuture`.
    public func publisher() -> AnyPublisher<Value, Error> {
        CoFuturePublisher(future: self).eraseToAnyPublisher()
    }
    
}

@available(OSX 10.15, iOS 13.0, *)
extension Publisher {
    // 从一个 Publisher, 变为一个 Future 的对象.
    // 其实就是增加了一个 Sink.
    // 注意, 这里 future 的 cancel, 也会影响到 Punlisher 的整个链条. 
    /// Attaches `CoFuture` as a subscriber and returns it. `CoFuture` will receive result only once.
    public func subscribeCoFuture() -> CoFuture<Output> {
        let promise = CoPromise<Output>()
        let cancellable = sink(receiveCompletion: {
            if case .failure(let error) = $0 { promise.fail(error) }
        }, receiveValue: promise.success)
        promise.whenCanceled(cancellable.cancel)
        return promise
    }
    
}
#endif
