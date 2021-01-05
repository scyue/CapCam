//
//  ImageProcessor.swift
//  PhotoProcessor
//
//  Created by Shichao Yue on 8/13/18.
//  Copyright © 2018 Shichao Yue. All rights reserved.
//

import Foundation
import Accelerate
import Surge

func generate_gaussian_kernel(sigma: Float) -> [Float] {
  var g_ker = [Float](repeating: 0, count: Int(3 * sigma * 2 + 1))
  let factor = 1/(sqrt(2 * Float.pi) * sigma)
  for i in 0 ... Int(3 * sigma * 2) {
    let x = (Float(i) - 3 * sigma) / sigma
    g_ker[i] = factor * exp(-x * x / 2)
  }
  return g_ker
}

func conv_reflect(_ x: [Float], _ k: [Float]) -> [Float] {
  precondition(x.count >= k.count, "Input vector [x] must have at least as many elements as the kernel,  [k]")
  let result_size = x.count
  var result = [Float](repeating: 0, count: x.count)
  result.withUnsafeMutableBufferPointer { rbp in
    let xPad_fore = repeatElement(x[0] as Float, count: k.count / 2)
    let xPad_back = repeatElement(x[x.count - 1] as Float, count: k.count - 1 - xPad_fore.count)
    var xPadded = [Float]()
    xPadded.reserveCapacity(xPad_fore.count + numericCast(x.count) + xPad_back.count)
    xPadded.append(contentsOf: xPad_fore)
    xPadded.append(contentsOf: x)
    xPadded.append(contentsOf: xPad_back)
    vDSP_conv(xPadded, 1, k, 1, rbp.baseAddress!, 1, numericCast(result_size), numericCast(k.count))
  }
  return result
}

func conv_reflect(_ x: [Double], _ k: [Double]) -> [Double] {
  precondition(x.count >= k.count, "Input vector [x] must have at least as many elements as the kernel,  [k]")
  let result_size = x.count
  var result = [Double](repeating: 0, count: x.count)
  result.withUnsafeMutableBufferPointer { rbp in
    let xPad_fore = repeatElement(x[0], count: k.count / 2)
    let xPad_back = repeatElement(x[x.count - 1], count: k.count - 1 - xPad_fore.count)
    var xPadded = [Double]()
    xPadded.reserveCapacity(xPad_fore.count + numericCast(x.count) + xPad_back.count)
    xPadded.append(contentsOf: xPad_fore)
    xPadded.append(contentsOf: x)
    xPadded.append(contentsOf: xPad_back)
    vDSP_convD(xPadded, 1, k, 1, rbp.baseAddress!, 1, numericCast(result_size), numericCast(k.count))
  }
  return result
}


func normalize(_ x: [Float]) -> [Float] {
  var xx = x
  xx -= mean(x)
  xx /= std(xx)
  return xx
}


class ImageProcessor {
  
  let client: AppClient!
  
  let length = 320
  let start_row = 100
  let end_row = 250
  let total: Int!
  let kernel_size = 5
  let kernel_float: UnsafeMutablePointer<Float>!
  let orig_len: Int!
  let strip_r = 10
  
  let g_ker_20: [Float]!
  let g_ker_10_d: [Double]!
  let g_ker_5: [Float]!
  let g_ker_5_d: [Double]!
  let g_ker_3: [Float]!
  let g_ker_3_d: [Double]!
  let g_ker_1: [Float]!
  
  var accumulation: [Float]!
  var wavelengths = [Double]()
  var min_loc: Int?
  
  init(orig_len: Int, log: (String) -> Void, client: AppClient) {
    self.orig_len = orig_len
    self.client = client
    total = length * length
    kernel_float = UnsafeMutablePointer<Float>.allocate(capacity: kernel_size * kernel_size)
    accumulation = [Float](repeating: 0, count: length)
    g_ker_20 = generate_gaussian_kernel(sigma: 20)
    g_ker_10_d = generate_gaussian_kernel(sigma: 10).map{ Double($0) }
    g_ker_5 = generate_gaussian_kernel(sigma: 5)
    g_ker_5_d = generate_gaussian_kernel(sigma: 5).map{ Double($0) }
    g_ker_3 = generate_gaussian_kernel(sigma: 3)
    g_ker_3_d = generate_gaussian_kernel(sigma: 3).map{ Double($0) }
    g_ker_1 = generate_gaussian_kernel(sigma: 1)
    initialize_conv_kernel()
  }
  
  func analyzeGroup(_ images: [UIImage]) -> ([Double], [Double], Int, Double) {
    self.start_analysis()
    for i in 0 ..< images.count {
      self.add(imageRef: images[i].cgImage!)
    }
    self.find_location()
    for i in 0 ..< images.count {
      self.extract_peaks(image: images[i].cgImage!)
    }
    return self.wavelength_statistics()
  }
  
  func analyzeGroup(_ images: [UIImage], loc: Int) -> ([Double], [Double], Int, Double) {
    self.start_analysis()
    self.min_loc = loc
    for i in 0 ..< images.count {
      self.extract_peaks(image: images[i].cgImage!)
    }
    return self.wavelength_statistics()
  }

  
  func wavelength_statistics() -> ([Double], [Double], Int, Double) {
    let hist_n = 200;
    let hist_x = [Double](repeating: 0, count: hist_n);
    let hist_v = [Double](repeating: 0, count: hist_n);
    let hist_x_p = UnsafeMutablePointer(mutating: hist_x)
    let hist_v_p = UnsafeMutablePointer(mutating: hist_v)
    histogram(wavelengths, wavelengths.count, hist_x_p, hist_v_p, hist_n);
    let hist_v_g = conv_reflect(hist_v, g_ker_5_d)
    var rough_max = argmax(hist_v_g, hist_v_g.count)
//    let offset = 20
//    let scale = hist_x[1] - hist_x[0]
//    rough_max = min(offset, rough_max)
//    rough_max = max(hist_v.count - offset - 1, rough_max)
//    let seg = Array(hist_v_g[rough_max-offset ... rough_max+offset])
//    var refinement = peak_refinement(seg, Int32(seg.count)) - Double(offset);
//    refinement *= scale
//    let wavelength = hist_x[rough_max] + refinement
    let wavelength = hist_x[rough_max]
    return (hist_x, hist_v_g, self.min_loc!, wavelength)
  }
  
  func initialize_conv_kernel() {
    for i in 0...4 {
      for j in 0...4 {
        if j < 2 {
          kernel_float[i * 5 + j] = -1.0
        } else if j == 2 {
          kernel_float[i * 5 + j] = 0.0
        } else {
          kernel_float[i * 5 + j] = 1.0
        }
      }
    }
  }
  
  func debug(image: CGImage) {
    let (wave, _, maximas) = extract_peaks(image: image)
    client.send_array(wave, "wave")
    client.send_array(maximas, "maximas")
  }
  
  func extract_wave(image: CGImage) -> [Double]? {
    guard let loc = min_loc else { return nil }
    let cs = CGColorSpaceCreateDeviceGray()
    let cropArea = CGRect(x: loc - strip_r, y: 0, width: strip_r * 2, height: orig_len)
    let pixels_u = UnsafeMutablePointer<UInt8>.allocate(capacity: orig_len)
    let _context = CGContext(data: pixels_u, width: 1, height: orig_len, bitsPerComponent: 8, bytesPerRow: 1, space: cs, bitmapInfo: 0)
    guard let context = _context else { return nil }
    context.interpolationQuality = .high
    context.draw(image.cropping(to: cropArea)!, in: CGRect(x: 0, y: 0, width: 1, height: orig_len))
    let pixels_f = Array(UnsafeBufferPointer(start: pixels_u + 5, count: orig_len - 10)).map{ Float($0) }
    let trend = conv_reflect(pixels_f, g_ker_20)
    let highpass = Surge.sub(pixels_f, trend)
    let lowpass = conv_reflect(highpass, g_ker_3)
    let normalized = normalize(lowpass)
    return normalized.map{ Double($0) }
  }
  
  @discardableResult
  func extract_peaks(image: CGImage) -> ([Double], [Int], [Double])! {
    let _wave = extract_wave(image: image)
    guard let wave = _wave else { return nil }
    let rough_maximas = find_local_maxima(wave)
    var maximas = [Double]()
    for m in rough_maximas {
      let offset = 10
      let seg = Array(wave[m-offset ... m+offset])
      let m_refine = peak_refinement(seg, Int32(seg.count));
      if m_refine + Double(m - offset) > 0 {
        maximas.append(m_refine + Double(m - offset))
      }
    }
    var peak_distances = [Double]()
    for i in 1..<maximas.count {
      peak_distances.append(maximas[i] - maximas[i - 1])
    }
    wavelengths.append(contentsOf: peak_distances)
    return (wave, rough_maximas, maximas)
  }
  
  func start_analysis() {
    for i in 0 ..< length {
      accumulation[i] = 0
    }
    wavelengths.removeAll(keepingCapacity: false)
    min_loc = nil
  }
  
  func find_location() {
    var min = Float(1e8)
    accumulation = conv_reflect(accumulation, g_ker_1)
    for i in 10 ..< length - 10 {
      if accumulation[i] < min {
        min = accumulation[i]
        min_loc = i
      }
    }
    min_loc = Int(Float(min_loc!) / Float(length) * Float(orig_len))
    
  }
  
  func add(imageRef: CGImage) {
    let pixels_u = convert(image: imageRef)
    let conv_f = convolute(pixels_u8: pixels_u!)
    let acc = accumulate(conv_f: conv_f)
    for i in 0 ..< length {
      accumulation[i] += acc[i]
    }
  }
  
  func convolute(pixels_u8: UnsafePointer<UInt8>) -> UnsafeMutablePointer<Float> {
    let pixels_float = UnsafeMutablePointer<Float>.allocate(capacity: total)
    let result = UnsafeMutablePointer<Float>.allocate(capacity: total)
    vDSP_vfltu8(pixels_u8, 1, pixels_float, 1, vDSP_Length(total))
    vDSP_f5x5(pixels_float, vDSP_Length(length), vDSP_Length(length), kernel_float, result)
    return result
  }
  
  func convert(image: CGImage) -> UnsafeMutablePointer<UInt8>? {
    let cs = CGColorSpaceCreateDeviceGray()
    let pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: total)
    let _context = CGContext(data: pixels, width: length, height: length, bitsPerComponent: 8, bytesPerRow: length, space: cs, bitmapInfo: 0)
    guard let context = _context else { return nil }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: length, height: length))
    return pixels
  }
  
  func convert(pixels_f: UnsafeMutablePointer<Float>) -> CGImage? {
    let float_bmi = CGBitmapInfo.floatComponents.rawValue
    let cs = CGColorSpaceCreateDeviceGray()
    let r_context = CGContext(data: pixels_f, width: length, height: length, bitsPerComponent: 32,
                              bytesPerRow: length * 4, space: cs, bitmapInfo: float_bmi)
    return r_context?.makeImage()
  }
  
  func accumulate(conv_f: UnsafePointer<Float>) -> UnsafeMutablePointer<Float> {
    let result = UnsafeMutablePointer<Float>.allocate(capacity: length)
    for i in 0 ..< length {
      result[i] = 0
      for row in start_row ..< end_row {
        result[i] += abs(conv_f[i + row * length])
      }
    }
    return result
  }
  
  func find_local_maxima(_ x: [Double]) -> [Int] {
    var maximas = [Int]()
    for i in 20 ..< x.count - 20 {
      if x[i] > Surge.max(x[i-10 ... i-1])  && x[i] > Surge.max(x[i+1 ... i+10]) && x[i] > 0 {
        maximas.append(i)
      }
    }
    return maximas
  }
  
}

