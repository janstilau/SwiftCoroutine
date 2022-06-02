//
//  ViewController.swift
//  MovieSwiftCoroutine
//
//  Created by Mac on 22.08.2020.
//  Copyright © 2020 Mac. All rights reserved.
//

import UIKit
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
    func getPopularMovies(){
        DispatchQueue.main.startCoroutine {
            self.movies = try self.dataManager.getPopularMovies().await()
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


