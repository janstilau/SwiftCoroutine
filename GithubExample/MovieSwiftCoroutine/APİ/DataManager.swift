//
//  DataManager.swift
//  MovieSwiftCoroutine
//
//  Created by Mac on 22.08.2020.
//  Copyright © 2020 Mac. All rights reserved.
//

import Foundation
import SwiftCoroutine

//MARK:-> URL
struct movieApiConstant {
    static let api_key = "?api_key=22da445752083e2b1c7cba53e1db864e"
    
    static var popularMovies_URL : String {
        return "https://api.themoviedb.org/3/movie/popular\(movieApiConstant.api_key)&language=en-US"
    }
}

var taskId: Int = 0

//MARK:-> DataManager
class DataManager {
    //:-> Get Popular Movie
    func getPopularMovies()->CoFuture<Movies>{
        /*
         Future 应该是一个统一的编程模型, 在 Qt 里面,  Future 在进行取值的时候, 是使用了线程的 WaitConfition 的模型. 如果在使用值的时候, 还没有得到 Result, 就进行线程的等待.
         在协程里面, 则是协程的等待, 知道 Future SetResult 的时候, 才会进行协程的唤醒.
         */
        guard let url = URL(string: movieApiConstant.popularMovies_URL) else {fatalError()}
        let moviedPromise = CoPromise<Movies>()
        
        
        DispatchQueue.main.startCoroutine {
            // callback 从哪里来的啊.
            taskId += 1
            let recordId = taskId
            let currentThread = Thread.current
            print("网络任务: \(recordId) 启动线程 \(Thread.current)")
            // Coroutine.await  是找到当下的协程, 进行 wait 的操作.
            let (data , response , error) = try Coroutine.await { callback in
                //  open func dataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask
                // dataTask(with 本身, 就是 completionHandler 的参数, 是一个元组类型.
                // 对于 Callback 来说, 它的参数, 只会是一个, 只不过这个参数的类型是一个元组类型. 而不是, 回调是多个参数.
                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
            }
            print("网络任务: \(recordId) 恢复线程 \(Thread.current)")
            /*
             这里之所以进行这样的一个比较, 是之前思考错误的结果.
             协程其实和线程不是绑定的, 在这个库里面, scheduler 控制的是, 协程的 start, resume 的等操作, 应该在什么环境下.
             如果是使用 globalQueue 作为调度器, 那么 Coroutine.await 之前的环境, 可能是线程 1.
             在 Coroutine.await 中, 经过回调函数, 触发了协程的 resume 的时候, 还是会使用 globalQueue 来调度, 协程 resume 的操作.
             因为是 globalQueue, 所以协程逻辑再次被执行的时候, 线程很有可能就不是同样的一个线程.
             
             正是因为如此, 如果是使用 mainQueue 当做调度器的话, 那么一定就是在同一个线程里面了.
             */
            if currentThread != Thread.current {
                print("网络任务不是一个线程")
            }
            
            if let response = response {
                let httpResponse = response as! HTTPURLResponse
                print(httpResponse.statusCode)
            }
            if let error = error {
                print(error.localizedDescription)
            }
            
            // 主动添加第二个异步任务, 查看协程的状态.
            let (_ , _ , _) = try Coroutine.await { callback in
                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
            }
            
            
            if let data = data {
                if let dataMovies = self.parse(data: data)  {
                    // 在异步函数的最终位置, 进行 Promise 的状态的改变.
                    moviedPromise.success(dataMovies)
                }
            }
        }
        return moviedPromise
    }
    
    func someAsync() -> Void {
        DispatchQueue.main.startCoroutine {
            let value = try? Coroutine.await { callback in
                URLSession.shared.dataTask(with: URL.init(string: "https://www.baidu.com")!,
                                           completionHandler: callback).resume()
            }
        }
    }
    
    //:-> Parsing
    private func parse(data : Data) -> Movies?{
        let decoder = JSONDecoder()
        var movies: Movies? = nil
        do {
            movies = try decoder.decode(Movies.self, from: data)
        }catch {
            print(error.localizedDescription)
        }
        
        return movies
    }
}

