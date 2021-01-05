//
//  GalleryViewController.swift
//  Capid
//
//  Created by Shichao Yue on 7/30/18.
//  Copyright © 2018 Shichao Yue. All rights reserved.
//

import UIKit
import CoreData

class GalleryCell: UICollectionViewCell {
  @IBOutlet weak var imageView: UIImageView!
}

private let reuseIdentifier = "GalleryCell"

class GalleryViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
  
  var manager: ModelManager?
  var imageGroup: ImageGroup?
  var processor: ImageProcessor?
  var images = [UIImage]()
  
  @IBOutlet weak var collectionView: UICollectionView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
    layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    layout.itemSize = CGSize(width: 124, height: 124)
    layout.minimumInteritemSpacing = 1
    layout.minimumLineSpacing = 1
    collectionView?.collectionViewLayout = layout
    collectionView.delegate = self
    collectionView.dataSource = self
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    images.removeAll(keepingCapacity: true)
    var imageDataArray = (imageGroup?.images?.allObjects as! [ImageData])
    imageDataArray = imageDataArray.sorted(by: { $0.datetime! < $1.datetime! })
    for imageData in imageDataArray {
      images.append(UIImage(data: imageData.jpeg!)!)
    }
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
   // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "showImageSegue" {
      let cell = sender as! GalleryCell
      let index = collectionView!.indexPath(for: cell)
      let controller = segue.destination as! ImageController
      controller.images = images
      controller.current_index = index?.item
      controller.group = imageGroup
      controller.manager = manager
    } else if segue.identifier == "showAnalysisSegue" {
      let controller = segue.destination as! AnalysisController
      controller.processor = processor
      controller.images = images
      controller.resolution = imageGroup!.resolution
      controller.currentIndex = 0
      controller.manager = manager
    }
  }
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return images.count
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! GalleryCell
    cell.imageView.image = images[indexPath.item]
    return cell
  }
  
  @IBAction func deleteGroup(_ sender: Any) {
    let alert = UIAlertController(title: "Alert", message: "Confirm to delete?", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "Delete!", style: .destructive, handler: { _ in
      self.manager?.deleteGroup(group: self.imageGroup!)
      self.navigationController?.popViewController(animated: true)
    }))
    self.present(alert, animated: true, completion: nil)
  }
  
  @IBAction func sendGroupToServer(_ sender: Any) {
    manager?.sendGroupOfImages(group: imageGroup!)
  }
}
