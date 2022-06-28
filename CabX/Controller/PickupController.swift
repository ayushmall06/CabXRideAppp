//
//  PickupController.swift
//  CabX
//
//  Created by Ayush Mall on 22/06/22.
//

import UIKit
import MapKit

protocol PickupControllerDelegate: class {
    func didAcceptTrip(_ trip: Trip)
}

class PickupController: UIViewController {
     
    // MARK: - Properties
    
    weak var delegate: PickupControllerDelegate?
    private let mapView = MKMapView()
    let trip: Trip
    
    private let cancelButton: UIButton = {
        let button = UIButton()
        
        button.setImage(UIImage(systemName: "xmark")?.withTintColor(.white).withRenderingMode(.alwaysOriginal), for: .normal)
        button.addTarget(self, action: #selector(handleDismissal), for: .touchUpInside)
        return button
    }()
    
    private let pickupLabel: UILabel = {
        let label = UILabel()
        label.text = "Would you like to pickup this passenger ?"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .white
        return label
    }()
    
    private var paymentInfo: UILabel = {
        let label = UILabel()
        let price = NSMutableAttributedString(string: "Price : ", attributes: [NSAttributedString.Key.font : UIFont.boldSystemFont(ofSize: 22),
            NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        
        let amount = NSMutableAttributedString(string: "", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 20),NSAttributedString.Key.foregroundColor: UIColor.white])
        
        let symbol = NSMutableAttributedString(string: " ETH", attributes: [NSAttributedString.Key.font : UIFont.boldSystemFont(ofSize: 20),NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        price.append(amount)
        price.append(symbol)
        label.attributedText = price
        return label
    }()
    
    private let acceptTripButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(handleAcceptTrip), for: .touchUpInside)
        button.backgroundColor = .white
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        button.setTitleColor(.black, for: .normal)
        button.setTitle("ACCEPT TRIP", for: .normal)
        
        return button
    }()
    
    // MARK: - Lifecycle
    
    init(trip: Trip) {
        self.trip = trip
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("DEBUG: Trip passenger uid is \(trip.passengerUid)")
        
        configureUI()
        configureMapView()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Selectors
    
    @objc func handleDismissal() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func handleAcceptTrip() {
        Service.shared.acceptTrip(trip: trip) { err, ref in
            
            self.delegate?.didAcceptTrip(self.trip)
        }
    }
    
    // MARK: - API
    
    // MARK: - Helper Functions
    
    func configureMapView() {
        let region = MKCoordinateRegion(center: trip.pickupCoordinates, latitudinalMeters: 1000, longitudinalMeters: 1000)
        mapView.setRegion(region, animated: false)
        
        
        self.mapView.addAnnotationAndSelect(forCoordinate: trip.pickupCoordinates)
    }
    
    func configureUI() {
        view.backgroundColor = .black
        
        view.addSubview(cancelButton)
        cancelButton.anchor(top: view.safeAreaLayoutGuide.topAnchor, left: view.leftAnchor, paddingLeft: 16)
        
        view.addSubview(mapView)
        mapView.setDimensions(height: 270, width: 270)
        mapView.layer.cornerRadius = 270/2
        mapView.centerX(inView: view)
        mapView.centerY(inView: view, constant: -200)
        
        view.addSubview(pickupLabel)
        pickupLabel.centerX(inView: view)
        pickupLabel.anchor(top: mapView.bottomAnchor ,paddingTop: 20)
        
        let price = NSMutableAttributedString(string: "Price : ", attributes: [NSAttributedString.Key.font : UIFont.boldSystemFont(ofSize: 22),
            NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        
        let amount = NSMutableAttributedString(string: self.trip.price, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 20),NSAttributedString.Key.foregroundColor: UIColor.white])
        
        let symbol = NSMutableAttributedString(string: " ETH", attributes: [NSAttributedString.Key.font : UIFont.boldSystemFont(ofSize: 20),NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        price.append(amount)
        price.append(symbol)
        paymentInfo.attributedText = price
        
        view.addSubview(paymentInfo)
        paymentInfo.centerX(inView: view)
        paymentInfo.anchor(top: pickupLabel.bottomAnchor, paddingTop: 20)
        
        view.addSubview(acceptTripButton)
        acceptTripButton.anchor(top: paymentInfo.bottomAnchor, left: view.leftAnchor, right: view.rightAnchor, paddingTop: 16, paddingLeft: 32, paddingRight: 32, height: 50)
    }
}

