//
//  classes.swift
//  Capid
//
//  Created by Shichao Yue on 7/18/18.
//  Copyright © 2018 Shichao Yue. All rights reserved.
//

import UIKit
import AudioToolbox
import AVFoundation


class PhotoFrameOnView: UIView {
  var w_ratio = 0.0
  var h_ratio = 0.0
  var area: CGRect?
  
  func setup(dimension: CMVideoDimensions, cropArea: CGRect) {
    // Portrait Mode, change dimension width and height
    self.w_ratio = Double(self.bounds.width / CGFloat(dimension.height))
    self.h_ratio = Double(self.bounds.height / CGFloat(dimension.width))
    self.area = cropArea
  }
  
  override func draw(_ rect: CGRect) {
    let context = UIGraphicsGetCurrentContext()
    context?.setLineWidth(10.0)
    context?.setStrokeColor(UIColor.blue.cgColor)
    context?.move(to: CGPoint(x: Double(area!.minX) * w_ratio, y: Double(area!.minY) * h_ratio))
    context?.addLine(to: CGPoint(x: Double(area!.minX) * w_ratio, y: Double(area!.maxY) * h_ratio))
    context?.addLine(to: CGPoint(x: Double(area!.maxX) * w_ratio, y: Double(area!.maxY) * h_ratio))
    context?.addLine(to: CGPoint(x: Double(area!.maxX) * w_ratio, y: Double(area!.minY) * h_ratio))
    context?.addLine(to: CGPoint(x: Double(area!.minX) * w_ratio, y: Double(area!.minY) * h_ratio))
    context?.strokePath()
  }
}

class AimAssistorOnView: UIView {
  var location: CGPoint?
  var prev_location: CGPoint?
  var line: (CGPoint, CGPoint)?
  
  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else {return}
    context.clear(rect)
    if let loc = location {
      if let prev_loc = prev_location {
        context.setLineWidth(5.0)
        context.setStrokeColor(UIColor.orange.cgColor)
        context.move(to: prev_loc)
        context.addLine(to: CGPoint(x: prev_loc.x, y: loc.y))
        context.strokePath()
      } else {
        context.setLineWidth(3.0)
        context.setStrokeColor(UIColor.orange.cgColor)
        context.move(to: CGPoint(x: rect.minX, y: loc.y))
        context.addLine(to: CGPoint(x: rect.maxX, y: loc.y))
        context.move(to: CGPoint(x:loc.x, y:rect.minY))
        context.addLine(to: CGPoint(x:loc.x, y:rect.maxY))
        context.strokePath()
      }
    }
    if let prev_loc = prev_location {
      context.setFillColor(UIColor.orange.cgColor)
      let r = 6
      let origin = prev_loc - CGPoint(x: r, y: r)
      context.fillEllipse(in: CGRect(origin: origin, size: CGSize(width: 2 * r, height: 2 * r)))
    }
    if let line = line {
      context.setLineWidth(5.0)
      context.setStrokeColor(UIColor.purple.cgColor)
      context.move(to: line.0)
      context.addLine(to: line.1)
      context.strokePath()
    }
  }
  
  func clear() {
    line = nil
    prev_location = nil
    location = nil
    self.setNeedsDisplay()
  }
}


class Vibrator: NSObject {
  
  var vibration_thread: Thread?
  var vibrationMode = false
  
  override init() {
    super.init()
    vibration_thread = Thread(target: self, selector: #selector(self.vibrateForever), object: nil)
    vibration_thread?.start()
  }
  
  func set_mode(mode: Bool) { vibrationMode = mode }

  func toggle() { vibrationMode = !vibrationMode }
  
  @objc func vibrateForever() {
    while true {
      if vibrationMode {
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
      }
      usleep(500)
    }
  }
}

