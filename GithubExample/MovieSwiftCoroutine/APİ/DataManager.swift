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
    private static let api_key = "?api_key=YOUR_TheMovieDatabase_API_KEY_HERE"
    
    static var popularMovies_URL : String {
        return "https://api.themoviedb.org/3/movie/popular\(movieApiConstant.api_key)&language=en-US"
    }
}
//MARK:-> DataManager
class DataManager {
    //:-> Get Popular Movie
    func getPopularMovies()->CoFuture<Movies>{
        guard let url = URL(string: movieApiConstant.popularMovies_URL) else {fatalError()}
        let movies = CoPromise<Movies>()
        
        DispatchQueue.main.startCoroutine {
            let (data , response , error) = try Coroutine.await{ callback in
                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
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

