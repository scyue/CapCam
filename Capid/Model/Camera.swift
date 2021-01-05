//
//  Camera.swift
//  Capid
//
//  Created by Shichao Yue on 7/18/18.
//  Copyright © 2018 Shichao Yue. All rights reserved.
//

import UIKit
import AVFoundation


class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  
  var session = AVCaptureSession()
  var photoOutput = AVCapturePhotoOutput()
  var videoDataOutput = AVCaptureVideoDataOutput()
  var cameraPreviewLayer = AVCaptureVideoPreviewLayer()
  
  var backTeleCamera: AVCaptureDevice?
  var backWideCamera: AVCaptureDevice?
  var current: AVCaptureDevice?
  var saveMode = true
  
  var dimension: CMVideoDimensions?
  var cropArea: CGRect?
  
  var resize_factor: Int
  var quota = 0
  var start_time = 0.0
  
  let updateCounter: (Int) -> Void?
  
  var imageBuffer = [UIImage]()
  
  init(imageViewer: UIView, area: CGRect, updateCounter: @escaping (Int) -> Void, resize_factor: Int) {
    self.updateCounter = updateCounter
    self.resize_factor = resize_factor
    super.init()
    setupDevice()
    setupInputOutput()
    setupPreviewLayer(imageViewer: imageViewer)
    setupExposureParameter()
    dimension = CMVideoFormatDescriptionGetDimensions(current!.activeFormat.formatDescription)
    setupCropAreaForUIImage(area: area)
  }
  
  func setupDevice() {
    let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: [AVCaptureDevice.DeviceType.builtInTelephotoCamera, AVCaptureDevice.DeviceType.builtInWideAngleCamera],
      mediaType: AVMediaType.video,
      position: AVCaptureDevice.Position.back
    )
    let devices = deviceDiscoverySession.devices
    for device in devices {
      if device.deviceType == AVCaptureDevice.DeviceType.builtInTelephotoCamera {
        backTeleCamera = device
      } else if device.deviceType == AVCaptureDevice.DeviceType.builtInWideAngleCamera {
        backWideCamera = device
      }
    }
    current = backWideCamera
  }
  
  func setupExposureParameter() {
    do {
      try backWideCamera!.lockForConfiguration()
      backWideCamera!.activeFormat = getBestFormat(device: backWideCamera!)!
      backWideCamera!.setExposureModeCustom(duration: CMTimeMake(1, 800), iso: 50, completionHandler: nil)
      backWideCamera!.unlockForConfiguration()
      try backTeleCamera!.lockForConfiguration()
      backTeleCamera!.activeFormat = getBestFormat(device: backTeleCamera!)!
      backTeleCamera!.setExposureModeCustom(duration: CMTimeMake(1, 300), iso: 50, completionHandler: nil)
      backTeleCamera!.unlockForConfiguration()
    } catch {
      print(error)
    }
  }

  func setupInputOutput() {
    do {
      let captureDeviceInput = try AVCaptureDeviceInput(device: current!)
      session.addInput(captureDeviceInput)
      session.addOutput(photoOutput)
      videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable : Int(kCVPixelFormatType_32BGRA)] as! [String : Any]
      videoDataOutput.alwaysDiscardsLateVideoFrames = true
      videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
      session.addOutput(videoDataOutput)
      session.sessionPreset = AVCaptureSession.Preset.inputPriority
    } catch {
      print(error)
    }
  }

  func setupPreviewLayer(imageViewer: UIView) {
    cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
    cameraPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
    cameraPreviewLayer.connection!.videoOrientation = AVCaptureVideoOrientation.portrait
    cameraPreviewLayer.frame = imageViewer.frame
    imageViewer.layer.insertSublayer(cameraPreviewLayer, at: 0)
  }
  
  func switchCamera() {
    session.beginConfiguration()
    let newDevice = (current == backTeleCamera) ? backWideCamera : backTeleCamera
    for input in session.inputs {
      session.removeInput(input as! AVCaptureDeviceInput)
    }
    let cameraInput:AVCaptureDeviceInput
    do {
      cameraInput = try AVCaptureDeviceInput(device: newDevice!)
    } catch {
      print(error)
      return
    }
    if session.canAddInput(cameraInput) {
      session.addInput(cameraInput)
    }
    current = newDevice
    session.commitConfiguration()
  }
  
  func setupCropAreaForUIImage(area: CGRect) {
    let c = area
    let ph = CGFloat(dimension!.height)
    cropArea = CGRect(x: c.minY, y: ph - c.minX - c.width, width: c.height, height: c.width)
  }
  
  func focusTo(_ value: Float) {
    do {
      try current!.lockForConfiguration()
      current!.setFocusModeLocked(lensPosition: value, completionHandler: nil)
      current!.unlockForConfiguration()
    } catch {
      print(error)
    }
  }
  
  func toggleTorch() {
    do {
      try current!.lockForConfiguration()
      switch current!.torchMode {
      case .on:
        current!.torchMode = .off
      case .off:
        current!.torchMode = .on
      case .auto:
        current!.torchMode = .on
      }
      current!.unlockForConfiguration()
    } catch {
      print("Torch could not be used")
    }
  }
  
  func setTorchMode(mode: AVCaptureDevice.TorchMode) {
    do {
      try current!.lockForConfiguration()
      current!.torchMode = mode
      current!.unlockForConfiguration()
    } catch {
      print("Torch could not be used")
    }
  }

  
  func startRunning() {
    session.startRunning()
  }
  
  func stopRunning() {
    session.stopRunning()
  }
  
  func setQuota(_ amount: Int) {
    imageBuffer.removeAll(keepingCapacity: true)
    quota = amount
    updateCounter(quota)
    start_time = Date().ts()
  }
  
  func resetQuota() {
    quota = 0
    updateCounter(quota)
  }
  
  // ==========================================================
  //
  //  AVCaptureVideoDataOutputSampleBufferDelegate
  //
  // ==========================================================

  
  func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    if quota > 0 {
      let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer)
      imageBuffer.append(image)
      quota -= 1
      updateCounter(quota)
    }
  }
  
  func imageFromSampleBuffer(sampleBuffer :CMSampleBuffer) -> UIImage {
    
    let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
    
    CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
    let base = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)!
    let bytesPerRow = UInt(CVPixelBufferGetBytesPerRow(imageBuffer))
    let width = UInt(CVPixelBufferGetWidth(imageBuffer))
    let height = UInt(CVPixelBufferGetHeight(imageBuffer))
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitsPerCompornent = 8
    let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) as UInt32)
    let newContext = CGContext(data: base, width: Int(width), height: Int(height), bitsPerComponent: Int(bitsPerCompornent),
                               bytesPerRow: Int(bytesPerRow), space: colorSpace, bitmapInfo: bitmapInfo.rawValue)! as CGContext
    let imageRef = newContext.makeImage()
    let editedRef = cgimagePostprocess(imageRef!)
    let image = UIImage(cgImage: editedRef, scale: 1.0, orientation: UIImageOrientation.up)
    CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
    return image
  }
  
  func cgimagePostprocess(_ image: CGImage) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceGray()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
    let width = Int(cropArea!.width) / resize_factor
    let height = Int(cropArea!.height) / resize_factor
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                            space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
    context!.interpolationQuality = .high
    context!.translateBy(x: CGFloat(width / 2), y: CGFloat(height / 2))
    context!.rotate(by: .pi / -2)
    context!.translateBy(x: -CGFloat(width / 2), y: -CGFloat(height / 2))
    context!.draw(image.cropping(to: cropArea!)!, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context!.makeImage()!
  }
}

