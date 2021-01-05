//
//  ModelManager.swift
//  Capid
//
//  Created by Shichao Yue on 7/29/18.
//  Copyright © 2018 Shichao Yue. All rights reserved.
//

import UIKit
import CoreData


class ModelManager {
  let context : NSManagedObjectContext!
  var currentGroup: ImageGroup?
  
  var resolution = Double(19750.0)
  var tension = Double(0.0)
  var density = Double(0.0)
  var frequency = Double(144.5)
  var counter = 0
  
  var client: AppClient?

  var log: (String) -> Void?
  
  init(log: @escaping (String) -> Void, client: AppClient) {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    self.log = log
    self.client = client
    context = appDelegate.persistentContainer.viewContext
  }
  
  func save() {
    do {
      try context.save()
    } catch {
      print("Saving Error: \(error)")
    }
    currentGroup = nil
  }
  
  func saveUIImages(_ images: [UIImage], ten: Double, den: Double, res: Double, fre: Double, dist: Double, name: String?) {
    let group = ImageGroup(context: context)
    group.resolution = res
    group.density = den
    group.tension = ten
    group.frequency = fre
    group.name = name
    group.distance = dist
    group.datetime = Date()
    for image in images {
      let data = UIImageJPEGRepresentation(image, 1.0)!
      let imageData = ImageData(context: context)
      imageData.group = currentGroup
      imageData.jpeg = data
      imageData.datetime = Date()
      group.addToImages(imageData)
    }
    save()
  }
  
  func newImageGroup() {
    currentGroup = ImageGroup(context: context)
    currentGroup!.resolution = resolution
    currentGroup!.density = density
    currentGroup!.tension = tension
    currentGroup!.frequency = frequency
    currentGroup!.datetime = Date()
    counter = 0
  }
  
  func saveImage(_ image: UIImage) {
    let data = UIImageJPEGRepresentation(image, 1.0)!
    let imageData = ImageData(context: context)
    imageData.group = currentGroup
    imageData.jpeg = data
    imageData.datetime = Date()
    currentGroup!.addToImages(imageData)
    counter += 1
//    log("\(currentGroup!.hash): \(counter) Images!")
  }
  
  func sendGroupOfImages(group: ImageGroup) {
    client?.send_tag("grp")
    client?.send_data(group.datetime!.ts(), with_count: false)
    client?.send_data(group.frequency, with_count: false)
    client?.send_data(group.resolution, with_count: false)
    client?.send_data(group.tension, with_count: false)
    client?.send_data(group.density, with_count: false)
    client?.send_data(group.images!.count, with_count: false)
    for item in group.images! {
      if let image = item as? ImageData {
        client?.send_data(image.jpeg)
      }
    }
  }
  
  func fetch(key: String) -> [NSManagedObject]? {
    let request = NSFetchRequest<NSFetchRequestResult>(entityName: key)
    if key == "ImageGroup" {
      let sort = NSSortDescriptor(key: #keyPath(ImageGroup.datetime), ascending: true)
      let predicate = NSPredicate(format: "images.@count > 0")
      request.sortDescriptors = [sort]
      request.predicate = predicate
    } else if key == "ImageData" {
      print("here")
      let sort = NSSortDescriptor(key: #keyPath(ImageData.datetime), ascending: true)
      request.sortDescriptors = [sort]
    }
    request.returnsObjectsAsFaults = false
    do {
      let result = try context.fetch(request)
      return result as? [NSManagedObject]
    } catch {
      print("Failed: \(error)")
    }
    return nil
  }
  
  func deleteGroup(group: ImageGroup) {
    for images in group.images! {
      let managedObjectData:NSManagedObject = images as! NSManagedObject
      context.delete(managedObjectData)
    }
    context.delete(group as NSManagedObject)
    do {
      try context.save()
    } catch let error as NSError {
      print("Delete group error : \(error) \(error.userInfo)")
    } 
  }
  
  func deleteAll() {
    let groups = fetch(key: "ImageGroup") as! [ImageGroup]
    for group in groups {
      deleteGroup(group: group)
    }
  }
}

