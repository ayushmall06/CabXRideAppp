//
//  HomeController.swift
//  CabX
//
//  Created by Ayush Mall on 19/06/22.
//

import UIKit
import Firebase
import MapKit
import BRYXBanner

private let reuseIdentifier = "LocationCell"
private let annotationIdentifier = "DriverAnnotation"

private enum ActionButtonConfiguration {
    case showMenu
    case dismissActionView
    
    init() {
        self = .showMenu
    }
}

private enum AnnotationType: String {
    case pickup
    case destination
}

class HomeController: UIViewController {
    
    // MARK: - Properties
    private let mapView = MKMapView()
    private let locationManager = LocationHandler.shared.locationManager
    private let inputActivationView = LocationInputActivationView()
    private let locationInputView = LocationInputView()
    private let tableView = UITableView()
    private var searchResults = [MKPlacemark]()
    private var route: MKRoute?
    private let rideActionView = RideActionView()
    private var priceString: String!
    
    private var actionButtonConfig = ActionButtonConfiguration()
    
    
    private var user: User? {
        didSet {
            locationInputView.user = user
            
            if user?.accountType == .passenger {
                print("DEBUG: User is passenger")
                fetchDrivers()
                configureLocationInputActivationView()
                observeCurrentTrip()
            } else {
                print("DEBUG: User is Driver")
                observeTrips()
            }
        }
    }
    
    private var trip: Trip? {
        didSet{
            print("DEBUG: Show pickup passenger controller...")
            guard let user = user else { return }
            if user.accountType == .driver {
                guard let trip = trip else { return }
                let controller = PickupController(trip: trip)
                controller.modalPresentationStyle = .fullScreen
                controller.delegate = self
                self.present(controller, animated: true, completion: nil)
                
            } else {
                print("DEBUG: SHow ride action view for accepted trip")
            }
        }
    }
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = .black
        
        button.setImage(UIImage(systemName: "line.3.horizontal")?.withRenderingMode(.alwaysOriginal), for: .normal)
        button.addTarget(self, action: #selector(actionButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private final let locationInputHeight: CGFloat = 200
    private final let rideActionViewHeight: CGFloat = 320
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
//        signOut()
        checkIfUserIsLoggedIn()
        enableLocationServices()
        
    }
    
    // MARK: - Selectors
    
    @objc func actionButtonPressed() {
        switch actionButtonConfig {
        case .showMenu:
            print("DEBUG: Handle Show Menu")
        case .dismissActionView:
            removeAnnotationsandOverlays()
            mapView.showAnnotations(mapView.annotations, animated: true)

            UIView.animate(withDuration: 0.3) {
                self.inputActivationView.alpha = 1
                self.configureActionButton(config: .showMenu)
                self.animateRideActionView(shouldShow: false)
            }

        }
    }
    
    // MARK: - API
    
    func observeCurrentTrip() {
        Service.shared.observeCurrentTrip { trip in
            self.trip = trip
            
            guard let state = trip.state else { return }
            guard let driverUid = trip.driverUid else { return }
            
            switch state {
            case .requested:
                break
            case .accepted:
                self.shouldPresentLoadingView(false)
                
                
                var amount: Double = NSString(string: self.priceString).doubleValue * 0.3
                var amountString = String(format: "%f", arguments: [amount])
                print("DEBUG: Amount: \(amountString)")
                
                EthTransfer.shared.sendCryptoToContract(fromUid: trip.passengerUid, amount: amount)
                self.removeAnnotationsandOverlays()
                
                
                
                let bannerString = "\(String(describing: amountString))ETH sent to Smart Contract"
                
                EthTransfer.shared.sendEthers(fromWalletAddress: "4a9f854bdf3d01a34ea220d6990e2147893e0fcf", toWalletAddress: "7fe406ddd93b49678cf2949d2aaa9c5776775454", amount: amountString)
                
                let banner = Banner(title: "Transaction Status", subtitle: bannerString, backgroundColor: UIColor(red:153.00/255.0, green:0.0/255.0, blue:0.0/255.0, alpha:1.000))
                banner.dismissesOnTap = true
                banner.show(duration: 10.0)
                
                self.zoomForActiveTrip(withDriverUid: trip.driverUid!)
                
                Service.shared.fetchUserData(uid: driverUid) { driver in
                    self.animateRideActionView(shouldShow: true, config: .tripAccepted, user: driver)
                }
            case .driverArrived:
                self.rideActionView.config = .driverArrived
            case .inProgress:
                self.rideActionView.config = .tripProgress
                break
            case .arrivedAtDestination:
                self.rideActionView.config = .endTrip
                
                let amount = NSString(string: trip.price).doubleValue * 0.7
                EthTransfer.shared.sendCryptoFromContract(toUid: trip.driverUid!, amount: amount)
                let amountString = String(format: "%f", arguments: [amount])
                let bannerString = "\(String(describing: amountString))ETH sent to Smart Contract"
                EthTransfer.shared.sendEthers(fromWalletAddress: "4a9f854bdf3d01a34ea220d6990e2147893e0fcf",toWalletAddress: "7fe406ddd93b49678cf2949d2aaa9c57", amount: amountString)
                let banner = Banner(title: "Transaction Status", subtitle: bannerString, backgroundColor: UIColor(red:153.00/255.0, green:0.0/255.0, blue:0.0/255.0, alpha:1.000))
                banner.dismissesOnTap = true
                banner.show(duration: 10.0)
            case .completed:
                
                Service.shared.deleteTrip { err, ref in
                    self.animateRideActionView(shouldShow: false)
                    self.centerMapOnUserLocation()
                    self.configureActionButton(config: .showMenu)
                    self.presentAlertController(withTitle: "Trip Completed", message: "We hope you enjoyed your trip!")
                    self.inputActivationView.alpha = 1
                }
            }
        }
    }
    
    func checkIfUserIsLoggedIn() {
        
        if Auth.auth().currentUser?.uid == nil {
            DispatchQueue.main.async {
                let nav = UINavigationController(rootViewController: LoginController())
                nav.modalPresentationStyle = .fullScreen
                
                self.present(nav, animated: true, completion: nil)
            }
            
        } else {
            
            configure()
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("DEBUG: Error signing out...")
        }
    }
    
    func startTrip() {
        guard let trip = self.trip else { return }
        Service.shared.updateTripState(trip: trip, state: .inProgress) { err, ref in
            self.rideActionView.config = .tripProgress
            self.removeAnnotationsandOverlays()
            self.mapView.addAnnotationAndSelect(forCoordinate: trip.destinationCoordinates)
            
            let placemark = MKPlacemark(coordinate: trip.destinationCoordinates)
            let mapItem = MKMapItem(placemark: placemark)
            
            self.setCustomRegion(withType: .destination, coordinates: trip.destinationCoordinates)
            
            self.generatePolyline(toDestination: mapItem)
            
            self.mapView.zoomToFit(annotations: self.mapView.annotations)
        }
    }
    
    func fetchUserData() {
        
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        Service.shared.fetchUserData(uid: currentUid) { user in
            self.user = user
        }
    }
    
    func fetchDrivers() {
        guard let location =  locationManager?.location else { return }
        Service.shared.fetchDrivers(location: location) { driver in
            guard let coordinate = driver.location?.coordinate else { return }
            let annotation = DriverAnnotation(uid: driver.uid, coordinate: coordinate)
            self.mapView.addAnnotation(annotation)

            var driverIsVisible: Bool {
                return self.mapView.annotations.contains { annotation -> Bool in
                    guard let driverAnno = annotation as? DriverAnnotation else { return false }
                    if driverAnno.uid == driver.uid {
                        driverAnno.updateAnnotationPosition(withCoordinate: coordinate)
                        self.zoomForActiveTrip(withDriverUid: driver.uid)
                        return true
                    }
                    return false
                }
            }

            if !driverIsVisible {
                self.mapView.addAnnotation(annotation)
            }
        }
    }
    
    func observeTrips() {
        Service.shared.observeTrips { trip in
            self.trip = trip
        }
    }
    
    
    // MARK: - Helper Functions
    
    func configure() {
        
        configureUI()
        fetchUserData()
        
    }
    
    func configureUI() {
        configureMapView()
        configureRideActionView()
        
        view.addSubview(actionButton)
        actionButton.anchor(top: view.safeAreaLayoutGuide.topAnchor, left: view.leftAnchor, paddingTop: 16, paddingLeft: 16, width: 30, height: 40)
        
        
        
        
        configureTableView()
        

    }
    
    func configureLocationInputActivationView() {
        view.addSubview(inputActivationView)
        inputActivationView.centerX(inView: view)
        inputActivationView.setDimensions(height: 50, width: view.frame.width - 64)
        inputActivationView.anchor(top: actionButton.bottomAnchor, paddingTop: 16)
        inputActivationView.alpha = 0
        inputActivationView.delegate = self
        
        UIView.animate(withDuration: 2, delay: 0) {
            self.inputActivationView.alpha = 1
        }
    }
    
    func configureMapView() {
        view.addSubview(mapView)
        mapView.frame = view.frame

        
        view.addSubview(mapView)
        mapView.frame = view.frame
        
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.delegate = self
    }
    
    func configureLocationInputView() {
        locationInputView.delegate = self
        view.addSubview(locationInputView)
        locationInputView.anchor(top: view.topAnchor,
                                 left:  view.leftAnchor,
                                 right: view.rightAnchor,
                                 height: locationInputHeight)
        locationInputView.alpha = 0
        
        UIView.animate(withDuration: 0.5, delay: 0) {
            self.locationInputView.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                //print("DEBUG: Present table view")
                self.tableView.frame.origin.y = self.locationInputHeight
            }
        }
    }
    
    func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(LocationCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.rowHeight = 60
        let height = view.frame.height - locationInputHeight
        tableView.frame = CGRect(x: 0,
                                 y: view.frame.height,
                                 width: view.frame.width,
                                 height: height)
        tableView.tableFooterView = UIView()
        
        view.addSubview(tableView)
    }
    
    func dismissLocationView(completion: ((Bool) -> Void)? = nil) {
        UIView.animate(withDuration: 0.3, animations: {
            self.locationInputView.alpha = 0
            self.tableView.frame.origin.y = self.view.frame.height
            self.locationInputView.removeFromSuperview()
           
        }, completion: completion)
    }
    
    fileprivate func configureActionButton(config: ActionButtonConfiguration) {
        switch config {
        case .showMenu:
            actionButton.setImage(UIImage(systemName: "line.3.horizontal"), for: .normal)
            actionButton.tintColor = .black
            actionButtonConfig = .showMenu
        case .dismissActionView:
            actionButton.setImage(UIImage(systemName: "arrow.backward"), for: .normal)
            actionButtonConfig = .dismissActionView
            
            
            
        }
    }
    
    func configureRideActionView() {
        view.addSubview(rideActionView)
        rideActionView.delegate = self
        rideActionView.frame = CGRect(x: 0,
                                      y: view.frame.height,
                                      width: view.frame.width,
                                      height: rideActionViewHeight)
    }
    
    func animateRideActionView(shouldShow: Bool, destination: MKPlacemark? = nil, config: RideActionViewConfiguration? = nil, user: User? = nil) {
        let yOrigin = shouldShow ? self.view.frame.height - self.rideActionViewHeight :
        self.view.frame.height
        
        UIView.animate(withDuration: 0.3) {
            self.rideActionView.frame.origin.y = yOrigin
        }
        
        if shouldShow {
            guard let config = config else { return }
            
            
            if let destination = destination  {
                rideActionView.destination = destination
            }
            
            if let user = user {
                rideActionView.user = user
            }
            rideActionView.config = config
            
        }
        
        
    }
}
    



// MARK: - MapViewHelper Functions

private extension HomeController {
    func searchBy(naturalLanguageQuery: String, completion: @escaping([MKPlacemark])-> Void) {
        var results = [MKPlacemark]()
        
        let request  = MKLocalSearch.Request()
        request.region = mapView.region
        request.naturalLanguageQuery = naturalLanguageQuery
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else { return }
            
            response.mapItems.forEach({item in
                results.append(item.placemark)
            })
            
            completion(results)
        }
    }
    
    func generatePolyline(toDestination destination: MKMapItem) {

        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = destination
        request.transportType = .automobile

        let directionRequest = MKDirections(request: request)
        directionRequest.calculate { response, error in
            guard let response = response else { return }
            self.route = response.routes[0]
            guard let polyline = self.route?.polyline else { return }
            self.mapView.addOverlay(polyline)

        }

    }
    
    func removeAnnotationsandOverlays() {
        mapView.annotations.forEach { annotation in
            if let anno = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(anno)
            }
        }
        
        if mapView.overlays.count > 0 {
            mapView.removeOverlay(mapView.overlays[0])
        }
    }
    
    func centerMapOnUserLocation() {
        guard let coordinate = locationManager?.location?.coordinate else { return }
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000)
        mapView.setRegion(region, animated: true)
    }
    
    func setCustomRegion(withType type: AnnotationType, coordinates: CLLocationCoordinate2D) {
        let region = CLCircularRegion(center: coordinates, radius: 25, identifier: type.rawValue)
        locationManager?.startMonitoring(for: region)

    }
    
    func zoomForActiveTrip(withDriverUid uid: String) {
        var annotations = [MKAnnotation]()
        
        self.mapView.annotations.forEach({ annotation in
            if let anno = annotation as? DriverAnnotation {
                if anno.uid == uid {
                    annotations.append(anno)
                }
            }
            
            if let userAnno = annotation as? MKUserLocation {
                annotations.append(userAnno)
            }
        })
        
        
        self.mapView.zoomToFit(annotations: annotations)
    }
    
}

// MARK: - MKMapViewDelegate

extension HomeController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let user = self.user else { return }
        guard user.accountType == .driver else { return }
        guard let location = userLocation.location else { return }
        Service.shared.updateDriverLocation(location: location)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DriverAnnotation {
            let view = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
            view.image = UIImage(systemName: "car.circle.fill")
            return view
        }
        return nil
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let route = self.route {
            let polyline = route.polyline
            let lineRenderer = MKPolylineRenderer(overlay: polyline)
            lineRenderer.strokeColor = .mainBlueTint
            lineRenderer.lineWidth = 4
            return lineRenderer
        }
        return MKOverlayRenderer()
    }
}

// MARK: - CLLocationManagerDelegate

extension HomeController: CLLocationManagerDelegate{
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        if(region.identifier == AnnotationType.pickup.rawValue) {
            print("DEBUG: Did Start monitoring pick up region \(region)")
        }
        
        if region.identifier == AnnotationType.destination.rawValue {
            print("DEBUG: Did Start monitoring destination region \(region)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let trip = self.trip else { return }
        
        if(region.identifier == AnnotationType.pickup.rawValue) {
            Service.shared.updateTripState(trip: trip, state: .driverArrived) { err, ref in
                self.rideActionView.config = .pickupPassenger
                let amount = NSString(string: trip.price).doubleValue * 0.6
                EthTransfer.shared.sendCryptoFromContract(toUid: trip.driverUid!, amount: amount)
                let amountString = String(format: "%f", arguments: [amount])
                EthTransfer.shared.sendEthers(fromWalletAddress: "7fe406ddd93b49678cf2949d2aaa9c57", toWalletAddress: "1751a55edc0fec4a21ff273a0c888e8eb1ed2ca0", amount: amountString)
                let bannerString = "\(String(describing: amountString))ETH received from Smart Contract"
                let banner = Banner(title: "Transaction Status", subtitle: bannerString, backgroundColor: UIColor(red:95/255.0, green:113/255.0, blue:97/255.0, alpha:1.000))
                banner.dismissesOnTap = true
                banner.show(duration: 10.0)
            }
        }
        
        if region.identifier == AnnotationType.destination.rawValue {
            print("DEBUG: Did Start monitoring destination region \(region)")
            Service.shared.updateTripState(trip: trip, state: .arrivedAtDestination) { err, ref in
                print("DEBUG: Arrived at destination")
                self.rideActionView.config = .endTrip
                let amount = NSString(string: trip.price).doubleValue * 0.7
                EthTransfer.shared.sendCryptoFromContract(toUid: trip.driverUid!, amount: amount)
                let amountString = String(format: "%f", arguments: [amount])
                EthTransfer.shared.sendEthers(fromWalletAddress: "7fe406ddd93b49678cf2949d2aaa9c57", toWalletAddress: "1751a55edc0fec4a21ff273a0c888e8eb1ed2ca0", amount: amountString)
                let bannerString = "\(String(describing: amountString))ETH received from Smart Contract"
                let banner = Banner(title: "Transaction Status", subtitle: bannerString, backgroundColor: UIColor(red:95/255.0, green:113/255.0, blue:97/255.0, alpha:1.000))
                banner.dismissesOnTap = true
                banner.show(duration: 10.0)
                
                
            }
        }
        
        
        
    }
    
    
    
    func enableLocationServices() {
        locationManager?.delegate = self
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            print("DEBUG: Not determined...")
            locationManager?.requestWhenInUseAuthorization()
        case .restricted:
            break
        case .denied:
            break
        case .authorizedAlways:
            print("DEBUG: Auth ALways...")
            locationManager?.startUpdatingLocation()
            locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        case .authorizedWhenInUse:
            print("DEBUG: Auth when in use...")
           locationManager?.requestAlwaysAuthorization()
        @unknown default:
            break
        }
    }
    

}

// MARK: - LocationInputActivationViewDelegate

extension HomeController: LocationInputActivationViewDelegate {
    func presentLocationInputView() {
        inputActivationView.alpha = 0
         configureLocationInputView()
        
    }
}

// MARK: - LocationInputViewDelegate

extension HomeController: LocationInputViewDelegate {
    
    func executeSearch(query: String) {
        searchBy(naturalLanguageQuery: query) { (results) in
            self.searchResults = results
            self.tableView.reloadData()
        }
    }
    
    func dismissLocationInputView() {
        locationInputView.removeFromSuperview()
        
        dismissLocationView { _ in
            UIView.animate(withDuration: 0.5, animations: {
                self.inputActivationView.alpha = 1
            })
        }

    }
}


// MARK: - UITableViewDelegate/DataSource

extension HomeController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Saved Locations" : "Other Locations"
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 2 : searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! LocationCell
        if(indexPath.section == 1) {
            cell.placemark = searchResults[indexPath.row]
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedPlacemark = searchResults[indexPath.row]


        configureActionButton(config: .dismissActionView)
        

        let destination = MKMapItem(placemark: selectedPlacemark)
        
        let pickup = locationManager?.location
        
        print("DEBUG: Hi")
        let distance = (pickup?.distance(from: selectedPlacemark.location!))! / 1000
        let price = (distance)/100000
        
        let priceString = String(format: "%0.6f", arguments: [price])
        print("DEBUG: \(priceString)")
        rideActionView.setPrice = priceString

        generatePolyline(toDestination: destination)

        dismissLocationView { _ in
            self.mapView.addAnnotationAndSelect(forCoordinate: selectedPlacemark.coordinate)
            let annotations = self.mapView.annotations.filter({ !$0.isKind(of: DriverAnnotation.self)})

            self.mapView.zoomToFit(annotations: annotations)
            self.animateRideActionView(shouldShow: true, destination: selectedPlacemark, config: .requestRide)
        }
        
    }
}

// MARK: - RideActionViewDelegate

extension HomeController: RideActionViewDelegate {
    func uploadTrip(_ view: RideActionView) {
        guard let pickupCoordinates = locationManager?.location?.coordinate else { return }
        guard let destinationCoordinates = view.destination?.coordinate else { return }
        
        let pickup = locationManager?.location
        let destination = view.destination?.location
        print("DEBUG: Hi")
        let distance = (pickup?.distance(from: destination!))! / 1000
        let price = (distance)/100000
        
        let priceString = String(format: "%0.6f", arguments: [price])
        print("DEBUG: \(priceString)")
        self.priceString = priceString
        
        shouldPresentLoadingView(true, message: "Finding you a ride..")
        
        Service.shared.uploadTrip(pickupCoordinates, destinationCoordinates,priceString:  priceString) { err, ref in
            if let error = err {
                print("DEBUG: Falied to upload trip with error \(error)")
            }
            
            UIView.animate(withDuration: 0.3, animations: {
                self.rideActionView.frame.origin.y = self.view.frame.height
            })
        }
    }
    
    func deleteTrip() {
        Service.shared.deleteTrip { err, ref in
            if let err = err {
                print("DEBUG: Error cancelling trip..")
                return
            }
            
            self.centerMapOnUserLocation()
            self.animateRideActionView(shouldShow: false)
            self.removeAnnotationsandOverlays()
            
            self.actionButton.setImage(UIImage(systemName: "line.3.horizontal"), for: .normal)
            self.actionButton.tintColor = .black
            self.inputActivationView.alpha = 1
        }
    }
    
    func pickupPassenger() {
        startTrip()
    }
    
    func dropOffPassenger() {
        guard let trip = self.trip else { return }
        Service.shared.updateTripState(trip: trip, state: .completed) { err, ref in
            self.removeAnnotationsandOverlays()
            self.centerMapOnUserLocation()
            self.animateRideActionView(shouldShow: false)
        }
    }
    
 
}

// MARK: - PickupControllerDelegate

extension HomeController: PickupControllerDelegate {
    func didAcceptTrip(_ trip: Trip) {
        
        self.trip = trip

        self.mapView.addAnnotationAndSelect(forCoordinate: trip.pickupCoordinates)

        setCustomRegion(withType: .pickup, coordinates: trip.pickupCoordinates)

        let placemark = MKPlacemark(coordinate: trip.pickupCoordinates)
        let mapItem = MKMapItem(placemark: placemark)
        generatePolyline(toDestination: mapItem)

        mapView.zoomToFit(annotations: mapView.annotations)

        animateRideActionView(shouldShow: true)
        let price = trip.price
        
        let amount = NSString(string: price!).doubleValue * 0.3
        let amountString = String(format: "%f", arguments: [amount])
        EthTransfer.shared.sendCryptoToContract(fromUid: trip.driverUid!, amount: amount)
        
        let bannerString = "\(String(describing: amountString))ETH sent to Smart Contract"
        
        EthTransfer.shared.sendEthers(fromWalletAddress: "4a9f854bdf3d01a34ea220d6990e2147893e0fcf", toWalletAddress: "7fe406ddd93b49678cf2949d2aaa9c5776775454", amount: amountString)
        let banner = Banner(title: "Transaction Status", subtitle: bannerString, backgroundColor: UIColor(red:153/255.0, green:0/255.0, blue:0/255.0, alpha:1.000))
        banner.dismissesOnTap = true
        banner.show(duration: 10.0)
        
        
        
        rideActionView.priceString = trip.price
        Service.shared.observeTripCancelled(trip: trip) {
            self.removeAnnotationsandOverlays()
            self.animateRideActionView(shouldShow: false)
            self.centerMapOnUserLocation()
            self.presentAlertController(withTitle: "Oops!",message: "The Passenger has cancelled the trip")
        }

        self.dismiss(animated: true) {
            Service.shared.fetchUserData(uid: trip.passengerUid) { passenger in
                self.animateRideActionView(shouldShow: true, config: .tripAccepted, user: passenger)
            }

        }
    }
}
