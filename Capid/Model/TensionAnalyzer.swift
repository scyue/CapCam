//
//  TensionAnalyzor.swift
//  Capid
//
//  Created by Shichao Yue on 7/31/18.
//  Copyright © 2018 Shichao Yue. All rights reserved.
//

import Foundation
import CoreGraphics


class AnalysisResult {
  var line = [0.0]
  var peaks = [0]
  var wave_avg = 0.0
  var wave_std = 0.0
  var ratio = 0.0
  
  func compute_ratio(group: ImageGroup) {
    let l_m = wave_avg / group.resolution
    let k = 2 * Double.pi / l_m
    let w = 2 * Double.pi * group.frequency
    let g = 9.8
    ratio = (w * w - k * g) / pow(k, 3) * 1e6
  }
  
  init() {}
  
  func description() -> String {
    return String.init(format: "Wavelength: %.2f ± %.2f, ratio: %.2f", wave_avg, wave_std, ratio)  
  }
}


class TensionAnalyzer {
  
  var data: [[Double]]
  let group: ImageGroup
  let client: AppClient
  let radius = 5
  
  init(_ data: [Double], _ group: ImageGroup, _ width: Int, _ height: Int, _ client: AppClient) {
    self.data = Array(repeating: Array(repeating: Double(0), count: height), count: width)
    for i in stride(from: 0, to: height, by: 1) {
      for j in stride(from: 0, to: width, by: 1) {
        self.data[i][j] = data[i * width + j]
      }
    }
    self.group = group
    self.client = client
  }
  
  func avgValueAt(_ point: CGPoint) -> Double {
    let x = Int(point.x + 0.5)
    let y = Int(point.y + 0.5)
    var total = 0.0
    var count = 0.0
    for i in stride(from: x - radius, to: x + radius + 1, by: 1) {
      for j in stride(from: y - radius, to: y + radius + 1, by: 1) {
        total += data[j][i]
        count += 1
      }
    }
    return total / count
  }
  
  func lineValue(from: CGPoint, to: CGPoint) -> [Double] {
    let path = to - from
    let distance = sqrt(path.x * path.x + path.y * path.y)
    let unit = path / Double(distance)
    var value = Array(repeating: 0.0, count: Int(distance))
    var loc = from
    for i in stride(from: 0, to: Int(distance), by: 1) {
      value[i] = avgValueAt(loc)
      loc = loc + unit
    }
    return value
  }
  
  func regularize(_ x: CGFloat) -> CGFloat {
    var new_x = x
    if new_x < CGFloat(radius) {
      new_x = CGFloat(radius)
    } else if new_x > CGFloat(data.count - radius - 1) {
      new_x = CGFloat(data.count - radius - 1)
    }
    return new_x
  }
  
  func analyze_line(from: CGPoint, to: CGPoint, factor: Double) -> AnalysisResult? {
    var from = from
    var to = to
    let result = AnalysisResult()
    from.y = regularize(from.y)
    to.y = regularize(to.y)
    client.send_tag("lin")
    client.send_data(Data(fromArray: lineValue(from: from / factor, to: to / factor)))
    
    guard let line = client.receive_packet()?.toArray(type: Double.self) else {
      print("Receiving Filtered Line Error")
      return nil
    }
    result.line = line
    
    guard let peaks = client.receive_packet()?.toArray(type: Int.self) else {
      print("Receiving Peak Indexes Error")
      return nil
    }
    result.peaks = peaks
    
    guard let wave_avg = client.receive_double() else {
      print("Receiving Wavelength Average Error")
      return nil
    }
    result.wave_avg = wave_avg
    
    guard let wave_std = client.receive_double() else {
      print("Receiving Wavelength Stdev Error")
      return nil
    }
    result.wave_std = wave_std
    
    result.compute_ratio(group: group)
    return result
  }
}
