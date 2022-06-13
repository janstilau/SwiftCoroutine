import Foundation

struct ImageFile: Codable, Identifiable, Equatable {
  let id: UUID
  let name: String
  let url: String
  let price: Double
  let checksum: String
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = UUID()
    name = try container.decode(String.self, forKey: .name)
    url = try container.decode(String.self, forKey: .url)
    price = try container.decode(Double.self, forKey: .price)
    checksum = try container.decode(String.self, forKey: .checksum)
  }
}
