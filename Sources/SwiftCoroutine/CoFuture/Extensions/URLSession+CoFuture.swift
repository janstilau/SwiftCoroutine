//
//  URLSession+CoFuture.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 14.03.2020.
//  Copyright © 2020 Alex Belozierov. All rights reserved.
//

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Foundation

extension URLSession {
    
    public typealias DataResponse = (data: Data, response: URLResponse)
    
    /// Returns a future that wraps a URL session data task for a given URL.
    /// - Parameter url: The URL for which to create a data task.
    /// - Returns: `CoFuture` with future data task result.
    @inlinable public func dataTaskFuture(for url: URL) -> CoFuture<DataResponse> {
        dataTaskFuture(for: URLRequest(url: url))
    }
    
    // COFuture 的构建其实很简单, 创建一个对象, 然后触发异步函数. 在异步函数的回调里面, 进行状态的设置.
    // COFuture 上, 可以挂钩各种回调, 在 SetResult 上进行触发.
    // 从这个角度上来看, COFuture 其实是 Combine 中的逻辑响应链的头结点.
    /// Returns a future that wraps a URL session data task for a given URL request.
    /// - Parameter urlRequest: The URL request for which to create a data task.
    /// - Returns: `CoFuture` with future data task result.
    public func dataTaskFuture(for urlRequest: URLRequest) -> CoFuture<DataResponse> {
        let promise = CoPromise<DataResponse>()
        let task = dataTask(with: urlRequest) {
            if let error = $2 {
                promise.fail(error)
            } else if let data = $0, let response = $1 {
                promise.success((data, response))
            } else {
                promise.fail(URLError(.badServerResponse))
            }
        }
        task.resume()
        promise.whenCanceled(task.cancel)
        return promise
    }
    
}
