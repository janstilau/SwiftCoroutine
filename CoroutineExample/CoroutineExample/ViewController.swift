//
//  ViewController.swift
//  CoroutineExample
//
//  Created by liuguoqiang on 2023/3/5.
//

import UIKit
import SwiftCoroutine

class ViewController: UIViewController {
    
    @IBOutlet weak var stackView: UIStackView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        stackView.arrangedSubviews.forEach { aView in
            guard let aBtn = aView as? UIButton else { return }
            aBtn.addTarget(self, action: #selector(btnDidClicked), for: .touchUpInside)
        }
    }
    
    @objc func btnDidClicked(_ sender: UIButton) {
        switch sender.tag {
        case 1:
            self.btn_1_didClicked()
        case 2:
            self.btn_2_didClicked()
        case 3:
            self.btn_3_didClicked()
        case 4:
            self.btn_4_didClicked()
        default:
            break
        }
    }
    
    func btn_1_didClicked() {
        DispatchQueue.main.startCoroutine {
            
            let (data, response, error) = try Coroutine.await { callback in
                let url = URL.init(string: "https://github.com/belozierov/SwiftCoroutine")!
                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
            }
            let (data_1, response_1, error_1) = try Coroutine.await { callback in
                let url = URL.init(string: "https://github.com/belozierov?tab=repositories")!
                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
            }
            let (data_2, response_2, error_2) = try Coroutine.await { callback in
                let url = URL.init(string: "https://github.com/belozierov/SwiftCoroutine")!
                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
            }
            let (data_3, response_3, error_3) = try Coroutine.await { callback in
                let url = URL.init(string: "https://www.baidu.com")!
                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
            }
            print(response)
        }
    }
    
    func btn_2_didClicked() {
        print(#function)
    }
    
    func btn_3_didClicked() {
        print(#function)
    }
    
    func btn_4_didClicked() {
        print(#function)
    }
}

