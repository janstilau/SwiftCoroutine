import Foundation

/// A single stock with a name and a price.
struct Stock: Hashable, Codable {
  let name: String
  let value: Double
}
