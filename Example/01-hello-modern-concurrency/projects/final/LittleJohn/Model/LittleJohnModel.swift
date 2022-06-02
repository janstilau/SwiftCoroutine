import Foundation

/// Easily throw generic errors with a text description.
extension String: Error { }

/// The app model that communicates with the server.
class LittleJohnModel: ObservableObject {
  /// Current live updates.
  @Published private(set) var tickerSymbols: [Stock] = []
  
  /// Start live updates for the provided stock symbols.
  func startTicker(_ selectedSymbols: [String]) async throws {
    tickerSymbols = []
    guard let url = URL(string: "http://localhost:8080/littlejohn/ticker?\(selectedSymbols.joined(separator: ","))") else {
      throw "The URL could not be created."
    }
    
    let (stream, response) = try await liveURLSession.bytes(from: url)
    
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw "The server responded with an error."
    }
    
    for try await line in stream.lines {
      let sortedSymbols = try JSONDecoder()
        .decode([Stock].self, from: Data(line.utf8))
        .sorted(by: { $0.name < $1.name })
      
      await MainActor.run {
        tickerSymbols = sortedSymbols
        print("Updated: \(Date())")
      }
    }
  }
  
  func availableSymbols() async throws -> [String] {
    guard let url = URL(string: "http://localhost:8080/littlejohn/symbols") else {
      throw "The URL could not be created."
    }
    
    let (data, response) = try await URLSession.shared.data(from: url)
    
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw "The server responded with an error."
    }
    
    return try JSONDecoder().decode([String].self, from: data)
  }
  
  /// A URL session that lets requests run indefinitely so we can receive live updates from server.
  private lazy var liveURLSession: URLSession = {
    var configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = .infinity
    return URLSession(configuration: configuration)
  }()
}
