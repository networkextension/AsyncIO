//
//  Process.swift
//  EchoServer
//
//  Created by 孔祥波 on 06/04/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation
typealias finCallBack = (_ error:Error) -> Void
class Process:Hashable {
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    static func ==(lhs: Process, rhs: Process) -> Bool {
        return lhs.socket == rhs.socket
    }
    var hashValue: Int {
        get {
            return socket.hashValue
        }
    }
    var socket:Socket
    var queue:DispatchQueue
    var complete:finCallBack?
    private var sourceGroup: DispatchGroup?
    private var dispatchSource: DispatchSourceProtocol?
    init(s:Socket,q:DispatchQueue) {
        self.socket = s
        self.queue = q
        
        sourceGroup = DispatchGroup()
        dispatchSource = createDispatchSource(socket)
        dispatchSource?.resume()
    }
    func log(_ msg:String){
        print(msg)
    }
    private func createDispatchSource(_ listeningSocket: Socket) -> DispatchSourceProtocol? {
        guard let sourceGroup = sourceGroup else { return nil }
        
        let fd = socket.socketFileDescriptor
        sourceGroup.enter()
        let source = DispatchSource.makeReadSource(fileDescriptor: socket.socketFileDescriptor, queue: queue)
        
        source.setCancelHandler { _ in
            
            Socket.close(fd)
            sourceGroup.leave()
        }
        
        source.setEventHandler { _ in
            autoreleasepool {
                do {
                    var data = try self.read()
                    if data.count > 0 {
                        data.append(contentsOf: [0x20])
                       try  self.write(data)
                    }

                } catch let error {
                    guard let complete = self.complete else  {
                        Socket.close(self.socket.socketFileDescriptor)
                        return
                    }
                    
                    complete(error)
                }
            }
        }
        
        log("Started dispatch source for listening socket \(socket.socketFileDescriptor)")
        return source
    }
    func read() throws ->  Data{
        let statusLine = try socket.readLine()
        return statusLine.data(using: .utf8)!
    }
    func write(_ data:Data) throws {
       try socket.writeData(data)
    }
    func handleConnection(doneCallback: @escaping () -> Void) {
        guard let request = try? self.read() else {
            //socket.releaseIgnoringErrors()
            doneCallback()
            return
        }
        
        respondToRequestAsync(request) { response in
            do {
                _ = try self.write(response)
            } catch {
                print("Failed to send response: \(error)")
            }
            //socket.releaseIgnoringErrors()
            doneCallback()
        }
    }
    private func respondToRequestAsync(_ request: Data, responseCallback: @escaping (Data) -> Void) {
        responseCallback(request)
        
    }
    deinit {
        print("client deinit")
    }
}
