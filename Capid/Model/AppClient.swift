//
//  AppClient.swift
//  PhotoProcessor
//
//  Created by Shichao Yue on 8/13/18.
//  Copyright © 2018 Shichao Yue. All rights reserved.
//

import Foundation
import SwiftSocket

class AppClient: NSObject {
  
  var log: (String) -> Void?
  var socket: TCPClient?
  
  var host = "scyue.csail.mit.edu"
  let port = Int32(6004)
  
  init(log: @escaping (String) -> Void) {
    self.log = log
    super.init()
    self.connect()
  }
  
  func connect() {
    socket = TCPClient(address: host, port: port)
    guard let socket = socket else { return }
    switch socket.connect(timeout: 1) {
    case .success:
      log("Connected to host \(socket.address)")
      break
    case .failure:
      log("Socket connection failed")
    }
  }
  
  func disconnect() {
    socket?.close()
  }
  
  func send_tag(_ tag: String) {
    switch socket!.send(string: tag) {
    case .success:
      break
    case .failure:
      self.connect()
      socket!.send(string: tag)
    }
  }
  
  @discardableResult
  func send_pointer<T>(_ d: UnsafePointer<T>, _ count: Int) -> Int {
    send_tag("dat")
    let data = Data(buffer: UnsafeBufferPointer(start: d, count: count))
    return send_data(data)
  }
  
  @discardableResult
  func send_array<T>(_ d: Array<T>, _ name: String = "test") -> Int {
    send_tag("deb")
    send_data(name.count, with_count: false)
    send_tag(name)
    return send_data(Data(fromArray: d))
  }
  
  @discardableResult
  func send_data<T>(_ d: T, with_count: Bool=true) -> Int{
    var data: Data
    if d is Data {
      data = d as! Data
    } else {
      data = Data(from: d)
    }
    if with_count {
      socket!.send(data: Data(from: data.count))
    }
    switch socket!.send(data: data) {
    case .success:
      return data.count
    case .failure:
      print("AppServer is down!")
      return -1
    }
  }
  
  func receive_packet() -> Data? {
    guard let byte_count = socket?.read(4, timeout: 1)?.to(type: Int.self) else {
      print("Socket Error when receiving packet")
      return nil
    }
    return socket?.read(byte_count, timeout: 100)
  }
  
  func receive_double() -> Double? {
    return socket?.read(8, timeout: 1)?.to(type: Double.self)
  }
}

