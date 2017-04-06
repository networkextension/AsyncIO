//
//  EServer.swift
//  EchoServer
//
//  Created by 孔祥波 on 06/04/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation
extension NSLock {
    @discardableResult
    func with<T>(_ fn: () -> T) -> T {
        lock()
        let ret = fn()
        unlock()
        return ret
    }
}


class EServer {
    static var shared = EServer()
    var clients:Set<Process> = []
    var list:Socket?
    let queue: DispatchQueue = DispatchQueue.init(label: "test",attributes: .concurrent)
    private var sourceGroup: DispatchGroup?
    private var dispatchSource: DispatchSourceProtocol?
    private let clientSocketsLock = NSLock()
    func start()  {
        do {
           list =  try Socket.tcpSocketForListen(8081, true, 64, "127.0.0.1")
            
            
            
            sourceGroup = DispatchGroup()
            dispatchSource = createDispatchSource(list!)
            guard let source = dispatchSource else {
               return // throw punosError(0, "Could not create dispatch source")
            }
            source.resume()
            
        }catch let e {
            print(e.localizedDescription)
        }
        
    }
    
    func log(_ msg:String){
        print(msg)
    }
    
    private func createDispatchSource(_ listeningSocket: Socket) -> DispatchSourceProtocol? {
        guard let sourceGroup = sourceGroup else { return nil }
        
        let listeningSocketFD = listeningSocket.socketFileDescriptor
        sourceGroup.enter()
        let source = DispatchSource.makeReadSource(fileDescriptor: listeningSocketFD, queue: queue)
        
        source.setCancelHandler { _ in
            
            Socket.close(listeningSocketFD)
            sourceGroup.leave()
        }
        
        source.setEventHandler { _ in
            autoreleasepool {
                print("new event")
                do {
                    let clientSocket = try listeningSocket.acceptClientSocket()
                    let p = Process.init(s: clientSocket, q: self.queue)
                    self.clientSocketsLock.with {
                        
                        self.clients.insert(p)
                    }
                    
                    self.queue.async {
                        //p.handleConnection()
                        p.complete = { (e) -> Void in
                            self.clientSocketsLock.with {
                                self.clients.remove(p)
                            }
                        }

                        
                    }
                } catch let error {
                    self.log("Failed to accept socket. Error: \(error)")
                }
            }
        }
        
        log("Started dispatch source for listening socket \(listeningSocketFD)")
        return source
    }
    
}
