//
//  ViewController.swift
//  MovieSwiftCoroutine
//
//  Created by Mac on 22.08.2020.
//  Copyright © 2020 Mac. All rights reserved.
//

import UIKit
import SwiftCoroutine
//MARK:-> ViewModel
class ViewControllerViewModel {
    private let dataManager = DataManager()
    var movies : Movies? = nil {
        didSet {
            if let movies = movies {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "movie"), object: nil)
                print(movies)
            }
        }
    }
    var temp_1: Movies? = nil
    var temp_2: Movies? = nil
    var temp_3: Movies? = nil
    var temp_4: Movies? = nil
    func getPopularMovies(){
        // DispatchQueue.main.startCoroutine
        // 这应该就是 await 所做的事情了.
        
        DispatchQueue.main.startCoroutine {
            self.movies = try self.dataManager.getPopularMovies().await()
        }
        
        var idGenerator: Int = 0
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            print("真正的任务 \(taskId) 启动线程 \(Thread.current)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
        }
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            print("真正的任务 \(taskId) 启动线程 \(Thread.current)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
        }
        DispatchQueue.main.startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            print("真正的任务 \(taskId) 启动线程 \(Thread.current)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
        }
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            print("真正的任务 \(taskId) 启动线程 \(Thread.current)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            print("真正的任务 \(taskId) 启动线程 \(Thread.current)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            print("真正的任务 \(taskId) 启动线程 \(Thread.current)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            print("真正的任务 \(taskId) 启动线程 \(Thread.current)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            print("真正的任务 \(taskId) 启动线程 \(Thread.current)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            print("真正的任务 \(taskId) 启动线程 \(Thread.current)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            let startThread = Thread.current
            print("真正的任务 \(taskId) 启动线程 \(startThread)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
            if Thread.current != startThread {
                print("真正的任务不是一个线程!!!!")
            }
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            let startThread = Thread.current
            print("真正的任务 \(taskId) 启动线程 \(startThread)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
            if Thread.current != startThread {
                print("真正的任务不是一个线程!!!!")
            }
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            let startThread = Thread.current
            print("真正的任务 \(taskId) 启动线程 \(startThread)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
            if Thread.current != startThread {
                print("真正的任务不是一个线程!!!!")
            }
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            let startThread = Thread.current
            print("真正的任务 \(taskId) 启动线程 \(startThread)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
            if Thread.current != startThread {
                print("真正的任务不是一个线程!!!!")
            }
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            let startThread = Thread.current
            print("真正的任务 \(taskId) 启动线程 \(startThread)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
            if Thread.current != startThread {
                print("真正的任务不是一个线程!!!!")
            }
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            let startThread = Thread.current
            print("真正的任务 \(taskId) 启动线程 \(startThread)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
            if Thread.current != startThread {
                print("真正的任务不是一个线程!!!!")
            }
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            let startThread = Thread.current
            print("真正的任务 \(taskId) 启动线程 \(startThread)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
            if Thread.current != startThread {
                print("真正的任务不是一个线程!!!!")
            }
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            let startThread = Thread.current
            print("真正的任务 \(taskId) 启动线程 \(startThread)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
            if Thread.current != startThread {
                print("真正的任务不是一个线程!!!!")
            }
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            let startThread = Thread.current
            print("真正的任务 \(taskId) 启动线程 \(startThread)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
            if Thread.current != startThread {
                print("真正的任务不是一个线程!!!!")
            }
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            let startThread = Thread.current
            print("真正的任务 \(taskId) 启动线程 \(startThread)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
            if Thread.current != startThread {
                print("真正的任务不是一个线程!!!!")
            }
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            let startThread = Thread.current
            print("真正的任务 \(taskId) 启动线程 \(startThread)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
            if Thread.current != startThread {
                print("真正的任务不是一个线程!!!!")
            }
        }
        
        DispatchQueue.global().startCoroutine {
            idGenerator += 1
            let taskId = idGenerator
            let startThread = Thread.current
            print("真正的任务 \(taskId) 启动线程 \(startThread)")
            let _ = try self.dataManager.getPopularMovies().await()
            print("真正的任务 \(taskId) 回复线程 \(Thread.current)")
            if Thread.current != startThread {
                print("真正的任务不是一个线程!!!!")
            }
        }
        
//        DispatchQueue.main.startCoroutine {
//            self.movies = try self.dataManager.getPopularMovies().await()
//        }
//        DispatchQueue.main.startCoroutine {
//            self.temp_1 = try self.dataManager.getPopularMovies().await()
//        }
//        DispatchQueue.main.startCoroutine {
//            self.temp_2 = try self.dataManager.getPopularMovies().await()
//        }
//        DispatchQueue.main.startCoroutine {
//            self.temp_3 = try self.dataManager.getPopularMovies().await()
//        }
//        DispatchQueue.main.startCoroutine {
//            self.temp_4 = try self.dataManager.getPopularMovies().await()
//        }
        
        print("ViewDidLoad End")
    }
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    
    @IBAction func callFuturePressed(_ sender: Any) {
        executeFuture()
    }
    @IBOutlet weak var label: UILabel!
    
    
    let imageURL = URL(string: "https://i.ibb.co/2P7sVL4/205585.jpg")!

//    override func viewDidLoad() {
//        super.viewDidLoad()
//        // Do any additional setup after loading the view.
//        executeCoroutine()
//        indicator.startAnimating()
//        executeChannel()
//    }
  
    /// 1- usage of await() inside a coroutine to wrap asynchronous calls.
    ///
    
    func executeCoroutine() {
         
        //execute coroutine on the main thread
        DispatchQueue.main.startCoroutine {

            //await URLSessionDataTask response without blocking the thread
            let (data, _, _) = try Coroutine.await { callback in
                URLSession.shared.dataTask(with: self.imageURL, completionHandler: callback).resume()
            }

            guard let image = UIImage(data: data!) else { return }
            self.imageView.image = image
            self.indicator.stopAnimating()
        }
    }
  
    /// 2- Futures and Promises
    ///
    
    
//    CoFuture and its subclass CoPromise are the implementation of the Future/Promise approach. They allow to launch asynchronous tasks and immediately returnCoFuture with its future results. The available result can be observed by the whenComplete() callback or by await() inside a coroutine without blocking a thread.
    
    func someAsyncFunc(completionHandler: @escaping (Int) -> Void)  {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            completionHandler(75)
        }
    }
    
    //wraps some async func with CoFuture
    func makeIntFuture() -> CoFuture<Int> {
        let promise = CoPromise<Int>()
        someAsyncFunc { int in
            promise.success(int)
        }
        return promise
    }

    func executeFuture() {
        // It allows to start multiple tasks in parallel and synchronize them later with await().

        //create CoFuture<Int> that takes 2 sec. from the example above
        let future1: CoFuture<Int> = makeIntFuture()

        //execute coroutine on the global queue and returns CoFuture<Int> with future result
        let future2: CoFuture<Int> = DispatchQueue.global().coroutineFuture {
            try Coroutine.delay(.seconds(3)) //some work that takes 3 sec.
            return 24
        }

        //execute coroutine on the main thread
        DispatchQueue.main.startCoroutine {
            let sum: Int = try future1.await() + future2.await() //will await for 3 sec.
            self.label.text = "Sum is \(sum)"
        }
    }
   
    
    /// 3- Channels
    ///
    
    // Futures and promises provide a convenient way to transfer a single value between coroutines. [Channels] provide a way to transfer a stream of values. Conceptually, a channel is similar to a queue that allows to suspend a coroutine on receive if it is empty, or on send if it is full.
    
    // Usage:
    // To create channels, use the CoChannel class.

    //create a channel with a buffer which can store only one element
    
    func executeChannel() {
        
        let channel = CoChannel<Int>(capacity: 1)

        DispatchQueue.global().startCoroutine {
            for i in 0..<9 {
                //imitate some work
                try Coroutine.delay(.seconds(1))
                //sends a value to the channel and suspends coroutine if its buffer is full
                try channel.awaitSend(i)
            }

            //close channel when all values are sent
            channel.close()
        }

        DispatchQueue.global().startCoroutine {
            //receives values until closed and suspends a coroutine if it's empty
            for i in channel.makeIterator() {
                print("Receive", i)
            }

            print("Done")
        }

    }
   
    
    
}
class ViewController: UIViewController {

    private var collectionViewIdentifier = "movieCell"
    private var collectionView : UICollectionView!
    private var collectionViewFlowLayout : UICollectionViewFlowLayout!
    private let viewModel = ViewControllerViewModel()
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.viewModel.getPopularMovies()
        
        self.setCollectionView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: NSNotification.Name(rawValue: "movie"), object: nil)
    }
    @objc func reloadData(){
        self.collectionView.reloadData()
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
//MARK:->Set  CollectionView
extension ViewController {
    private func setCollectionView(){
        self.collectionViewFlowLayout = UICollectionViewFlowLayout()
        self.collectionViewFlowLayout.itemSize = CGSize(width: UIScreen.main.bounds.width - 48, height: 100)
        self.collectionViewFlowLayout.minimumLineSpacing  = 10
        self.collectionViewFlowLayout.scrollDirection = .vertical
        
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.collectionViewFlowLayout)
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        self.collectionView.register(movieCollectionViewCell.self, forCellWithReuseIdentifier: self.collectionViewIdentifier)
        self.collectionView.backgroundColor = .clear
        self.view.addSubview(self.collectionView)
        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        self.collectionView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.collectionView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        self.collectionView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        self.collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
    }
}
//MARK:-> CollectionView Delegate
extension ViewController : UICollectionViewDelegate , UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let result = self.viewModel.movies?.results {
            return result.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: self.collectionViewIdentifier, for: indexPath) as? movieCollectionViewCell else {fatalError()}
        if let result = self.viewModel.movies?.results[indexPath.row]{
            cell.setData(result.originalTitle, imageURL: result.posterPath)
        }
        return cell
    }
 
}


