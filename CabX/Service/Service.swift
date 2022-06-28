//
//  Service.swift
//  CabX
//
//  Created by Ayush Mall on 21/06/22.
//

import Firebase
import CoreLocation
import GeoFire
import UIKit

let DB_REF = Database.database().reference()
let REF_USERS = DB_REF.child("users")
let REF_DRIVER_LOCATIONS = DB_REF.child("driver-locations")
let REF_TRIPS = DB_REF.child("trips")
let REF_SMART_CONTRACTS = DB_REF.child("smart-contract")

struct Service {
    
    static let shared = Service()
        
    func fetchUserData(uid: String, completion: @escaping(User) -> Void) {
        REF_USERS.child(uid).observeSingleEvent(of: .value) { (snapshot) in
            guard let dictionary = snapshot.value as? [String: Any] else { return }
            let uid = snapshot.key
            let user = User(uid: uid, dictionary: dictionary)
            completion(user)
        }
    }
    
    func fetchDrivers(location: CLLocation, completion: @escaping(User) -> Void) {
        let geofire = GeoFire(firebaseRef: REF_DRIVER_LOCATIONS)

        REF_DRIVER_LOCATIONS.observe(.value) { (snapshot) in
            geofire.query(at: location, withRadius: 50).observe(.keyEntered, with: {(uid, location) in
                self.fetchUserData(uid: uid) { (user) in
                    var driver = user
                    driver.location = location
                    completion(driver)
                }
            })
        }
    }
    
    func uploadTrip(_ pickupCoordinates: CLLocationCoordinate2D, _ destinationCoordinates: CLLocationCoordinate2D, priceString: String, completion: @escaping(Error?, DatabaseReference) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let pickupArray = [pickupCoordinates.latitude, pickupCoordinates.longitude]
        let destinationArray = [destinationCoordinates.latitude, destinationCoordinates.longitude]
        
        let values = ["pickupCoordinates": pickupArray, "destinationCoordinates": destinationArray, "state": TripState.requested.rawValue, "price": priceString] as [String: Any]

        REF_TRIPS.child(uid).updateChildValues(values, withCompletionBlock: completion)
    }
    
    func observeTrips(completion: @escaping(Trip) -> Void) {
        REF_TRIPS.observe(.childAdded) { snapshot in
            guard let dictionary = snapshot.value as? [String: Any] else { return }
            
            
            let uid = snapshot.key
            let trip  = Trip(passengerUid: uid, dictionary: dictionary)
            if trip.state == .requested {
             completion(trip)
            }
        }
    }
    
    func observeTripCancelled(trip: Trip, completion: @escaping() -> Void) {
        guard trip.state != .completed else { return }
        REF_TRIPS.child(trip.passengerUid).observeSingleEvent(of: .childRemoved) { snapshot in
            completion()
        
        
        }
        
    }
    
    func acceptTrip(trip: Trip, completion: @escaping(Error?, DatabaseReference) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let values = ["driverUid": uid, "state": TripState.accepted.rawValue] as [String : Any]
        observeTrips { newTrip in
            if(newTrip.state == .requested) {
                REF_TRIPS.child(trip.passengerUid).updateChildValues(values, withCompletionBlock: completion)
                }
            }
        
        
    }
    
    func observeCurrentTrip(completion: @escaping(Trip) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        REF_TRIPS.child(uid).observe(.value) { snapshot in
            guard let dictionary = snapshot.value as? [String: Any] else { return }
            let uid = snapshot.key
            let trip = Trip(passengerUid: uid, dictionary: dictionary)
            completion(trip)
        }
    }
    
    func deleteTrip(completion: @escaping(Error?, DatabaseReference) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        REF_TRIPS.child(uid).removeValue(completionBlock: completion)
    }
    
    func updateDriverLocation(location: CLLocation) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let geofire = GeoFire(firebaseRef: REF_DRIVER_LOCATIONS)
        geofire.setLocation(location, forKey: uid)
    }
    
    func updateUserEthers(ethers: String, uid: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        REF_USERS.child(uid).child("ethers").setValue(ethers)
    }
    
    func updateTripState(trip: Trip, state: TripState, completion: @escaping(Error?, DatabaseReference) -> Void) {
        REF_TRIPS.child(trip.passengerUid).child("state").setValue(state.rawValue, withCompletionBlock: completion)
        
        if state == .completed {
            REF_TRIPS.child(trip.passengerUid).removeAllObservers()
        }
    }
    
    func updateCrypto(ethers: String) {
        REF_SMART_CONTRACTS.child("ethers").setValue(ethers)
    }
    
    func getCrypto() -> String {
        var ans: String = ""
        REF_SMART_CONTRACTS.child("ethers").observeSingleEvent(of: .value) { snapshot in
            guard let ethers = snapshot.value as? String else { return }
            ans =  ethers
        }
        return ans
    }
}

