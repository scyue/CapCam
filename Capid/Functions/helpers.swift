//
//  helpers.swift
//  Capid
//
//  Created by Shichao Yue on 7/13/18.
//  Copyright © 2018 Shichao Yue. All rights reserved.
//

import Foundation
import UIKit
import Photos
import MobileCoreServices
import AssetsLibrary

// get an NSDictionary from an image
func getEXIFFromImage(image:NSData) -> NSDictionary {
  let imageSourceRef = CGImageSourceCreateWithData(image, nil);
  let currentProperties = CGImageSourceCopyPropertiesAtIndex(imageSourceRef!, 0, nil)
  let mutableDict = NSMutableDictionary(dictionary: currentProperties!)
  return mutableDict
}

func getBestFormat(device: AVCaptureDevice) -> AVCaptureDevice.Format? {
  var bestFormat:AVCaptureDevice.Format?
  var bestPixels = 0
  for format in device.formats {
    let d = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
    let pixels = d.height * d.width
    if pixels > bestPixels {
      bestPixels = Int(pixels)
      bestFormat = format
    }
  }
  return bestFormat
}

func doubleValue(data: Data) -> Double {
  return Double(bitPattern: UInt64(littleEndian: data.withUnsafeBytes { $0.pointee } ))
}
