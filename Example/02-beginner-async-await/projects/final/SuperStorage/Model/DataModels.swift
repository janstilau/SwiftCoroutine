import Foundation

/*
 /// A class of types whose instances hold the value of an entity with stable
 /// identity.
 ///
 /// Use the `Identifiable` protocol to provide a stable notion of identity to a
 /// class or value type. For example, you could define a `User` type with an `id`
 /// property that is stable across your app and your app's database storage.
 /// You could use the `id` property to identify a particular user even if other
 /// data fields change, such as the user's name.
 ///
 /// `Identifiable` leaves the duration and scope of the identity unspecified.
 /// Identities can have any of the following characteristics:
 ///
 /// - Guaranteed always unique, like UUIDs.
 /// - Persistently unique per environment, like database record keys.
 /// - Unique for the lifetime of a process, like global incrementing integers.
 /// - Unique for the lifetime of an object, like object identifiers.
 /// - Unique within the current collection, like collection indices.
 ///
 /// It's up to both the conformer and the receiver of the protocol to document
 /// the nature of the identity.
 ///
 /// Conforming to the Identifiable Protocol
 /// =======================================
 ///
 /// `Identifiable` provides a default implementation for class types (using
 /// `ObjectIdentifier`), which is only guaranteed to remain unique for the
 /// lifetime of an object. If an object has a stronger notion of identity, it
 /// may be appropriate to provide a custom implementation.
 @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
 public protocol Identifiable {

     /// A type representing the stable identity of the entity associated with
     /// an instance.
     associatedtype ID : Hashable

     /// The stable identity of the entity associated with this instance.
     var id: Self.ID { get }
 }

 @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
 extension Identifiable where Self : AnyObject {

     /// The stable identity of the entity associated with this instance.
     public var id: ObjectIdentifier { get }
 }
 */

/// A downloadble file.
struct DownloadFile: Codable, Identifiable, Equatable {
  // 因为遵循了 Identifiable 这个 protocol, 所以一定要有一个 id 属性.
  var id: String { return name }
  let name: String
  let size: Int
  let date: Date
  
  static let empty = DownloadFile(name: "", size: 0, date: Date())
}

/// Download information for a given file.
struct DownloadInfo: Identifiable, Equatable {
  let id: UUID
  let name: String
  var progress: Double // 在下载的过程中, 会更新这个值. 然后, 这个值的改变, 会触发 View 的更新. 
}
