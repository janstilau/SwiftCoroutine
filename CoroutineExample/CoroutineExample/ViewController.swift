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
        DispatchQueue.global().startCoroutine {
            let (data, response, error) = try CoroutineStruct.await { callback in
                let url = URL.init(string: "https://github.com/belozierov/SwiftCoroutine")!
                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
            }
            let (data_1, response_1, error_1) = try CoroutineStruct.await { callback in
                let url = URL.init(string: "https://github.com/belozierov?tab=repositories")!
                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
            }
            let (data_2, response_2, error_2) = try CoroutineStruct.await { callback in
                let url = URL.init(string: "https://github.com/belozierov/SwiftCoroutine")!
                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
            }
            let (data_3, response_3, error_3) = try CoroutineStruct.await { callback in
                let url = URL.init(string: "https://www.baidu.com")!
                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
            }
            print("1 \(Thread.current)")
        }
        
//        DispatchQueue.main.startCoroutine {
//
//            let (data, response, error) = try Coroutine.await { callback in
//                let url = URL.init(string: "https://github.com/belozierov/SwiftCoroutine")!
//                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
//            }
//            let (data_1, response_1, error_1) = try Coroutine.await { callback in
//                let url = URL.init(string: "https://github.com/belozierov?tab=repositories")!
//                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
//            }
//            let (data_2, response_2, error_2) = try Coroutine.await { callback in
//                let url = URL.init(string: "https://github.com/belozierov/SwiftCoroutine")!
//                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
//            }
//            let (data_3, response_3, error_3) = try Coroutine.await { callback in
//                let url = URL.init(string: "https://www.baidu.com")!
//                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
//            }
//            print("2 \(Thread.current)")
//        }
//
//        DispatchQueue.main.startCoroutine {
//
//            let (data, response, error) = try Coroutine.await { callback in
//                let url = URL.init(string: "https://github.com/belozierov/SwiftCoroutine")!
//                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
//            }
//            let (data_1, response_1, error_1) = try Coroutine.await { callback in
//                let url = URL.init(string: "https://github.com/belozierov?tab=repositories")!
//                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
//            }
//            let (data_2, response_2, error_2) = try Coroutine.await { callback in
//                let url = URL.init(string: "https://github.com/belozierov/SwiftCoroutine")!
//                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
//            }
//            let (data_3, response_3, error_3) = try Coroutine.await { callback in
//                let url = URL.init(string: "https://www.baidu.com")!
//                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
//            }
//            print("3 \(Thread.current)")
//        }
//
//        DispatchQueue.main.startCoroutine {
//
//            let (data, response, error) = try Coroutine.await { callback in
//                let url = URL.init(string: "https://github.com/belozierov/SwiftCoroutine")!
//                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
//            }
//            let (data_1, response_1, error_1) = try Coroutine.await { callback in
//                let url = URL.init(string: "https://github.com/belozierov?tab=repositories")!
//                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
//            }
//            let (data_2, response_2, error_2) = try Coroutine.await { callback in
//                let url = URL.init(string: "https://github.com/belozierov/SwiftCoroutine")!
//                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
//            }
//            let (data_3, response_3, error_3) = try Coroutine.await { callback in
//                let url = URL.init(string: "https://www.baidu.com")!
//                URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
//            }
//            print("4 \(Thread.current)")
//        }
    }
    
    func btn_2_didClicked() {
        let channel = CoChannel<Int>(capacity: 1)

        DispatchQueue.global().startCoroutine {
            for i in 0..<100 {
                //imitate some work
                try CoroutineStruct.delay(.seconds(1))
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
    
    func btn_3_didClicked() {
        DispatchQueue.global().startCoroutine {
            print("3 Begin")
            CoroutineStruct.start {
                print("3 Inner Begin")
                CoroutineStruct.start {
                    print("3 Inner Inner Begin")
                    try CoroutineStruct.delay(.seconds(1))
                    print("3 Inner Inner End")
                }
                try CoroutineStruct.delay(.seconds(2))
                print("3 Inner End")
            }
            print("3 End")
        }

    }
    
    func btn_4_didClicked() {
        print(#function)
    }
}

