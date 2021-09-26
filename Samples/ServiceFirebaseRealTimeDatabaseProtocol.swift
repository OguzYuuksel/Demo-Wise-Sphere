//
// Project: FirebaseRealTimeDatabase
// File: ServiceFirebaseRealTimeDatabaseProtocol.swift
// Copyright © 2021 Oguz Yuksel. All rights reserved.
//
// Created by Oguz Yuksel(oguz.yuuksel@gmail.com) on 18.09.2021.
//

import Foundation
import FirebaseDatabase
import CodableFirebase
import Algorithms

// MARK: - Protocol
protocol ServiceFirebaseRealTimeDatabaseProtocol: ObservableObject {
    typealias ObservationType = Database.ModelObserver.ObservationType
    typealias OrderType = Database.ModelObserver.QueryOrder
    typealias FilterType = Database.ModelObserver.QueryFilter
    typealias ObserverModel = Database.ModelObserver
    typealias ServiceError = Database.ServiceError
    var database: Database { get }
    var dbRef: DatabaseReference { get }
    var refObservers: [ObserverModel : DatabaseHandle] { get set }
    func create<T: Codable>(childPath: String, value: T) async throws -> Void
    func create<T: Codable>(childPaths: [String], value: T) async throws -> Void
    func update<T: Codable>(childPath: String, value: T) async throws -> Void
    func update<T: Codable>(childPaths: [String], value: T) async throws -> Void
    func write<T: Codable>(childPath: String, value: T) async throws -> Void
    func write<T: Codable>(childPaths: [String], value: T) async throws -> Void
    func remove(childPath: String) async throws -> Void
    func addObserver<T: Codable>(model: ObserverModel, completion: @escaping (_ jsonValue: Result<T?,Error>) -> Void)
    func getData<T: Codable>(childPath: String) async throws -> T?
    func removeObserver(model: ObserverModel) throws -> Void
    func removeAllObservers(childPath: String) throws -> Void
    func deInit()
}

// TODO: Add Transactions
// TODO: Consider Opaque Types instead of Generics
// TODO: Fix Documentation Typos!
extension ServiceFirebaseRealTimeDatabaseProtocol {
    
    // MARK: Properties
    var dbRef: DatabaseReference { database.reference() }
    
    // MARK: Functions
    /// `Create` a value for given path. In order to `Create`, value of given path key must be empty.
    /// - Parameters:
    ///   - childPath: Path of `value`.
    ///   - value: `value` of `childPath`.
    func create<T: Codable>(childPath: String = "/", value: T) async throws -> Void {
        if try await (getData(childPath: childPath) as T?) == nil {
            try await write(childPath: childPath, value: value) // Path is empty, you can write.
        }
        else {
            throw ServiceError.pathIsFull
        }
    }
    
    /// `Create` a value for given path. In order to `Create`, value of given path key must be empty.
    /// - Parameters:
    ///   - childPaths: Path of `value`.
    ///   - value: `value` of `childPath`.
    func create<T: Codable>(childPaths: [String], value: T) async throws -> Void {
        for path in childPaths {
            if try await (getData(childPath: path) as T?) != nil {
                throw ServiceError.pathIsFull
            }
        }
        try await write(childPaths: childPaths, value: value) // Paths are empty, you can write.
    }
    
    /// `Update` value of given path. In order to `Update`, given path key must have a value.
    /// - Parameters:
    ///   - childPath: Path of `value`.
    ///   - value: `value` of `childPath`.
    func update<T: Codable>(childPath: String = "/", value: T) async throws -> Void {
        if try await (getData(childPath: childPath) as T?) != nil {
            try await write(childPath: childPath, value: value) // Path is not empty, you can write.
        }
        else {
            throw ServiceError.pathIsEmpty
        }
    }
    
    /// `Update` value of given path. In order to `Update`, given path key must have a value.
    /// - Parameters:
    ///   - childPaths: Path of `value`.
    ///   - value: `value` of `childPath`.
    func update<T: Codable>(childPaths: [String], value: T) async throws -> Void {
        for path in childPaths {
            if try await (getData(childPath: path) as T?) == nil {
                throw ServiceError.pathIsEmpty
            }
        }
        try await write(childPaths: childPaths, value: value) // Paths are not empty, you can write.
    }
    
    /// `Write` value of given path. `Write` is a forced method so that there is value or not, it will write!
    /// - Parameters:
    ///   - childPath: Path of `value`.
    ///   - value: `value` of `childPath`.
    func write<T: Codable>(childPath: String = "/", value: T) async throws -> Void {
        do {
            try await dbRef.child(childPath).setValue(value)
        } catch {
            throw ServiceError.writingFailed
        }
    }
    
    /// `Write` value of given path. `Write` is a forced method so that there is value or not, it will write!
    /// - Parameters:
    ///   - childPaths: Path of `value`.
    ///   - value: `value` of `childPath`.
    func write<T: Codable>(childPaths: [String], value: T) async throws -> Void {
        // Simultaneous updates made this way are atomic: either all updates succeed or all updates fail.
        let composedPaths = composePaths(childPaths)
        print("ServiceDatabaseProtocol.write(): writes following paths \(composedPaths)")
        let childUpdates = Dictionary(uniqueKeysWithValues: composedPaths.map { ($0, value) })
        do {
            try await dbRef.updateChildValues(childUpdates)
        } catch {
            throw ServiceError.writingFailed
        }
    }
    
    /// `Remove` a value.
    /// - Parameter childPath: Path of `value`.
    func remove(childPath: String = "/") async throws -> Void {
        do {
            try await dbRef.child(childPath).removeValue()
        } catch {
            throw ServiceError.removingFailed
        }
    }
    
    /// Observe a database `path` according to observation `type`.
    ///
    /// # Database Structure
    ///             /users
    ///                 /17865
    ///                     /name: "Oguz Yuksel"
    ///                     /email: "oguz.yuuksel@gmail.com"
    ///                     /gender: "M"
    ///                     /age: 27
    ///                 /25789
    ///                     /name: "Clark Kent"
    ///                     /email: "clark.kent@icloud.com"
    ///                     /gender: "M"
    ///                     /age: 22
    ///                 /29874
    ///                     /name: "Nancy Brown"
    ///                     /email: "nancy.brown@hotmail.com"
    ///                     /gender: "F"
    ///                     /age: 52
    ///                 /29894
    ///                     /name: "Ela Twin"
    ///                     /email: "ela.twin@gmail.com"
    ///                     /gender: "F"
    ///                     /age: 25
    ///             /posts
    ///                 /92
    ///                     /title: "First Post"
    ///                     /context: "Something happened!"
    ///                 /493
    ///                     /title: "Third Post"
    ///                     /context: "Something happened!"
    ///                 /123
    ///                     /title: "Second Post"
    ///                     /context: "Something again happened!"
    ///
    /// # Query samples
    /// - queryOrdered(byChild: String) & queryEqual(toValue: Any)
    ///
    ///       ref.child(/users).queryOrdered(byChild: "gender").queryEqual(toValue: "F", childKey: "29894")<.observe/.getData/.observeSingleEvent>
    ///     Returns a **disordered JSON** as below, **.sort()** returned value before using!
    ///
    ///       //  {
    ///       //      "29874" = {
    ///       //          name: "Nancy Brown";
    ///       //          email: "nancy.brown@hotmail.com";
    ///       //          gender: "F";
    ///       //          age: 52;
    ///       //      };
    ///       //      "29894" = {
    ///       //          name: "Ela Twin";
    ///       //          email: "ela.twin@gmail.com";
    ///       //          gender: "F";
    ///       //          age: 25;
    ///       //      };
    ///       //  };
    ///
    /// - queryOrdered(byChild: String) & queryEqual(toValue: Any, childKey: String)
    ///
    ///       ref.child(/users).queryOrdered(byChild: "gender").queryEqual(toValue: "F", childKey: "29894")<.observe/.getData/.observeSingleEvent>
    ///     Returns a **disordered JSON** as below, **.sort()** returned value before using!
    ///
    ///       //  {
    ///       //      "29894" = {
    ///       //          name: "Ela Twin";
    ///       //          email: "ela.twin@gmail.com";
    ///       //          gender: "F";
    ///       //          age: 25;
    ///       //      };
    ///       //  };
    ///
    /// - queryOrdered(byChild: String) & queryEnding(beforeValue: Any)
    ///
    ///     queryEnding(beforeValue: Any, childKey: String)
    ///
    ///     Inferences can be made for this version by looking at the previous examples.
    ///
    ///       ref.child(/users).queryOrdered(byChild: "age").queryEnding(beforeValue:52)<.observe/.getData/.observeSingleEvent>
    ///     Returns a **disordered JSON** as below, **.sort()** returned value before using!
    ///
    ///       //  {
    ///       //      "17865" = {
    ///       //          name: "Oguz Yuksel";
    ///       //          email: "oguz.yuuksel@gmail.com";
    ///       //          gender: "M";
    ///       //          age: 27;
    ///       //      };
    ///       //      "25789" = {
    ///       //          name: "Clark Kent";
    ///       //          email: "clark.kent@icloud.com";
    ///       //          gender: "M";
    ///       //          age: 22;
    ///       //      };
    ///       //      "29894" = {
    ///       //          name: "Ela Twin";
    ///       //          email: "ela.twin@gmail.com";
    ///       //          gender: "F";
    ///       //          age: 25;
    ///       //      };
    ///       //  };
    ///
    /// - queryOrdered(byChild: String) & queryEnding(atValue: Any)
    ///
    ///     queryEnding(atValue: Any, childKey: String)
    ///
    ///     Inferences can be made for this version by looking at the previous examples.
    ///
    ///       ref.child(/users).queryOrdered(byChild: "age").queryEnding(atValue:52)<.observe/.getData/.observeSingleEvent>
    ///     Returns a **disordered JSON** as below, **.sort()** returned value before using!
    ///
    ///       //  {
    ///       //      "17865" = {
    ///       //          name: "Oguz Yuksel";
    ///       //          email: "oguz.yuuksel@gmail.com";
    ///       //          gender: "M";
    ///       //          age: 27;
    ///       //      };
    ///       //      "25789" = {
    ///       //          name: "Clark Kent";
    ///       //          email: "clark.kent@icloud.com";
    ///       //          gender: "M";
    ///       //          age: 22;
    ///       //      };
    ///       //      "29874" = {
    ///       //          name: "Nancy Brown";
    ///       //          email: "nancy.brown@hotmail.com";
    ///       //          gender: "F";
    ///       //          age: 52;
    ///       //      };
    ///       //      "29894" = {
    ///       //          name: "Ela Twin";
    ///       //          email: "ela.twin@gmail.com";
    ///       //          gender: "F";
    ///       //          age: 25;
    ///       //      };
    ///       //  };
    ///
    /// - queryOrdered(byChild: String) & queryLimited(toFirst: Int)
    ///
    ///     queryLimited(toLast: Int)
    ///
    ///     Inferences can be made for this version by looking at the previous examples.
    ///
    ///       ref.child(/users).queryOrdered(byChild: "age").queryLimited(toFirst:2)<.observe/.getData/.observeSingleEvent>
    ///     Returns a **disordered JSON** as below, **.sort()** returned value before using!
    ///
    ///       //  {
    ///       //      "25789" = {
    ///       //          name: "Clark Kent";
    ///       //          email: "clark.kent@icloud.com";
    ///       //          gender: "M";
    ///       //          age: 22;
    ///       //      };
    ///       //      "29894" = {
    ///       //          name: "Ela Twin";
    ///       //          email: "ela.twin@gmail.com";
    ///       //          gender: "F";
    ///       //          age: 25;
    ///       //      };
    ///       //  };
    ///
    /// - queryOrderedByKey() & queryLimited(toFirst: Int)
    ///
    ///     queryOrderedByKey().<otherQueryTypes>
    ///
    ///     queryOrderedByValue().<otherQueryTypes>
    ///
    ///     Inferences can be made for these versions by looking at the previous examples.
    ///
    ///       ref.child(/posts).queryOrderedByKey().queryLimited(toFirst:2)<.observe/.getData/.observeSingleEvent>
    ///     Returns a **disordered JSON** as below, **.sort()** returned value before using!
    ///
    ///       //  {
    ///       //      "92" = {
    ///       //          title: "First Post";
    ///       //          context: "Something happened!";
    ///       //      };
    ///       //      "123" = {
    ///       //          title: "Second Post";
    ///       //          context: "Something again happened!";
    ///       //      };
    ///       //  };
    ///
    /// - Parameters:
    ///   - model: Observer Model.
    ///   - completion: Completion will run each time after getting a new value from observer. You may use that update something through ViewModel in UI with new value.
    ///   - jsonValue: JSON model of observed path.
    func addObserver<T: Codable>(model: ObserverModel, completion: @escaping (_ jsonValue: Result<T?,Error>) -> Void) {
        guard refObservers[model] == nil else { completion(.failure(ServiceError.observerAlreadyExists)); return } // Check if observer already added.
        var dbQuery = dbRef.child(model.childPath) as DatabaseQuery
        
        switch model.order {
        case .queryOrderedByKey:
            dbQuery = dbQuery.queryOrderedByKey()
        case .queryOrderedByValue:
            dbQuery = dbQuery.queryOrderedByValue()
        case .queryOrdered(let byChild):
            dbQuery = dbQuery.queryOrdered(byChild: byChild)
        default:
            break
        }
        
        switch model.filter {
        case .queryEqualToValue(let toValue, childKey: let childKey):
            dbQuery = dbQuery.queryEqual(toValue: toValue, childKey: childKey)
        case .queryEndingAtValue(let atValue, childKey: let childKey):
            dbQuery = dbQuery.queryEnding(atValue: atValue, childKey: childKey)
        case .queryEndingBeforeValue(let beforeValue, childKey: let childKey):
            dbQuery = dbQuery.queryEnding(beforeValue: beforeValue, childKey: childKey)
        case .queryStartingAtValue(let atValue, childKey: let childKey):
            dbQuery = dbQuery.queryStarting(atValue: atValue, childKey: childKey)
        case .queryStartingAfterValue(let afterValue, childKey: let childKey):
            dbQuery = dbQuery.queryStarting(afterValue: afterValue, childKey: childKey)
        case .queryLimitedToFirst(let toFirst):
            dbQuery = dbQuery.queryLimited(toFirst: toFirst)
        case .queryLimitedToLast(let toLast):
            dbQuery = dbQuery.queryLimited(toLast: toLast)
        default:
            break
        }
        
        // Completion will run each time after getting a new value from observer.
        switch model.observationType {
        case .observeOnce(event: let event):
            dbQuery.observeSingleEvent(of: event) { jsonSnap in
                completionFunc(jsonSnap: jsonSnap)
            }
        case .observe(event: let event):
            refObservers[model] = dbQuery.observe(event) { jsonSnap in
                completionFunc(jsonSnap: jsonSnap)
            }
        }
        
        // Helper function
        func completionFunc(jsonSnap: DataSnapshot) {
            do {
                let value: T? = try snapDecoder(jsonSnap)
                completion(.success(value))
            } catch let error {
                completion(.failure(error))
            }
        }
    }
        
    /// Get current value from a specific `Database Path`
    ///
    /// - Parameter childPath: Path of value.
    /// - Returns: Optional type safe value.
    func getData<T: Codable>(childPath: String = "/") async throws -> T? {
        do {
            let snapshot = try await dbRef.child(childPath).getData()
            let model: T? = try snapDecoder(snapshot)
            #if DEBUG
            print("ServiceDatabaseProtocol.getData(): \(String(describing: model))")
            #endif
            return model
        } catch {
            throw ServiceError.gettingDataFailed
        }
    }
    
    /// Remove a observer.
    ///
    /// # Info:
    /// - Observer will be also removed from `refObservers` dictionary in case of active Observers list need.
    ///
    /// - Parameter model: Observer Model.
    func removeObserver(model: ObserverModel) throws -> Void {
        guard let observerID = refObservers[model] else { throw ServiceError.observerDoesntExist }
        dbRef.child(model.childPath).removeObserver(withHandle: observerID)
        refObservers.removeValue(forKey: model)
        #if DEBUG
        print("ServiceDatabaseProtocol.removeObserver(): Removed observer: \(model)")
        #endif
    }
        
    /// Removes all observers at the current reference, but does not remove any observers at child references.
    /// `removeAllObservers()` must be called again for each child reference where a listener was established to remove the observers.
    ///
    /// # Info:
    /// - Observers will be also removed from `refObservers` dictionary.
    func removeAllObservers(childPath: String = "/") throws -> Void {
        var removedKeys = [String]()
        refObservers.forEach { (model, _) in
            if model.childPath == childPath { refObservers.removeValue(forKey: model); removedKeys.append(model.key) }
        }
        guard removedKeys.count > 0 else { throw ServiceError.observerDoesntExist }
        dbRef.child(childPath).removeAllObservers()
        #if DEBUG
        print("ServiceDatabaseProtocol.removeAllObservers(): Removed observers[\(removedKeys.count)]: \(removedKeys)")
        #endif
    }
    
    /// It is a must to put this function in the deinit of Class.
    func deInit() {
        // Clean all observers before deinitialization!
        refObservers.keys.uniqued { model in model.childPath }.forEach { uniqueModel in
            dbRef.child(uniqueModel.childPath).removeAllObservers()
        }
    }

    // MARK: Helper Functions
    /// Turn unsafe child paths into safer by avoiding overwriting considering path hierarchy.
    ///
    ///     var str = ["/", "first", "first/second", "second", "third/four", "third/four/five", "third/six/seven"]
    ///     composePaths(str)
    ///     // ["/", "first", "second", "third/four", "third/six/seven"]
    /// - Parameter str: Unsafe path array may contain duplicated paths.
    /// - Returns: Safe path array free from overwriting for ref.updateChildValues().
    private func composePaths(_ str: [String]) -> [String] {
        var highestPaths = [String]()
        var higherPath: String?
        let sortedPaths = str.sorted()
        for path in sortedPaths {
            guard let validHigherPath = higherPath, path.hasPrefix(validHigherPath) else {
                highestPaths.append(path)
                higherPath = path
                continue
            }
        }
        #if DEBUG
        print("ServiceDatabaseProtocol.composePaths(): Composed from: \(str), to: \(highestPaths)")
        #endif
        return highestPaths
    }
    
    /// Decode DataSnapshot JSON value into its Swift Model.
    ///
    /// - Parameter snap: DataShapshot from observed or getData path.
    /// - Returns: Optional type safe value.
    private func snapDecoder<T: Codable>(_ snap: DataSnapshot) throws -> T? {
        guard let json = snap.value else { return nil }
        do {
            let model = try FirebaseDecoder().decode(T.self, from: json)
            #if DEBUG
            print("ServiceDatabaseProtocol.snapDecoder(): Model: \(model)")
            #endif
            return model
        } catch {
            throw ServiceError.decodingFailed
        }
    }
                
}
