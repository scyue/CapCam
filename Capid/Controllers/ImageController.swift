//
//  ImageController.swift
//  Capid
//
//  Created by Shichao Yue on 7/30/18.
//  Copyright © 2018 Shichao Yue. All rights reserved.
//

import UIKit
import CoreData
import Charts

class ImageController: UIViewController, UIScrollViewDelegate {
  
  var images: [UIImage]?
  var current_index: Int?
  var group: ImageGroup?
  
  var manager: ModelManager?
  var analyzer: TensionAnalyzer?
  
  var factor = 1.0
  
  @IBOutlet weak var scrollView: UIScrollView!
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var plotView: LineChartView!
  @IBOutlet weak var logLabel: UILabel!
  @IBOutlet weak var aimAssistor: AimAssistorOnView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.navigationItem.title = self.group?.shortDescription()
    
    scrollView.delegate = self
    scrollView.minimumZoomScale = 1.0
    scrollView.maximumZoomScale = 6.0
    
    let lp_recognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressHandler))
    lp_recognizer.minimumPressDuration = 0.3
    scrollView.addGestureRecognizer(lp_recognizer)
    
    let swipe_left = UISwipeGestureRecognizer(target: self, action: #selector(swipeHandler))
    swipe_left.direction = .left
    scrollView.addGestureRecognizer(swipe_left)
    let swipe_right = UISwipeGestureRecognizer(target: self, action: #selector(swipeHandler))
    swipe_right.direction = .right
    scrollView.addGestureRecognizer(swipe_right)

    plotView.legend.enabled = false
    plotView.xAxis.labelPosition = XAxis.LabelPosition.bottom
    plotView.chartDescription?.text = ""
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  override func viewWillAppear(_ animated: Bool) {
    updateImage()
  }
  
  func updateImage() {
    guard let image = images?[current_index!] else { return }
    let data = image.getPixelValue()
    factor = Double(scrollView.bounds.width) / Double(image.cgImage!.width)
    analyzer = TensionAnalyzer(data!, group!, image.cgImage!.width, image.cgImage!.height, manager!.client!)
    imageView.image = image
    self.plotView.data = LineChartData(dataSets: [])
    self.aimAssistor.clear()
    log("Swiped to next image")
  }
  
  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return imageView
  }
  
  @objc func longPressHandler(recognizer: UILongPressGestureRecognizer) {
    if recognizer.state == UIGestureRecognizerState.began {
      aimAssistor.line = nil
    } else if recognizer.state == UIGestureRecognizerState.changed {
      aimAssistor.location = recognizer.location(in: aimAssistor)
      aimAssistor.setNeedsDisplay()
    } else if recognizer.state == UIGestureRecognizerState.ended {
      var loc = recognizer.location(in: aimAssistor)
      if aimAssistor.prev_location == nil {
        aimAssistor.prev_location = loc
      } else {
        guard let prev_loc = aimAssistor.prev_location else { return }
        loc.x = prev_loc.x
        aimAssistor.line = (prev_loc, loc)
        plotAnalyzer(line: aimAssistor.line!)
        aimAssistor.prev_location = nil
      }
      aimAssistor.location = nil
      aimAssistor.setNeedsDisplay()
    } else if recognizer.state == UIGestureRecognizerState.cancelled {
      
    }
  }
  
  @objc func swipeHandler(recognizer: UISwipeGestureRecognizer) {
    guard var index = current_index else { return }
    guard let count = self.images?.count else { return }
    if recognizer.state == UIGestureRecognizerState.ended {
      if recognizer.direction == .left {
        index += 1
      } else if recognizer.direction == .right {
        index -= 1
      }
    }
    if index >= count {
      index = count - 1
    } else if index < 0 {
      index = 0
    }
    self.current_index = index
    updateImage()
  }
  
  func plotAnalyzer(line: (CGPoint, CGPoint)) {
    guard let result = analyzer?.analyze_line(from: line.0, to: line.1, factor: factor) else {
      self.plotView.data = LineChartData(dataSets: [])
      log("AppServer is down!!!")
      return
    }
    let line_entries = (0 ..< result.line.count).map{(i) -> ChartDataEntry in
      return ChartDataEntry(x: Double(i), y: result.line[i])
    }
    let peak_entries = (0 ..< result.peaks.count).map{(i) -> ChartDataEntry in
      return ChartDataEntry(x: Double(result.peaks[i]), y: result.line[result.peaks[i]])
    }
    let line_set = LineChartDataSet(values: line_entries, label: nil)
    line_set.drawCirclesEnabled = false
    let peak_set = LineChartDataSet(values: peak_entries, label: nil)
    peak_set.lineWidth = 0
    peak_set.circleRadius = 3
    peak_set.circleColors = [UIColor.red]
    self.plotView.data = LineChartData(dataSets: [line_set, peak_set])
    self.log(result.description())
  }
  
  @objc func log(_ string: String) {
    func log_string(_ string: String) {
      self.logLabel.text = string
      self.logLabel.setNeedsDisplay()
    }
    if Thread.isMainThread {
      log_string(string)
    } else {
      DispatchQueue.main.async {
        log_string(string)
      }
    }
  }
}
