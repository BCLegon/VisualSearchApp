//
//  FeaturePrint.swift
//  Search
//
//  Created by Benoît on 20/11/23.
//

import Foundation
import CoreData
import Vision
import Photos
import UIKit

// MARK: - Object definition

@objc(FeaturePrintData)
class FeaturePrintData: NSManagedObject, Identifiable {
    var id: String { identifier }
    @NSManaged var identifier: String
    @NSManaged var features: VNFeaturePrintObservation

    var featuresArray: Array<Float> {
        let array: [Float] = self.features.data.withUnsafeBytes {
            Array($0.bindMemory(to: Float.self))
        }
        return array
    }
}

// MARK: - Elementary data methods

extension FeaturePrintData {

    static func createNewItem(identifier: String, features: VNFeaturePrintObservation) -> FeaturePrintData? {
        let context = CoreDataStack.shared.viewContext

        // Check if an object with the given identifier already exists
        if let existingObject = getItemByIdentifier(identifier) {
            // Handle the case where the identifier is not unique
            print("Object with identifier '\(identifier)' already exists.")
            // You may choose to update the existing object or take other corrective actions.
            // For now, we'll print a message and exit the function.
            return nil
        }

        // Create a new FeaturePrintData instance
        let newItem = FeaturePrintData(context: context)
        newItem.identifier = identifier
        newItem.features = features

        // Save the context to persist the new item
        CoreDataStack.shared.saveContext()
        
        return newItem
    }

    static func deleteFeaturePrintByIdentifier(_ identifier: String) {
        let fetchRequest: NSFetchRequest<FeaturePrintData> = NSFetchRequest<FeaturePrintData>(entityName: "FeaturePrintData")
        fetchRequest.predicate = NSPredicate(format: "identifier == %@", identifier)

        do {
            let matchingFeaturePrints = try CoreDataStack.shared.viewContext.fetch(fetchRequest)

            for featurePrint in matchingFeaturePrints {
                CoreDataStack.shared.viewContext.delete(featurePrint)
            }
            // Save the context to persist the deletion
            CoreDataStack.shared.saveContext()
        } catch {
            print("Error deleting FeaturePrintData by identifier: \(error.localizedDescription)")
        }
    }
    
    static func getAllItems() -> [FeaturePrintData] {
        let fetchRequest: NSFetchRequest<FeaturePrintData> = NSFetchRequest<FeaturePrintData>(entityName: "FeaturePrintData")
        
        do {
            return try CoreDataStack.shared.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching items: \(error.localizedDescription)")
            return []
        }
    }
    
    static func countItems() -> Int {
        let fetchRequest: NSFetchRequest<NSNumber> = NSFetchRequest<NSNumber>(entityName: "FeaturePrintData")
        fetchRequest.resultType = .countResultType

        do {
            let countResult = try CoreDataStack.shared.viewContext.fetch(fetchRequest)
            return countResult.first?.intValue ?? 0
        } catch {
            print("Error counting items: \(error.localizedDescription)")
            return 0
        }
    }

    static func getItemByIdentifier(_ identifier: String) -> FeaturePrintData? {
        let fetchRequest: NSFetchRequest<FeaturePrintData> = NSFetchRequest<FeaturePrintData>(entityName: "FeaturePrintData")
        fetchRequest.predicate = NSPredicate(format: "identifier == %@", identifier)

        do {
            let results = try CoreDataStack.shared.viewContext.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching item by identifier: \(error.localizedDescription)")
            return nil
        }
    }
    
    static func searchSimilarItems(anchorFeaturePrint: FeaturePrintData, distanceThreshold: Float) -> [FeaturePrintData] {
//        let fetchRequest: NSFetchRequest<FeaturePrintData> = NSFetchRequest<FeaturePrintData>(entityName: "FeaturePrintData")
//        fetchRequest.predicate = NSPredicate(format: "SELF != %@ AND featurePrintDistance(features, %@) <= %@", anchorFeaturePrint, anchorFeaturePrint.features, distanceThreshold) // TODO: Does not conform to signature
//        fetchRequest.predicate = NSPredicate(format: "identifier != %@ AND featuresDistance(features, %@) <= %@", anchorFeaturePrint.identifier, anchorFeaturePrint.features, distanceThreshold)

        let fetchRequest: NSFetchRequest<FeaturePrintData> = NSFetchRequest<FeaturePrintData>(entityName: "FeaturePrintData")

        do {
//            var similarFeaturePrints = try CoreDataStack.shared.viewContext.fetch(fetchRequest)
            var allFeaturePrints = try CoreDataStack.shared.viewContext.fetch(fetchRequest)

            // Calculate distances and sort the results
//            allFeaturePrints.sort { (first: FeaturePrintData, second: FeaturePrintData) -> Bool in
//                let distanceA = featurePrintDistance(anchorFeaturePrint, first)
//                let distanceB = featurePrintDistance(anchorFeaturePrint, second)
//                return distanceA < distanceB
//            }
            allFeaturePrints.sort {
                featurePrintDistance(anchorFeaturePrint, $0) < featurePrintDistance(anchorFeaturePrint, $1)
            }

            return allFeaturePrints
        } catch {
            print("Error searching similar feature prints: \(error.localizedDescription)")
            return []
        }
    }
    
    static func featuresDistance(_ featuresA: VNFeaturePrintObservation, _ featuresB: VNFeaturePrintObservation) -> Float {
        var distance: Float = 0
        do {
            try featuresA.computeDistance(&distance, to: featuresB)
        } catch{
            print("Error computing feature distance: \(error.localizedDescription)")
        }
        return distance
    }
    
    static func featurePrintDistance(_ featurePrintA: FeaturePrintData, _ featurePrintB: FeaturePrintData) -> Float {
        var distance: Float = 0
        do {
            try featurePrintA.features.computeDistance(&distance, to: featurePrintB.features)
        } catch{
            print("Error computing feature distance: \(error.localizedDescription)")
        }
        return distance
    }
    
}

// MARK: - Convenience methods

extension FeaturePrintData {
    
    static func retrieveFeaturePrint(identifier: String, completion: @escaping (FeaturePrintData?) -> Void) {
        // Try to retrieve a feature print from the data store
        if let storedFeaturePrint = FeaturePrintData.getItemByIdentifier(identifier) {
            completion(storedFeaturePrint)
        } else {
            // If not found, compute the feature print using the identifier
            computeFeaturePrintForIdentifier(identifier) { createdFeaturePrint in
                guard let createdFeaturePrint = createdFeaturePrint else {
                    // Handle the case where feature print computation failed
                    completion(nil)
                    return
                }
                // Return the newly computed feature print
                completion(createdFeaturePrint)
            }
        }
    }
    
    static func computeFeaturePrint(image: CGImage) -> VNFeaturePrintObservation? {
        let requestHandler = VNImageRequestHandler(
                cgImage: image,
                options: [:]
        )
        do {
            let request = VNGenerateImageFeaturePrintRequest()
            #if targetEnvironment(simulator)
               request.usesCPUOnly = true
            #endif
            request.revision = VNGenerateImageFeaturePrintRequestRevision2
            request.imageCropAndScaleOption = .scaleFill
            try requestHandler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch (let message) {
            print("\(message)")
            return nil
        }
    }

//    func computeFeaturePrintForIdentifier(_ identifier: String) -> FeaturePrintData? {
////        PHAsset.localIdentifier
//        let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: PHFetchOptions()).firstObject
//        
//        if let phAsset: PHAsset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: PHFetchOptions()).firstObject {
//            getCGImage(for: phAsset) { (cgImage) in
//                guard let cgImage else {
//                    print("Failed to obtain CGImage for photo asset")
//                }
//                guard let features = self.computeFeaturePrint(image: cgImage) else {
//                    print("Failed to compute feature print")
//                }
//                let featurePrintData: FeaturePrintData = FeaturePrintData.createNewItem(identifier: identifier, features: features)
//                return featurePrintData
//            }
//        } else {
//            print("Photo asset not found")
//            return nil
//        }
//        
//    }
    
    static func computeFeaturePrintForIdentifier(_ identifier: String, completion: @escaping (FeaturePrintData?) -> Void) {
        // Fetch the PHAsset for the given identifier
        let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: PHFetchOptions()).firstObject

        guard let asset = phAsset else {
            // Handle the case where the asset is not found
            print("Photo asset not found")
            completion(nil)
            return
        }

        // Request CGImage for the asset
        getCGImage(for: asset) { cgImage in
            guard let cgImage = cgImage else {
                // Handle the case where CGImage cannot be obtained
                print("Failed to obtain CGImage")
                completion(nil)
                return
            }
            
            let features = self.computeFeaturePrint(image: cgImage)
            guard let features = features else {
                // Handle the case where feature print cannot be computed
                print("Failed to compute feature print")
                completion(nil)
                return
            }
            
            let featurePrintData = FeaturePrintData.createNewItem(identifier: identifier, features: features)
            guard let featurePrintData = featurePrintData else {
                // Handle the case where feature print cannot be added to data
                print("Failed to add feature print to data")
                completion(nil)
                return
            }
            completion(featurePrintData)
        }
    }
    
    static func getCGImage(for asset: PHAsset, completion: @escaping (CGImage?) -> Void) {
        let imageManager = PHImageManager.default()

        // Check if the asset represents an image
        guard asset.mediaType == .image else {
            completion(nil)
            return
        }

        // Image request options
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .fastFormat  // Also possible: .highQualityFormat, .opportunistic, .fastFormat

        // Perform the image request
        imageManager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: requestOptions) { (image, info) in
            guard let cgImage = image?.cgImage else {
                print("HERE")
                completion(nil)
                return
            }

            // Completion with the CGImage
            completion(cgImage)
        }
    }
}

// MARK: - Convenience methods for use with app assets

extension FeaturePrintData {
    
    static func retrieveFeaturePrintAppAsset(identifier: String, completion: @escaping (FeaturePrintData?) -> Void) {
        // Try to retrieve a feature print from the data store
        if let storedFeaturePrint = FeaturePrintData.getItemByIdentifier(identifier) {
            completion(storedFeaturePrint)
        } else {
            // If not found, compute the feature print using the identifier
            computeFeaturePrintForIdentifierAppAsset(identifier) { createdFeaturePrint in
                guard let createdFeaturePrint = createdFeaturePrint else {
                    // Handle the case where feature print computation failed
                    completion(nil)
                    return
                }
                // Return the newly computed feature print
                completion(createdFeaturePrint)
            }
        }
    }
    
    static func computeFeaturePrintForIdentifierAppAsset(_ identifier: String, completion: @escaping (FeaturePrintData?) -> Void) {
        let image = UIImage(named: identifier)
        guard let image = image else {
            // Handle the case where UIImage cannot be obtained
            print("Failed to obtain UIImage")
            completion(nil)
            return
        }
        
        let cgImage = image.cgImage
        guard let cgImage = cgImage else {
            // Handle the case where CGImage cannot be obtained
            print("Failed to obtain CGImage")
            completion(nil)
            return
        }
        
        let features = self.computeFeaturePrint(image: cgImage)
        guard let features = features else {
            // Handle the case where feature print cannot be computed
            print("Failed to compute feature print")
            completion(nil)
            return
        }
        
        let featurePrintData = FeaturePrintData.createNewItem(identifier: identifier, features: features)
        guard let featurePrintData = featurePrintData else {
            // Handle the case where feature print cannot be added to data
            print("Failed to add feature print to data")
            completion(nil)
            return
        }
        completion(featurePrintData)
    }
}
