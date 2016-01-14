//
//  JSON.swift
//  TCP
//
//  Created by Chris Eidhof on 14-01-16.
//  Copyright © 2016 Chris Eidhof. All rights reserved.
//

import Foundation

extension Dictionary {
    func string(key: Key) throws-> String {
        guard let result = self[key] as? String else {
            throw "Expected \(key) to be a String"
        }
        return result
    }
    func int(key: Key) throws -> Int {
        guard let result = self[key] as? Int else {
            throw "Expected \(key) to be an Int"
        }
        return result
    }
    func bool(key: Key) throws -> Bool {
        guard let result = self[key] as? Bool else {
            throw "Expected \(key) to be a Bool"
        }
        return result
    }
    func array<A>(key: Key) throws -> [A] {
        guard let result = self[key] as? [A] else {
            throw "Expected \(key) to be an Array"
        }
        return result
    }
    func raw<A: RawRepresentable>(key: Key) throws -> A {
        guard let rawResult = self[key] as? A.RawValue,
            let result = A(rawValue: rawResult)
            else {
                throw "Expected \(key) to be a(n) \(A.self)"
        }
        return result
    }
}

extension Array {
  /// Works like map, but if multiple elements throw, the errors are combined
  func mapAll<A>(f: Element throws -> A) throws -> [A] {
    var errors: [ErrorType] = []
    var result: [A] = []
    for item in self {
      do {
        result.append(try f(item))
      } catch {
        errors.append(error)
      }
    }
    guard errors.count != 1 else { throw errors[0] }
    guard errors.isEmpty else { throw MultipleErrors(errors: errors) }
    return result
  }
}
