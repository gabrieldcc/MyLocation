//
//  ViewController.swift
//  MyLocations
//
//  Created by Gabriel de Castro Chaves on 21/10/22.
//

import UIKit
import CoreLocation
import CoreData

final class CurrentLocationViewController: UIViewController {
    
    //MARK: - Var
    private var location: CLLocation?
    private var updatingLocation = false
    private var lastLocationError: Error?
    private var placemark: CLPlacemark?
    private var performingReverseGeocoding = false
    private var lastGeocodingError: Error?
    private var timer: Timer?
    var managedObjectContext: NSManagedObjectContext!
    
    //MARK: - Let
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    //MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        updateLabels()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.isNavigationBarHidden = false
    }
    
    //MARK: - IBOutlets
    @IBOutlet weak private var messageLabel: UILabel!
    @IBOutlet weak private var latitudeLabel: UILabel!
    @IBOutlet weak private var longitudeLabel: UILabel!
    @IBOutlet weak private var addressLabel: UILabel!
    @IBOutlet weak private var tagButton: UIButton!
    @IBOutlet weak private var getButton: UIButton!
    
    //MARK: - Functions
    func string(from placemark: CLPlacemark) -> String {
        
        var line1 = ""
        
        if let tmp = placemark.subThoroughfare {
            line1 += tmp + " "
        }
        
        if let tmp = placemark.thoroughfare {
            line1 += tmp }
        
        var line2 = ""
        if let tmp = placemark.locality {
            line2 += tmp + " "
        }
        if let tmp = placemark.administrativeArea {
            line2 += tmp + " "
        }
        if let tmp = placemark.postalCode {
            line2 += tmp }
        return line1 + "\n" + line2
    }
    
    private func configureGetButton() {
        if updatingLocation {
            getButton.setTitle("Stop", for: .normal)
        } else {
            getButton.setTitle("Get My Location", for: .normal)
        }
    }
    
    private func startLocationManager() {
        if CLLocationManager.locationServicesEnabled() {
            
            timer = Timer.scheduledTimer(
                  timeInterval: 60,
                  target: self,
                  selector: #selector(didTimeOut),
                  userInfo: nil,
                  repeats: false)
            
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
            updatingLocation = true
        }
    }
    
    private func stopLocationManager() {
        if updatingLocation {
            locationManager.stopUpdatingLocation()
            guard let timer = timer else { return }
            timer.invalidate()
            locationManager.delegate = nil
            updatingLocation = false
        }
    }
    
    private func updateLabels() {
        if let location = location {
            latitudeLabel.text = String(format: "%.8f",
                                        location.coordinate.latitude)
            longitudeLabel.text = String(format: "%.8f",
                                         location.coordinate.longitude)
            tagButton.isHidden = false
            messageLabel.text = ""
        } else {
            let statusMessage: String
            if let error = lastLocationError as NSError? {
                if error.domain == kCLErrorDomain && error.code ==
                    CLError.denied.rawValue {
                    statusMessage = "Location Services Disabled"
                } else {
                    statusMessage = "Error Getting Location"
                }
            } else if !CLLocationManager.locationServicesEnabled() {
                statusMessage = "Location Services Disabled"
            } else if updatingLocation {
                statusMessage = "Searching..."
            } else {
                statusMessage = "Tap 'Get My Location' to Start"
            }
            messageLabel.text = statusMessage
        }
        configureGetButton()
        
        if let placemark = placemark {
            addressLabel.text = string(from: placemark)
        } else if performingReverseGeocoding {
            addressLabel.text = "Searching for Address..."
        } else if lastGeocodingError != nil {
            addressLabel.text = "Error Finding Address"
        } else {
            addressLabel.text = "No Address Found"
        }
    }
    
    
    private func showLocationServicesDeniedAlert() {
        let alert = UIAlertController(
            title: "Location Services Disabled",
            message: "Please enable location services for this app in Settings.",
            preferredStyle: .alert)
        
        let okAction = UIAlertAction(
            title: "OK",
            style: .default,
            handler: nil)
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    @objc func didTimeOut() {
      print("*** Time out")
      if location == nil {
        stopLocationManager()
        lastLocationError = NSError(
          domain: "MyLocationsErrorDomain",
          code: 1,
          userInfo: nil)
        updateLabels()
      }
    }
    
    // MARK: - IBActions
    @IBAction func getLocation() {
        let authStatus = locationManager.authorizationStatus
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        
        if authStatus == .denied || authStatus == .restricted {
            showLocationServicesDeniedAlert()
            return
        }
        
        if updatingLocation {
            stopLocationManager()
        } else {
            location = nil
            lastLocationError = nil
            startLocationManager()
        }
        
        lastLocationError = nil
        updateLabels()
    }
    
}

//MARK: - CLLocationManagerDelegate
extension CurrentLocationViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
        if (error as NSError).code == CLError.locationUnknown.rawValue { return }
        lastLocationError = error
        stopLocationManager()
        updateLabels()
        print("didFailWithError \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        location = newLocation
        print("didUpdateLocations \(newLocation)")
        
        if newLocation.timestamp.timeIntervalSinceNow < -5 {
            return
            
        }
        
        if newLocation.horizontalAccuracy < 0 {
            return
        }
        
        // New section #1
        var distance = CLLocationDistance(Double.greatestFiniteMagnitude)
        if let location = location {
            distance = newLocation.distance(from: location)
        }
        // End of new section #1
        if location == nil || location!.horizontalAccuracy >
            newLocation.horizontalAccuracy {
            
            if newLocation.horizontalAccuracy <=
                locationManager.desiredAccuracy {
                
                // New section #2
                if distance > 0 {
                    performingReverseGeocoding = false
                }
                // End of new section #2
            }
            if !performingReverseGeocoding {
                
            }
            updateLabels()
            // New section #3
        } else if distance < 1 {
            let timeInterval =
            newLocation.timestamp.timeIntervalSince(location!.timestamp)
            if timeInterval > 10 {
                print("*** Force done!")
                stopLocationManager()
                updateLabels()
            }
            // End of new sectiton #3
        }
    
        if !performingReverseGeocoding {
            print("*** Going to geocode")
            performingReverseGeocoding = true
            geocoder.reverseGeocodeLocation(newLocation) { placemarks,
                error in
                self.lastGeocodingError = error
                if error == nil, let places = placemarks, !places.isEmpty {
                    self.placemark = places.last!
                } else {
                    self.placemark = nil
                }
                self.performingReverseGeocoding = false
                self.updateLabels()
            }
        }
    }
    
    //MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "TagLocation" {
            let controller = segue.destination as? LocationDetailsViewController
            guard let location = location else { return }
            controller?.coordinate = location.coordinate
            controller?.placemark = placemark
            controller?.managedObjectContext = managedObjectContext
        }
    }
    
}

