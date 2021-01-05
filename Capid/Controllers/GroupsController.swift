//
//  GroupsController.swift
//  Capid
//
//  Created by Shichao Yue on 7/29/18.
//  Copyright © 2018 Shichao Yue. All rights reserved.
//

import UIKit
import CoreData

class GroupCellPrototype: UITableViewCell {
  @IBOutlet weak var timeLabel: UILabel!
  @IBOutlet weak var descriptionLabel: UILabel!
}


class GroupsController: UIViewController, UITableViewDelegate, UITableViewDataSource {
  
  let cell_id = "group_cell"
  
  var data: [ImageGroup]?
  var manager: ModelManager?
  var processor: ImageProcessor?
  
  @IBOutlet weak var tableView: UITableView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.delegate = self
    tableView.dataSource = self
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    data = (manager!.fetch(key: "ImageGroup") as! [ImageGroup])
    self.tableView.reloadData()
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = self.tableView.dequeueReusableCell(withIdentifier: cell_id) as! GroupCellPrototype
    let imageGroup = data![indexPath.row]
    cell.timeLabel.text = imageGroup.timeString()
    cell.descriptionLabel.text = imageGroup.description()
    return cell
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return data!.count
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    //Change the selected background view of the cell.
    tableView.deselectRow(at: indexPath, animated: true)
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    let cell = sender as! GroupCellPrototype
    let index = tableView.indexPath(for: cell)
    let imageGroup = data![index!.row]
    if segue.identifier == "showGallerySegue" {
      let controller = segue.destination as! GalleryViewController
      controller.manager = manager
      controller.imageGroup = imageGroup
      controller.processor = processor
    }
  }
  
  @IBAction func sendAllGroups(_ sender: Any) {
    for group in data! {
      if group.datetime! > Date.init(timeIntervalSince1970: 1537138380.0) {
        manager?.sendGroupOfImages(group: group)
      }
    }
  }
  
  @IBAction func deleteAllGroups(_ sender: Any) {
    let alert = UIAlertController(title: "Alert", message: "Confirm to delete?", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "Delete!", style: .destructive, handler: { _ in
      self.manager?.deleteAll()
      self.navigationController?.popViewController(animated: true)
    }))
    self.present(alert, animated: true, completion: nil)
  }
}
