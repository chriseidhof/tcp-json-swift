//
//  Errors.swift
//  TCP
//
//  Created by Chris Eidhof on 14-01-16.
//  Copyright © 2016 Chris Eidhof. All rights reserved.
//

import Foundation

infix operator !! { }

func !!<A>(lhs: A?, rhs: ErrorType) throws -> A {
    guard let result = lhs else { throw rhs }
    return result
}

struct MultipleErrors: ErrorType {
    let errors: [ErrorType]
}

/// Try to compute both values. If both fail, a MultipleErrors error is returned.
func all<A,B>(
    @autoclosure a: () throws -> A,
    @autoclosure _ b: () throws -> B
    ) throws -> (A,B) {
        var errors: [ErrorType] = []
        var aR: A? = nil
        var bR: B? = nil
        do { aR = try a() } catch { errors.append(error) }
        do { bR = try b() } catch { errors.append(error) }
        guard errors.isEmpty else { throw MultipleErrors(errors: errors) }
        return (aR!, bR!)
}

/// Try to compute all three values. If multiple fail, a MultipleErrors error is returned.
func all<A,B,C>(
    @autoclosure   a: () throws -> A,
    @autoclosure _ b: () throws -> B,
    @autoclosure _ c: () throws -> C
    ) throws -> (A,B,C) {
        var errors: [ErrorType] = []
        var aR: A? = nil
        var bR: B? = nil
        var cR: C? = nil
        do { aR = try a() } catch { errors.append(error) }
        do { bR = try b() } catch { errors.append(error) }
        do { cR = try c() } catch { errors.append(error) }
        guard errors.count != 1 else { throw errors[0] }
        guard errors.isEmpty else { throw MultipleErrors(errors: errors) }
        return (aR!, bR!, cR!)
}


/// Try to compute all four values. If multiple fail, a MultipleErrors error is returned.
func all<A,B,C,D>(
    @autoclosure   a: () throws -> A,
    @autoclosure _ b: () throws -> B,
    @autoclosure _ c: () throws -> C,
    @autoclosure _ d: () throws -> D
    ) throws -> (A,B,C,D) {
        var errors: [ErrorType] = []
        var aR: A? = nil
        var bR: B? = nil
        var cR: C? = nil
        var dR: D? = nil
        do { aR = try a() } catch { errors.append(error) }
        do { bR = try b() } catch { errors.append(error) }
        do { cR = try c() } catch { errors.append(error) }
        do { dR = try d() } catch { errors.append(error) }
        guard errors.count != 1 else { throw errors[0] }
        guard errors.isEmpty else { throw MultipleErrors(errors: errors) }
        return (aR!, bR!, cR!, dR!)
}
