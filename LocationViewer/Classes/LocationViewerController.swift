//
//  LocationViewerController.swift
//  Pods
//
//  Created by admin on 18/1/18.
//

import UIKit
import MapKit

public class LocationViewerController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    
    private var state = 1 { didSet(value) { if value > 1 { state = 0 } } }
    private var annotationTitle: String?
    private var userLocation: CLLocation?
    private var location: CLLocation?
    private let geoCoder: CLGeocoder = CLGeocoder()
    private let locationManager = CLLocationManager()
    
    var backButton: UIBarButtonItem?
    var leftCallOutAction: (() -> Void)? = nil
    var rightCallOutAction: (() -> Void)? = nil
    var shareAction: ((CLLocation) -> Void)? = nil
    
    public convenience init(location: CLLocation, forName name: String) {
        let bundle = Bundle(for: LocationViewerController.classForCoder())
        self.init(nibName: "LocationViewerController", bundle: bundle)
        self.location = location
        self.annotationTitle = name
    }
    
    private lazy var annotation: MKPointAnnotation? = {
        guard let location = location else {return nil}
        let annotation = MKPointAnnotation()
        annotation.title = annotationTitle
        annotation.coordinate = location.coordinate
        return annotation
    }()
    
    private lazy var userAnnotation: MKPointAnnotation? = {
        guard let location = userLocation else {return nil}
        let annotation = MKPointAnnotation()
        annotation.title = "My Location"
        annotation.coordinate = location.coordinate
        return annotation
    }()
    
    private lazy var userCamera: MKMapCamera? = {
        guard let location = userLocation else {return nil}
        if #available(iOS 9.0, *) {
            return MKMapCamera(lookingAtCenter: location.coordinate,fromDistance: 1000,pitch: 0,heading: 0)
        } else {
            return MKMapCamera(lookingAtCenter: location.coordinate, fromEyeCoordinate: location.coordinate, eyeAltitude: 1000)
        }
    }()
    
    private lazy var camera: MKMapCamera? = {
        guard let location = location else {return nil}
        if #available(iOS 9.0, *) {
            return MKMapCamera(lookingAtCenter: location.coordinate,fromDistance: 1000,pitch: 0,heading: 0)
        } else {
            return MKMapCamera(lookingAtCenter: location.coordinate, fromEyeCoordinate: location.coordinate, eyeAltitude: 1000)
        }
    }()
    
    private lazy var leftButtonCallOut: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        button.backgroundColor = button.tintColor
        button.addTarget(self, action: #selector(executeLeftCallOutAction(_:)), for: .touchUpInside)
        return button
    }()
    
    private lazy var rightButtonCallOut: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        button.backgroundColor = button.tintColor
        button.addTarget(self, action: #selector(executeRightCallOutAction(_:)), for: .touchUpInside)
        return button
    }()
    
    @objc func executeRightCallOutAction(_ sender: Any) {
        rightCallOutAction?()
    }
    
    @objc func executeLeftCallOutAction(_ sender: Any) {
        leftCallOutAction?()
    }
    
    @IBAction func share(_ sender: Any) {
        guard let location = location else {return}
        shareAction?(location)
    }
    
    @IBAction func changedValue(_ sender: Any) {
        guard let sender = sender as? UISegmentedControl else {return}
        let mapType: [MKMapType] = [.standard, .hybrid, .satellite]
        guard sender.selectedSegmentIndex < mapType.count else {return}
        mapView.mapType = mapType[sender.selectedSegmentIndex]
    }
    
    @IBAction func search(_ sender: Any) {
        guard let location = location, let userLocation = userLocation else {return}
        switch state {
        case 0:
            if let annotation = annotation { mapView.selectAnnotation(annotation, animated: true) }
            if let camera = camera { mapView.setCamera(camera, animated: true) }
            break
        case 1:
            let distance = location.distance(from: userLocation)
            let centerLatitude = (location.coordinate.latitude + userLocation.coordinate.latitude) / 2
            let centerLongitude = (location.coordinate.longitude + userLocation.coordinate.longitude) / 2
            let centerCoordinate = CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
            let region = MKCoordinateRegionMakeWithDistance(centerCoordinate, 3 * distance, 3 * distance)
            let adjustedRegion = mapView.regionThatFits(region)
            mapView.setRegion(adjustedRegion, animated: true)
            break
        case 2:
            if let annotation = userAnnotation { mapView.selectAnnotation(annotation, animated: true) }
            if let camera = userCamera { mapView.setCamera(camera, animated: true) }
            break
        default:
            break
        }
        state += 1
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        if let backButton = backButton { navigationItem.backBarButtonItem = backButton }
        if let camera = camera { mapView.setCamera(camera, animated: false) }
        if let annotation = annotation { self.mapView.addAnnotation(annotation) }
        if let annotation = annotation { mapView.selectAnnotation(annotation, animated: true) }
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }
        guard let location = location else {return}
        geoCoder.reverseGeocodeLocation(location, completionHandler: { placemark, _ in
            guard let placemark = placemark?.first else {return}
            self.navigationItem.titleView = self.setTitle(title: placemark.thoroughfare, subtitle: placemark.administrativeArea)
        })
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        switch (self.mapView.mapType) {
        case MKMapType.hybrid:
            self.mapView.mapType = MKMapType.standard
            break;
        case MKMapType.standard:
            self.mapView.mapType = MKMapType.hybrid
            break;
        default:
            break;
        }
        self.mapView.showsUserLocation = false
        self.mapView.delegate = nil
        self.mapView.removeFromSuperview()
        self.mapView = nil
    }
    
    private func setTitle(title: String?, subtitle: String?) -> UIView {
        let titleLabel = UILabel(frame: CGRect(x:0, y:-5, width:0, height:0))
        
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.textColor = UIColor.black
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
        titleLabel.text = title
        titleLabel.sizeToFit()
        
        let subtitleLabel = UILabel(frame: CGRect(x:0, y:18, width:0, height:0))
        subtitleLabel.backgroundColor = UIColor.clear
        subtitleLabel.textColor = UIColor.darkGray
        subtitleLabel.font = UIFont.systemFont(ofSize: 12)
        subtitleLabel.text = subtitle
        subtitleLabel.sizeToFit()
        
        let width = max(titleLabel.frame.size.width, subtitleLabel.frame.size.width)
        let titleView = UIView(frame: CGRect(x:0, y:0, width:width, height:30))
        titleView.addSubview(titleLabel)
        titleView.addSubview(subtitleLabel)

        let widthDiff = subtitleLabel.frame.size.width - titleLabel.frame.size.width
        let newX = widthDiff / 2
        if widthDiff < 0 { subtitleLabel.frame.origin.x = abs(newX) }
        else { titleLabel.frame.origin.x = newX }
        return titleView
    }
    
}

extension LocationViewerController: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.first
    }
}

extension LocationViewerController: MKMapViewDelegate {
    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {return nil}
        guard let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "pin") else {
            let annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "pin")
            annotationView.animatesDrop = true
            annotationView.canShowCallout = true
            annotationView.leftCalloutAccessoryView = leftButtonCallOut
            annotationView.rightCalloutAccessoryView = rightButtonCallOut
            return annotationView
        }
        annotationView.annotation = annotation
        return annotationView
    }
}