//
//  CoChannel+Combine.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 11.06.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

#if canImport(Combine)
import Combine

@available(OSX 10.15, iOS 13.0, *)
extension CoChannel {

    // MARK: - publisher

    /// Returns a publisher that emits elements of this `CoChannel`.
    @inlinable public func publisher() -> AnyPublisher<Element, CoChannelError> {
        _innerChannel.publisher()
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
        let _innerChannel = CoChannel<Output>(bufferType: buffer)
        let cancellable = sink(receiveCompletion: { _ in _innerChannel.close() },
                               receiveValue: { _innerChannel.offer($0) })
        _innerChannel.whenCanceled(cancellable.cancel)
        return _innerChannel.receiver
    }
    
}
#endif
