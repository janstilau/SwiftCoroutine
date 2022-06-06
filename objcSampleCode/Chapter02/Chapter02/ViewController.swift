//
//  ViewController.swift
//  Chapter02
//
//  Created by Wang Wei on 2021/06/28.
//

import UIKit

actor Holder {
    var results: [String] = []
    func setResults(_ results: [String]) {
        self.results = results
    }
    
    func append(_ value: String) {
        results.append(value)
    }
}

@globalActor
actor MyActor {
    static let shared = MyActor()
}

class ViewController: UIViewController {
    
    var holder = Holder()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        for i in 0 ..< 10000 {
            someSyncMethod(index: i)
        }
    }
    
    func someSyncMethod(index: Int) {
        Task {
            await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await self.loadResultRemotely()
                }
                group.addTask(priority:. low) {
                    try await self.processFromScratch()
                }
            }
            print("Done Task: \(index)")
        }
    }

    private var idGenerator: Int = 0
    
    func loadResultRemotely() async throws {
        let taskId = idGenerator
        idGenerator += 1
        print("TaskId: \(taskId), 当前线程: \(Thread.current)")
        // TaskId: 5, 当前线程: <NSThread: 0x28393d3c0>{number = 8, name = (null)}
        await Task.sleep(NSEC_PER_SEC + NSEC_PER_SEC / 80)
        print("TaskId: \(taskId), 恢复线程: \(Thread.current)")
        // TaskId: 5, 恢复线程: <NSThread: 0x28398f680>{number = 12, name = (null)}
        
        // 从上面的执行结果可以看到, 在 await 的前后, 并不一定会在同样的一个线程里面.
        // async/await 只能保证, 所有的逻辑, 能够按照正确的顺序进行执行, 但是从实际结果来看, 执行环境是不保证的.
        // 这在第三方库里面的实现, 也是使用了相同的策略.
        
        // 根据网络请求的结构, 一次性的给 holder 进行赋值处理.
        await holder.setResults(["data1^sig", "data2^sig", "data3^sig"])
    }
    
    func processFromScratch() async throws {
        async let loadStrings = loadFromDatabase()
        async let loadSignature = loadSignature()
        
        let strings = try await loadStrings
        if let signature = try await loadSignature {
            // 根据, 本地运行的结果, 给 hodler 进行赋值处理.
            await holder.setResults([])
            for data in strings {
                await holder.append(data.appending(signature))
            }
        } else {
            throw NoSignatureError()
        }
    }
    
    func loadFromDatabase() async throws -> [String] {
        await Task.sleep(NSEC_PER_SEC)
        return ["data1", "data2", "data3"]
    }
    
    func loadSignature() async throws -> String? {
        await Task.sleep(NSEC_PER_SEC)
        return "^sig"
    }
}

struct NoSignatureError: Error {}
