import CoreLocation
import Observation

@Observable @MainActor
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var active = false
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var message: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        authorization = manager.authorizationStatus
    }

    func start() {
        active = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            updateAuthorization()
        }
    }

    func stop() {
        active = false
        manager.stopUpdatingLocation()
    }

    private func updateAuthorization() {
        authorization = manager.authorizationStatus
        switch authorization {
        case .authorizedAlways, .authorizedWhenInUse:
            message = nil
            if active { manager.startUpdatingLocation() }
        case .denied, .restricted:
            manager.stopUpdatingLocation()
            coordinate = nil
            message = "Location is off. Enable it in Settings."
        default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.updateAuthorization() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0,
              abs(location.timestamp.timeIntervalSinceNow) < 30 else { return }
        let coordinate = location.coordinate
        Task { @MainActor in
            self.coordinate = coordinate
            self.message = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let code = (error as? CLError)?.code
        Task { @MainActor in
            if code == .denied {
                self.updateAuthorization()
            } else if code != .locationUnknown {
                self.message = "Location unavailable."
            }
        }
    }
}
