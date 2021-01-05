//
//  AnalysisController.swift
//  Capid
//
//  Created by Shichao Yue on 9/7/18.
//  Copyright © 2018 Shichao Yue. All rights reserved.
//

import UIKit
import Charts

class XLocAssistorOnView: UIView {
  var location: CGPoint?
  var done = false
  
  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else {return}
    context.clear(rect)
    if let loc = location {
      if !done {
        context.setLineWidth(3.0)
        context.setStrokeColor(UIColor.orange.cgColor)
        context.move(to: CGPoint(x: rect.minX, y: loc.y))
        context.addLine(to: CGPoint(x: rect.maxX, y: loc.y))
        context.move(to: CGPoint(x:loc.x, y:rect.minY))
        context.addLine(to: CGPoint(x:loc.x, y:rect.maxY))
        context.strokePath()
      } else {
        context.setLineWidth(3.0)
        context.setStrokeColor(UIColor.red.cgColor)
        context.move(to: CGPoint(x:loc.x, y:rect.minY))
        context.addLine(to: CGPoint(x:loc.x, y:rect.maxY))
        context.strokePath()
      }
    }
  }
}



class AnalysisController: UIViewController, UIScrollViewDelegate {
  
  @IBOutlet weak var scrollView: UIScrollView!
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var plotView: LineChartView!
  @IBOutlet weak var logLabel: UILabel!
  @IBOutlet weak var xlocAssistor: XLocAssistorOnView!
//  @IBOutlet weak var waveLabel: UILabel!
  @IBOutlet weak var tdrLabel: UILabel!
  
  var manager: ModelManager?
  var processor: ImageProcessor?
  var images: [UIImage]?
  var resolution: Double?
  var distance: Double?
  var currentIndex: Int?
  var factor = 1.0
  let frequency = 144.5
    
  override func viewDidLoad() {
    super.viewDidLoad()
    
    plotView.legend.enabled = false
    plotView.xAxis.labelPosition = XAxis.LabelPosition.bottom
    plotView.chartDescription?.text = ""
    
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
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateImage()
    analyzeImages()
  }
  
  func analyzeImages() {
    let (hist_x, hist_v_g, x_loc, wavelength) = processor!.analyzeGroup(images!)
    xlocAssistor.location = CGPoint(x: Double(x_loc) * factor, y: 0.0)
    xlocAssistor.done = true
    xlocAssistor.setNeedsDisplay()
//    logLabel.text = "xloc: \(x_loc)"
    plotResult(hist_x, hist_v_g, wavelength)
  }
  
  func analyzeImagesWithLoc(loc: Int) {
    let (hist_x, hist_v_g, _, wavelength) = processor!.analyzeGroup(images!, loc: loc)
    plotResult(hist_x, hist_v_g, wavelength)
  }
  
  @objc func longPressHandler(recognizer: UILongPressGestureRecognizer) {
    if recognizer.state == UIGestureRecognizerState.began {
      xlocAssistor.done = false
    } else if recognizer.state == UIGestureRecognizerState.changed {
      xlocAssistor.location = recognizer.location(in: xlocAssistor)
      xlocAssistor.setNeedsDisplay()
    } else if recognizer.state == UIGestureRecognizerState.ended {
      let loc = recognizer.location(in: xlocAssistor)
      let converted_x = Int(Double(loc.x) / factor)
      xlocAssistor.location = loc
      xlocAssistor.done = true
      xlocAssistor.setNeedsDisplay()
//      logLabel.text = "new xloc: \(converted_x)"
      analyzeImagesWithLoc(loc: converted_x)
    }
  }
  
  @objc func swipeHandler(recognizer: UISwipeGestureRecognizer) {
    guard var index = currentIndex else { return }
    guard let count = self.images?.count else { return }
    if recognizer.state == UIGestureRecognizerState.ended {
      if recognizer.direction == .left {
        index += 1
      } else if recognizer.direction == .right {
        index -= 1
      }
    }
    if index >= count {
      index = 0
    } else if index < 0 {
      index = count - 1
    }
    self.currentIndex = index
    updateImage()
  }

  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
  func plotResult(_ hist_x: [Double], _ hist_v_g: [Double], _ wavelength: Double) {
    let line_entries = (0 ..< hist_v_g.count).map{(i) -> ChartDataEntry in
      return ChartDataEntry(x: hist_x[i], y: hist_v_g[i])
    }
    let rough_max = argmax(hist_v_g, hist_v_g.count)
    let peak_entries = (0 ..< 1).map{(i) -> ChartDataEntry in
      return ChartDataEntry(x: hist_x[rough_max], y: hist_v_g[rough_max])
    }
    let line_set = LineChartDataSet(values: line_entries, label: nil)
    line_set.drawCirclesEnabled = false
    line_set.lineWidth = 5
    let peak_set = LineChartDataSet(values: peak_entries, label: nil)
    peak_set.lineWidth = 0
    peak_set.circleRadius = 8
    peak_set.circleColors = [UIColor.red]
    self.plotView.data = LineChartData(dataSets: [line_set, peak_set])
    let ratio = wl_to_tension(wavelength)
//    waveLabel.text = String(format: "%.1f pixels", wavelength)
    tdrLabel.text = String(format: "%.1f mN/m", ratio)
  }
  
  
  func wl_to_tension(_ l_pixel: Double) -> Double {
    let l_m = l_pixel / resolution!
    let k = 2 * Double.pi / l_m
    let w = 2 * Double.pi * frequency
    let g = 9.8
    let tension_ratio = (w * w - k * g) / (k * k * k) * 1e6
    return tension_ratio
  }
  
  func updateImage() {
    guard let image = images?[currentIndex!] else { return }
    imageView.image = image
    factor = Double(scrollView.bounds.width) / Double(image.cgImage!.width)
  }
  
  @IBAction func saveImages(_ sender: Any) {
    let configController = UIAlertController(
      title: "Save Image Group",
      message: "",
      preferredStyle: .alert
    )
    let saveAction = UIAlertAction(title: "Save", style: .default) { [unowned self] action in
      guard let tension = Double(configController.textFields![0].text!) else { return }
      guard var density = Double(configController.textFields![1].text!) else { return }
      guard let resolution = Double(configController.textFields![2].text!) else { return }
      guard let frequency = Double(configController.textFields![3].text!) else { return }
      density /= 25
      let name = configController.textFields?[4].text
      self.manager?.saveUIImages(self.images!, ten: tension, den: density, res: resolution, fre: frequency, dist: self.distance!, name: name)
      self.navigationController?.popViewController(animated: true)
    }
    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
    configController.addTextField(configurationHandler: nil)
    configController.textFields?[0].placeholder = "Surface Tension"
    configController.textFields?[0].keyboardType = .decimalPad
    configController.addTextField(configurationHandler: nil)
    configController.textFields?[1].text = "25.00"
    configController.textFields?[1].placeholder = "Density"
    configController.textFields?[1].keyboardType = .decimalPad
    configController.addTextField(configurationHandler: nil)
    configController.textFields?[2].text = "\(resolution!)"
    configController.textFields?[2].placeholder = "Resolution"
    configController.textFields?[2].keyboardType = .decimalPad
    configController.addTextField(configurationHandler: nil)
    configController.textFields?[3].text = "\(frequency)"
    configController.textFields?[3].placeholder = "Frequency"
    configController.textFields?[3].keyboardType = .decimalPad
    configController.addTextField(configurationHandler: nil)
    configController.textFields?[4].placeholder = "name"
    configController.addAction(saveAction)
    configController.addAction(cancelAction)
    present(configController, animated: true, completion: nil)
  }
}
