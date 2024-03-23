#if canImport(Combine)
import Combine

@available(OSX 10.15, iOS 13.0, *)
extension CoChannel {

    // MARK: - publisher

    /// Returns a publisher that emits elements of this `CoChannel`.
    @inlinable public func publisher() -> AnyPublisher<Element, CoChannelError> {
        channel.publisher()
    }

}

@available(OSX 10.15, iOS 13.0, *)
extension CoChannel.Receiver {

    // MARK: - publisher

    /// Returns a publisher that emits elements of this `Receiver`.
    public func publisher() -> AnyPublisher<Element, CoChannelError> {
        CoChannelPublisher(receiver: self).eraseToAnyPublisher()
    }

}

@available(OSX 10.15, iOS 13.0, *)
extension Publisher {
    
    /// Attaches `CoChannel.Receiver` as a subscriber and returns it.
    public func subscribeCoChannel(buffer: CoChannel<Output>.BufferType = .unlimited) -> CoChannel<Output>.Receiver {
        let channel = CoChannel<Output>(bufferType: buffer)
        let cancellable = sink(receiveCompletion: { _ in channel.close() },
                               receiveValue: { channel.offer($0) })
        channel.whenCanceled(cancellable.cancel)
        return channel.receiver
    }
    
}
#endif
