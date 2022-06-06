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
fileprivate struct movieApiConstant {
    private static let api_key = "?api_key=22da445752083e2b1c7cba53e1db864e"
    
    static var popularMovies_URL : String {
        return "https://api.themoviedb.org/3/movie/popular\(movieApiConstant.api_key)&language=en-US"
    }
}

var taskId: Int = 0

//MARK:-> DataManager
class DataManager {
    //:-> Get Popular Movie
    func getPopularMovies()->CoFuture<Movies>{
        guard let url = URL(string: movieApiConstant.popularMovies_URL) else {fatalError()}
        let movies = CoPromise<Movies>()
        
        // 在这里, 又进行了一次协程的创建
        DispatchQueue.main.startCoroutine {
            // callback 从哪里来的啊.
            taskId += 1
            let recordId = taskId
            let currentThread = Thread.current
            print("网络任务: \(recordId) 启动线程 \(Thread.current)")
            let (data , response , error) = try Coroutine.await { callback in
                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
            }
            print("网络任务: \(recordId) 恢复线程 \(Thread.current)")
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
            if let data = data {
                if let dataMovies = self.parse(data: data)  {
                    movies.success(dataMovies)
                }
            }
        }
        return movies
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

