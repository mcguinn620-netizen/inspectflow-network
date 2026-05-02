import Foundation
final class LocalStore { private let d=UserDefaults.standard; func save<T:Codable>(_ value:T,key:String){ if let data=try? JSONEncoder().encode(value){ d.set(data,forKey:key)}}; func load<T:Codable>(_ type:T.Type,key:String)->T?{ guard let data=d.data(forKey:key) else{return nil}; return try? JSONDecoder().decode(type,from:data)} }
