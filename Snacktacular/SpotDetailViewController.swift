//
//  SpotDetailViewController.swift
//  Snacktacular
//
//  Created by John Gallaugher on 3/23/18.
//  Copyright © 2018 John Gallaugher. All rights reserved.
//

import UIKit
import GooglePlaces
import MapKit
import Contacts

class SpotDetailViewController: UIViewController {
    
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var addressField: UITextField!
    @IBOutlet weak var averageRatingLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var saveBarButton: UIBarButtonItem!
    @IBOutlet weak var cancelBarButton: UIBarButtonItem!
    
    var spot: Spot!
    var reviews: Reviews!
    let regionDistance: CLLocationDistance = 750 // 750m (about .5 mile)
    var locationManager: CLLocationManager!
    var currentLocation: CLLocation!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // hide keyboard if we tap outside
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        // mapView.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        
        
        if spot == nil {
            // declares spot with all empty values
            // we won't have to change this if we make changes to our spot class
            spot = Spot()
            getLocation()
            
            // editable fields should have border
            nameField.addBorder(width: 0.5, radius: 5.0, color: .black)
            addressField.addBorder(width: 0.5, radius: 5.0, color: .black)
            
        } else {
            // disable text editing fields
            nameField.isEnabled = false
            addressField.isEnabled = false
            // disabled fields should have white background
            nameField.backgroundColor = UIColor.white
            addressField.backgroundColor = UIColor.white
            
            // Save and Cancel should be hidden
            saveBarButton.title = ""
            cancelBarButton.title = ""
            
            // hide toolbar so lookup place isn't available
            navigationController?.setToolbarHidden(true, animated: true)
        }
        
        reviews = Reviews()
        
        let region = MKCoordinateRegion(center: spot.coordinate, latitudinalMeters: regionDistance, longitudinalMeters: regionDistance)
        mapView.setRegion(region, animated: true)
        
        updateUserInterface()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        reviews.loadData(spot: spot) {
            self.tableView.reloadData()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        spot.name = nameField.text!
        spot.address = addressField.text!
        switch segue.identifier ?? ""{
        case "AddReview":
            let navigationController = segue.destination as! UINavigationController
            let destination = navigationController.viewControllers.first as! ReviewTableViewController
            destination.spot = spot
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: selectedIndexPath, animated: true)
            }
        case "ShowReview":
            let destination = segue.destination as! ReviewTableViewController
            destination.spot = spot
            let selectedIndexPath = tableView.indexPathForSelectedRow!
            destination.review = reviews.reviewArray[selectedIndexPath.row]
        default:
            print("Error: did not have a segue in SpotDetailViewController prepareForSeque")
        }
    }
    
    @IBAction func textFieldEditingChanged(_ sender: UITextField) {
        saveBarButton.isEnabled = !(nameField.text == "")
        
    }
    
    @IBAction func textFieldReturnPressed(_ sender: UITextField) {
        sender.resignFirstResponder()
        spot.name = nameField.text!
        spot.address = addressField.text!
        updateUserInterface()
    }
    
    
    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(alertAction)
        present(alertController, animated: true, completion: nil)
    }
    
    func updateUserInterface() {
        nameField.text = spot.name
        addressField.text = spot.address
        updateMap()
    }
    
    func updateMap() {
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotation(spot)
        mapView.setCenter(spot.coordinate, animated: true)
    }
    
    func leaveViewController() {
        let isPresentingInAddMode = presentingViewController is UINavigationController
        if isPresentingInAddMode {
            dismiss(animated: true, completion: nil)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    
    

    @IBAction func photoButtonPressed(_ sender: UIButton) {
    }
    
    @IBAction func reviewButtonPressed(_ sender: UIButton) {
        performSegue(withIdentifier: "AddReview", sender: nil)
    }
    
    @IBAction func lookupPlacePressed(_ sender: UIBarButtonItem) {
        let autocompleteController = GMSAutocompleteViewController()
        autocompleteController.delegate = self
        present(autocompleteController, animated: true, completion: nil)
    }
    
    @IBAction func saveButtonPressed(_ sender: UIBarButtonItem) {
        spot.name = nameField.text ?? ""
        spot.address = addressField.text ?? ""
        spot.saveData{ success in
            if success {
                self.leaveViewController()
            } else {
                print("*** ERROR: Couldn't leave this view controller because data wasn't saved.")
            }
        }
    }
    
    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        leaveViewController()
    }
}

extension SpotDetailViewController: GMSAutocompleteViewControllerDelegate {

  // Handle the user's selection.
  func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
    
    spot.name = place.name ?? "unknown name"
    spot.address = place.formattedAddress ?? "unknown address"
    spot.coordinate = place.coordinate
    dismiss(animated: true, completion: nil)
    updateUserInterface()
  }

  func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
    // TODO: handle the error.
    print("Error: ", error.localizedDescription)
  }

  // User canceled the operation.
  func wasCancelled(_ viewController: GMSAutocompleteViewController) {
    dismiss(animated: true, completion: nil)
  }

  // Turn the network activity indicator on and off again.
  func didRequestAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
  }

  func didUpdateAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
    UIApplication.shared.isNetworkActivityIndicatorVisible = false
  }

}

// this is supposedly from weather gift? I don't have it in my weather gift though so idk

extension SpotDetailViewController: CLLocationManagerDelegate {
    
    func getLocation() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
    }
    
    func handlLocationAuthorizationStatus(status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .denied:
            showAlertToPrivacySettings(title: "User had not authorized location services", message: "Change your settings")
        case .restricted:
            showAlert(title: "Location services denied", message: "Parental controls might be on")
        }
    }
    
    func showAlertToPrivacySettings(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            print("Something went wrong getting the UIApplication.openSettingsURLString")
            return
        }
        let settingsActions = UIAlertAction(title: "Settings", style: .default) { value in
            UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: nil)
        alertController.addAction(settingsActions)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handlLocationAuthorizationStatus(status: status)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard spot.name == "" else {
            return
        }
        
        let geoCoder = CLGeocoder()
        var name = ""
        var address = ""
        currentLocation = locations.last
        spot.coordinate = currentLocation.coordinate
        geoCoder.reverseGeocodeLocation(currentLocation, completionHandler: {placemarks, error in
            if placemarks != nil {
                let placemark = placemarks?.last
                name = placemark?.name ?? "name unknown"
                // need to import contacts to use this code:
                if let postalAddress = placemark?.postalAddress {
                    address = CNPostalAddressFormatter.string(from: postalAddress, style: .mailingAddress)
                }
            } else {
                print("*** Error retrieving place. Error code: \(error!.localizedDescription)")
            }
            
            self.spot.name = name
            self.spot.address = address
            self.updateUserInterface()
            
        })
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get user location.")
    }
    
}
extension SpotDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return reviews.reviewArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ReviewCell", for: indexPath) as! SpotReviewsTableViewCell
        cell.review = reviews.reviewArray[indexPath.row]
        
        
        
        return cell
    }
    
    
}
