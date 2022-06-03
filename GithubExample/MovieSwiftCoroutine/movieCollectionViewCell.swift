//
//  movieCollectionViewCell.swift
//  MovieSwiftCoroutine
//
//  Created by Mac on 22.08.2020.
//  Copyright © 2020 Mac. All rights reserved.
//

import Foundation
import SDWebImage
import UIKit


class movieCollectionViewCell: UICollectionViewCell {
    private var mainView : UIView!
    private var imageView : UIImageView!
    private var movieNameLabel : UILabel!
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.backgroundColor = .clear
        
        self.layer.shadowColor = UIColor.purple.cgColor
        self.layer.shadowOpacity = 1
        self.layer.shadowOffset = CGSize(width: 10, height: 10)
        self.layer.shadowRadius = 30
        
        // View 的构建构成, 在初始化方法中
        self.setMainView()
        self.setMovieImageView()
        self.setTitleLabel()
    }
    private func setMainView(){
        self.mainView = UIView()
        self.mainView.backgroundColor = UIColor.red.withAlphaComponent(0.5)
        self.mainView.layer.borderWidth = 1.0
        self.mainView.layer.borderColor = UIColor.blue.cgColor
        
        self.addSubview(self.mainView)
        
        self.mainView.translatesAutoresizingMaskIntoConstraints = false
        self.mainView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        self.mainView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        self.mainView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        self.mainView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        
        self.mainView.layer.masksToBounds = true
        self.mainView.layer.cornerRadius = 16
    }
    private func setMovieImageView(){
        self.imageView = UIImageView()
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.mainView.addSubview(self.imageView)
        
        self.imageView.leftAnchor.constraint(equalTo: self.mainView.leftAnchor , constant: 24).isActive = true
        self.imageView.centerYAnchor.constraint(equalTo: self.mainView.centerYAnchor).isActive = true
        self.imageView.heightAnchor.constraint(equalTo: self.mainView.heightAnchor , multiplier: 0.5).isActive = true
        self.imageView.widthAnchor.constraint(equalTo: self.mainView.heightAnchor , multiplier: 0.5).isActive = true
    }
    private func setTitleLabel(){
        self.movieNameLabel = UILabel()
        self.movieNameLabel.text = ""
        self.movieNameLabel.textColor = .white
        self.movieNameLabel.textAlignment = .left
        self.movieNameLabel.numberOfLines = 0
        self.movieNameLabel.font = UIFont(name: "Avenir", size: 15)
        
        self.mainView.addSubview(self.movieNameLabel)
        self.movieNameLabel.translatesAutoresizingMaskIntoConstraints = false
        self.movieNameLabel.leftAnchor.constraint(equalTo: self.imageView.rightAnchor , constant: 10).isActive = true
        self.movieNameLabel.centerYAnchor.constraint(equalTo: self.mainView.centerYAnchor).isActive = true
        self.movieNameLabel.rightAnchor.constraint(equalTo: self.mainView.rightAnchor).isActive = true
        self.movieNameLabel.heightAnchor.constraint(equalTo: self.mainView.heightAnchor).isActive = true
        
    }
    
    func setData(_ movieName :String? , imageURL :String?){
        self.movieNameLabel.text = movieName
        let image_url = "https://image.tmdb.org/t/p/w500/"
        self.imageView.sd_setImage(with: URL(string: image_url + imageURL!), completed: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
