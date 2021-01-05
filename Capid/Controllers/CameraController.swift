//
//  ViewController.swift
//  Capid
//
//  Created by Shichao Yue on 7/5/18.
//  Copyright © 2018 Shichao Yue. All rights reserved.
//

import UIKit

class CameraController: UIViewController {
  
  @IBOutlet weak var imageViewer: UIView!
  @IBOutlet weak var photoFrameView: PhotoFrameOnView!
  @IBOutlet weak var distanceField: UITextField!  {didSet{distanceField?.addButtons()}}
  @IBOutlet weak var shutterCountField: UITextField! {didSet{shutterCountField?.addButtons()}}
  @IBOutlet weak var progressbar: UIProgressView!
  @IBOutlet weak var startButton: UIButton!
  
  var camera: Camera?
  var client: AppClient?
  var manager: ModelManager?
  var processor: ImageProcessor?
  var vibrator = Vibrator()
  var cropArea = CGRect(x: 520, y: 2000, width: 1280, height: 1280)
  var resize_factor = 1
  
  var default_focus = Float(0.65)
  
  override func viewDidLoad() {
    super.viewDidLoad()
    startButton.setTitle("Start!", for: .normal)
    startButton.setTitle("Analyzing", for: .disabled)
    UIApplication.shared.isIdleTimerDisabled = true
    NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    client = AppClient(log: log)
    manager = ModelManager(log: log, client: client!)
    camera = Camera(imageViewer: imageViewer, area: cropArea, updateCounter: updateCounter, resize_factor: resize_factor)
    camera!.saveMode = false
    camera?.focusTo(default_focus)
    self.processor = ImageProcessor(orig_len: Int(cropArea.width) / resize_factor, log: log, client: client!)
    self.photoFrameView.setup(dimension: camera!.dimension!, cropArea: cropArea)
  }

  func wl_to_tension(_ l_pixel: Double, _ resolution: Double) -> Double {
    let l_m = l_pixel / resolution
    let k = 2 * Double.pi / l_m
    let w = 2 * Double.pi * 144.5
    let g = 9.8
    let tension_ratio = (w * w - k * g) / (k * k * k) * 1e6
    return tension_ratio
  }
  
  func analyzeGroup(group: ImageGroup) -> String {
    
    var images = [UIImage]()
    var imageDataArray = (group.images?.allObjects as! [ImageData])
    imageDataArray = imageDataArray.sorted(by: { $0.datetime! < $1.datetime! })
    for imageData in imageDataArray {
      images.append(UIImage(data: imageData.jpeg!)!)
    }
    let (_, _, _, wavelength) = processor!.analyzeGroup(images)
    let tdr = wl_to_tension(wavelength, group.resolution)
    return "\(group.tension) \t \(tdr)\n"
  }
  
  func analyzeAllGroups() {
    var result = ""
    var all_groups = (manager!.fetch(key: "ImageGroup") as! [ImageGroup])
    for i in 0 ..< all_groups.count {
      all_groups = (manager!.fetch(key: "ImageGroup") as! [ImageGroup])
      result = result + analyzeGroup(group: all_groups[i])
      manager?.context.reset()
    }
    print(result)
  }
  
  func setNavigationbarStyle() {
    guard let bar = navigationController?.navigationBar else {return}
    bar.barTintColor = UIColor(red: 21/255, green: 101/255, blue: 192/255, alpha: 1)
    bar.isTranslucent = false
    bar.tintColor = .white
    bar.titleTextAttributes = [NSAttributedStringKey.foregroundColor : UIColor.white]
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    setNavigationbarStyle()
    camera?.startRunning()
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    camera?.stopRunning()
    vibrator.set_mode(mode: false)
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "showAnalysisSegue" {
      let controller = segue.destination as! AnalysisController
      controller.processor = processor
      controller.images = camera?.imageBuffer
      controller.resolution = 39500.0 / Double(resize_factor) * 87.0 / Double(distanceField.text!)!
      controller.distance = Double(distanceField.text!)!
      controller.currentIndex = 0
      controller.manager = manager
    } else if segue.identifier == "showStorageSegue" {
      let controller = segue.destination as! GroupsController
      controller.manager = manager
      controller.processor = processor
    }
  }

  @IBAction func shutterCustom(_ sender: Any) {
    startButton.isEnabled = false
    camera?.setQuota(Int(shutterCountField.text!)!)
  }
  @IBAction func toggleTorch(_ sender: Any) { camera?.toggleTorch() }
  @IBAction func toggleVibration(_ sender: Any) { vibrator.toggle() }
  
  @objc func keyboardWillShow(notification: NSNotification) { self.view.frame.origin.y = -280 }
  @objc func keyboardWillHide(notification: NSNotification) { self.view.frame.origin.y = 90 }
  @objc func log(_ string: String) {
    func log_string(_ string: String) {
      print(string)
    }
    if Thread.isMainThread {
      log_string(string)
    } else {
      DispatchQueue.main.async {
        log_string(string)
      }
    }
  }
  
  @objc func updateCounter(_ count: Int) {
    self.progressbar.progress = 1 - Float(count) / Float(shutterCountField.text!)!
    if count == 0 {
      startButton.isEnabled = true
      self.performSegue(withIdentifier: "showAnalysisSegue", sender: nil)
    }
  }
}

