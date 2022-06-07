
// 父类, 啥都不干. 
@usableFromInline internal class _Channel<T>: CoChannel<T>.Receiver {
    
    private var completeBlocks = CallbackStack<CoChannelError?>()
    
    // MARK: - send
    
    @usableFromInline internal func awaitSend(_ element: T) throws {}
    @usableFromInline internal func sendFuture(_ future: CoFuture<T>) {}
    @usableFromInline internal func offer(_ element: T) -> Bool { false }
    
    // MARK: - close
    
    @usableFromInline internal func close() -> Bool { false }
    
    // MARK: - complete
    
    internal final override func whenFinished(_ callback: @escaping (CoChannelError?) -> Void) {
        if !completeBlocks.append(callback) { callback(channelError) }
    }
    
    internal final func finish() {
        completeBlocks.close()?.finish(with: channelError)
    }
    
    private var channelError: CoChannelError? {
        if isClosed { return .closed }
        if isCanceled { return .canceled }
        return nil
    }
    
    deinit {
        finish()
    }
    
}
