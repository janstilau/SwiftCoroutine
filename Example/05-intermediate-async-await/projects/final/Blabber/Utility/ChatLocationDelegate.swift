import Foundation
import CoreLocation

/*
 在这里, 封装的是, CLLocationManager 的相关逻辑 i.
 */
class ChatLocationDelegate: NSObject, CLLocationManagerDelegate {
  
  typealias LocationContinuation = CheckedContinuation<CLLocation, Error>
  private var continuation: LocationContinuation?
  private let manager = CLLocationManager()
  
  init(continuation: LocationContinuation) {
    self.continuation = continuation
    super.init()
    manager.delegate = self
    manager.requestWhenInUseAuthorization()
  }
  
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .notDetermined:
      break
    case .authorizedAlways, .authorizedWhenInUse:
      manager.startUpdatingLocation()
    default:
      continuation?.resume(
        throwing: "The app isn't authorized to use location data"
      )
      continuation = nil
    }
  }
  
  func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    guard let location = locations.first else { return }
    continuation?.resume(returning: location)
    continuation = nil
  }
  
  func locationManager(
    _ manager: CLLocationManager,
    didFailWithError error: Error
  ) {
    continuation?.resume(throwing: error)
    continuation = nil
  }
}
