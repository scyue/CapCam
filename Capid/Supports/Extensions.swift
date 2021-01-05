//
//  extensions.swift
//  Capid
//
//  Created by Shichao Yue on 7/18/18.
//  Copyright © 2018 Shichao Yue. All rights reserved.
//

import Foundation
import UIKit
import Photos
import MobileCoreServices
import AssetsLibrary


extension UIImage {
  func getPixelColor(pos: CGPoint) -> UIColor {
    let pixelData = self.cgImage!.dataProvider!.data
    let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
    let pixelInfo: Int = ((Int(self.size.width) * Int(pos.y)) + Int(pos.x)) * 4
    let r = CGFloat(data[pixelInfo]) / CGFloat(255.0)
    let g = CGFloat(data[pixelInfo+1]) / CGFloat(255.0)
    let b = CGFloat(data[pixelInfo+2]) / CGFloat(255.0)
    let a = CGFloat(data[pixelInfo+3]) / CGFloat(255.0)
    return UIColor(red: r, green: g, blue: b, alpha: a)
  }
  
  func getPixelValue() -> [Double]? {
    guard let imageRef = self.cgImage else { return nil }
    let width = imageRef.width
    let height = imageRef.height
    let colorspace = CGColorSpaceCreateDeviceGray()
    let pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: width*height)
    let context = CGContext(data: pixels, width: width, height: height, bitsPerComponent: imageRef.bitsPerComponent,
                            bytesPerRow: imageRef.bytesPerRow, space: colorspace, bitmapInfo: 0)
    context!.draw(imageRef, in: CGRect(x: 0, y: 0, width: width, height: height))
    return Array(UnsafeBufferPointer(start: pixels, count: width * height)).map{ Double($0) }
  }
  
  func resize(targetSize: CGSize) -> UIImage {
    let size = self.size
    let widthRatio  = targetSize.width  / size.width
    let heightRatio = targetSize.height / size.height
    let newSize = widthRatio > heightRatio ?  CGSize(width: size.width * heightRatio, height: size.height * heightRatio) : CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
    let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
    
    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    self.draw(in: rect)
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return newImage!
  }
  
  func crop(rect: CGRect) -> UIImage {
    var rect = rect
    rect.origin.x*=self.scale
    rect.origin.y*=self.scale
    rect.size.width*=self.scale
    rect.size.height*=self.scale
    let imageRef = self.cgImage!.cropping(to: rect)
    let image = UIImage(cgImage: imageRef!, scale: self.scale, orientation: self.imageOrientation)
    return image
  }
  
  var noir: UIImage? {
    let context = CIContext(options: nil)
    guard let currentFilter = CIFilter(name: "CIPhotoEffectNoir") else { return nil }
    currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
    if let output = currentFilter.outputImage,
      let cgImage = context.createCGImage(output, from: output.extent) {
      return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
    return nil
  }
}


extension UITextField {
  func addButtons(onDone: (target: Any, action: Selector)? = nil, onCancel: (target: Any, action: Selector)? = nil) {
    let onCancel = onCancel ?? (target: self, action: #selector(cancelButtonTapped))
    let onDone = onDone ?? (target: self, action: #selector(doneButtonTapped))
    
    let toolbar: UIToolbar = UIToolbar()
    toolbar.barStyle = .default
    toolbar.items = [
      UIBarButtonItem(title: "Cancel", style: .plain, target: onCancel.target, action: onCancel.action),
      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil),
      UIBarButtonItem(title: "Done", style: .done, target: onDone.target, action: onDone.action)
    ]
    toolbar.sizeToFit()
    
    self.inputAccessoryView = toolbar
  }
  
  // Default actions:
  @objc func doneButtonTapped() { self.resignFirstResponder() }
  @objc func cancelButtonTapped() { self.resignFirstResponder() }
}


extension Data {
  init<T>(from value: T) {
    var value = value
    self.init(buffer: UnsafeBufferPointer(start: &value, count: 1))
  }
  
  func to<T>(type: T.Type) -> T {
    return self.withUnsafeBytes { $0.pointee }
  }
  
  init<T>(fromArray values: [T]) {
    var values = values
    self.init(buffer: UnsafeBufferPointer(start: &values, count: values.count))
  }
  
  func toArray<T>(type: T.Type) -> [T] {
    return self.withUnsafeBytes {
      [T](UnsafeBufferPointer(start: $0, count: self.count/MemoryLayout<T>.stride))
    }
  }
}


extension Date {
  func ts() -> Double {
    return Double(self.timeIntervalSince1970)
  }
}


extension ImageGroup {
  func description() -> String {
    let tdr = self.tension/self.density
    let str = String.init(format: "%.1f, %d images", tdr, self.images!.count)
    guard let name = self.name else { return str }
    if name.count > 0 {
      return String.init(format: "\(name), %.1f, \(self.images!.count) images", tdr)
    } else {
      return str
    }
    
  }
  
  func timeString() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EEE, yyyy/MM/dd HH:mm:ss"
    return dateFormatter.string(from: self.datetime!)
  }
  
  func wl_to_tension(_ l_pixel: Double) -> Double {
    let l_m = l_pixel / self.resolution
    let k = 2 * Double.pi / l_m
    let w = 2 * Double.pi * self.frequency
    let g = 9.8
    let tension_ratio = (w * w - k * g) / (k * k * k) * 1e6
    return tension_ratio
  }
  
  func shortDescription() -> String {
    return String.init(format: "σ/ρ: %.1f", self.tension/self.density)
  }
}

extension CGPoint {
  static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
  }
  
  static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
  }
  
  static func /(lhs: CGPoint, rhs: Double) -> CGPoint {
    return CGPoint(x: Double(lhs.x) / rhs, y: Double(lhs.y) / rhs)
  }
}

