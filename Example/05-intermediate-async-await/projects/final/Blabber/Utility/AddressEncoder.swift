import CoreLocation
import Contacts

/// A type that converts a location into a human readable address.
enum AddressEncoder {
  /// Converts the given location into the nearest address, calls `completion` when finished.
  ///
  /// - Note: This method is "simulating" an old-style callback API that the reader can wrap
  ///   as an async code while working through the book.
  static func addressFor(location: CLLocation,
                         completion: @escaping (String?, Error?) -> Void) {
    let geocoder = CLGeocoder()
    
    Task {
      do {
        guard
          // 因为, 在这里使用到了 await geocoder.reverseGeocodeLocation, 这是一个异步函数,
          // 所以要在这里, 开启一个异步执行环境才可以.
          let placemark = try await geocoder.reverseGeocodeLocation(location).first,
          let address = placemark.postalAddress else {
          completion(nil, "No addresses found")
          return
        }
        completion(
          CNPostalAddressFormatter.string(from: address, style: .mailingAddress),
          nil)
      } catch {
        completion(nil, error)
      }
    }
  }
}
