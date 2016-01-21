//  Created by Chris Eidhof on 04-01-16.
//  Copyright © 2016 Chris Eidhof. All rights reserved.
//
// Large parts copy/pasted from https://github.com/Eonil/TCPIPSocket.Swift

import Darwin

struct TCPIPSocketAddress {
    init(_ a:UInt8, _ b:UInt8, _ c:UInt8, _ d:UInt8) {
        let	a1	=	UInt32(a) << 24
        let	b1	=	UInt32(b) << 16
        let	c1	=	UInt32(c) << 8
        let	d1	=	UInt32(d)
        number	=	a1 + b1 + c1 + d1
    }
    var number:UInt32		///	Uses host-endian.
    
    static let localhost = TCPIPSocketAddress(127,0,0,1)
}

final class TCPIPConnection {
    static let bufLen = 1024
    private var data: [UInt8] = Array(count: bufLen, repeatedValue: 0) // Keep it around for efficiency
    private let _conn: Int32
    
    private init(_ conn: Int32) throws {
        _conn = conn
        try postconditionDarwinAPICallResultCodeState(_conn > 0)
    }
    
    func read() -> ReadResult {
        while true {
            let n = Darwin.read(_conn, &data, TCPIPConnection.bufLen)
            guard n != 0 else { return .Empty }
            guard n > 0 else { return .Error("Read error \(n)")  }
            return .Chunk(AnySequence(data.prefix(n)))
        }
    }
    
    func write(bytes: [UInt8]) throws {
        let r = Darwin.write(_conn, bytes, bytes.count)
        try postconditionDarwinAPICallResultCodeState(r == bytes.count)
    }
    
    func close() {
        Darwin.close(_conn)
    }
}

enum ReadResult {
    case Error(ErrorType)
    case Empty
    case Chunk(AnySequence<UInt8>)
}

final class TCPIPSocket {
    let	socketDescriptor:Int32
    private var ds : dispatch_source_t?
    var handler: TCPIPConnection throws -> () = { _ in () }
    
    init(address: TCPIPSocketAddress, port: UInt16) throws {
        socketDescriptor =	Darwin.socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)
        var options: Int32 = 1
        setsockopt(socketDescriptor, SOL_SOCKET, SO_REUSEADDR, &options, socklen_t(sizeofValue(options)))

        try postconditionDarwinAPICallResultCodeState(socketDescriptor != -1)
        try bind(address, port)
    }
    
    deinit {
        let	r =	close(socketDescriptor)
        try! postconditionDarwinAPICallResultCodeState(r == 0)
    }
    
    private func bind(address: TCPIPSocketAddress, _ port: UInt16) throws {
        let	f		=	sa_family_t(AF_INET)
        let	p		=	in_port_t(port.bigEndian)
        let	a		=	in_addr(s_addr: address.number.bigEndian)
        var	addr	=	sockaddr_in(sin_len: 0, sin_family: f, sin_port: p, sin_addr: a, sin_zero: (0,0,0,0,0,0,0,0))
        let	sz		=	socklen_t(sizeofValue(addr))
        let r  = Darwin.bind(socketDescriptor, unsafePointerCast(&addr), sz)
        try postconditionDarwinAPICallResultCodeState(r == 0)
    }
    
    func listen(handler: TCPIPConnection throws -> ()) throws {
        self.handler = handler
        let r = Darwin.listen(socketDescriptor, SOMAXCONN)
        try postconditionDarwinAPICallResultCodeState(r == 0)
        ds = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(socketDescriptor), 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
        guard let source = ds else { throw "Couldn't create dispatch source" }
        dispatch_source_set_event_handler(source, self.handleConnection)
        dispatch_resume(source)
    }
    
    func handleConnection() {
        do {
            let connection = try TCPIPConnection(Darwin.accept(socketDescriptor, nil, nil))
            try handler(connection)
        } catch {
            print(error)
        }
    }
}

extension String: ErrorType { }

private func postconditionDarwinAPICallResultCodeState(ok:Bool) throws {
    if ok { return }
    
    let	n	=	Darwin.errno
    let	s	=	String(UTF8String: strerror(n))
    throw "Darwin API call error: (\(n)) \(s)"
}

private func unsafePointerCast<T,U>(p:UnsafePointer<T>) -> UnsafePointer<U> {
    return	UnsafePointer<U>(p)
}

// A wrapper that allows us to process byte arrays

enum Action {
    case ProcessedBytes(count: Int)
    case Write(bytes: [UInt8])
    case CloseConnection(message: String)
}

import Foundation


func bufferedBytesReader(processBytes: [UInt8] -> [Action]) -> TCPIPConnection throws -> () {
    var queue = dispatch_queue_create("read bytes", DISPATCH_QUEUE_SERIAL)

    return { connection in
        var theError: ErrorType?
        dispatch_sync(queue) {
            do {
                var result: [UInt8] = []
                while true {
                    switch connection.read() {
                    case .Empty: continue
                    case .Chunk(let chunk):
                        result += chunk
                    case .Error(let error): throw error
                    }
                    for action in processBytes(result) {
                        switch action {
                        case .ProcessedBytes(let count):
                            result[0..<count] = []
                        case .Write(let bytes):
                            try connection.write(bytes)
                        case .CloseConnection(let message):
                            print(message)
                            connection.close()
                            return
                        }
                    }
                }
            } catch {
                theError = error
            }
        }
        if theError != nil { throw theError! }
    }
}

extension UInt8 {
    static private var pattern32: UInt32  = UInt32(UInt8.max)
    init(truncating: UInt32) {
        self = UInt8(truncating & UInt8.pattern32)
    }
    
    static private var pattern16: UInt16  = UInt16(UInt8.max)
    init(truncating: UInt16) {
        self = UInt8(truncating & UInt8.pattern16)
    }

}


extension UInt16 {
    init(bytes: ArraySlice<UInt8>) {
        precondition(bytes.count == 2)
        self = UInt16(bytes[1]) << 8 | UInt16(bytes[0])
    }
    var bytes: [UInt8] {
        return [UInt8(truncating: self) , UInt8(truncating: self >> 8)]
    }
}

extension UInt32 {
    init(bytes: ArraySlice<UInt8>) {
        precondition(bytes.count == 4)
        self = UInt32(bytes[bytes.startIndex])
        self |= UInt32(bytes[bytes.startIndex + 1]) << 8
        self |= UInt32(bytes[bytes.startIndex + 2]) << 16
        self |= UInt32(bytes[bytes.startIndex + 3]) << 24
    }
    var bytes: [UInt8] {
        return [UInt8(truncating: self) , UInt8(truncating: self >> 8), UInt8(truncating: self >> 16), UInt8(truncating: self >> 24)]
    }
}

import Foundation

extension NSData {
    var uint8Bytes: [UInt8] {
        var result: [UInt8] = Array(count: self.length, repeatedValue: 0)
        self.getBytes(&result, length: self.length)
        return result
    }
}

func jsonToBytes(json: AnyObject) throws -> [UInt8] {
    let data = try NSJSONSerialization.dataWithJSONObject(json, options: NSJSONWritingOptions())
    return UInt16(206).bytes + UInt32(data.length).bytes + data.uint8Bytes
}

/// Given a callback, this function tries to read an entire json-over-tcp
/// message. It uses the same protocol as https://www.npmjs.com/package/json-over-tcp
func jsonReader(callback: AnyObject -> AnyObject?) -> [UInt8] -> [Action] {
    return { result in
        guard result.count >= 6 else { return [] }
        guard UInt16(bytes: result[0...1]) == 206 else {
            return [.CloseConnection(message: "Invalid protocol identifier, expected 206")]
        }
        let length = UInt32(bytes: result[2..<6])
        let lastIndex = 6 + Int(length)
        guard result.endIndex >= lastIndex else { return [] }
        
        var dataBytes = Array(result[6..<lastIndex])
        let data = NSData(bytes: &dataBytes, length: dataBytes.count)
        guard let json = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) else {
            return [.CloseConnection(message: "Invalid JSON")]
        }
        var result: [Action] = [.ProcessedBytes(count: lastIndex)]
        if let resultValue = callback(json), bytes = try? jsonToBytes(resultValue) {
            result.append(.Write(bytes: bytes))
        }
        return result
    }
}

class JSONSocket {
    var connections: [TCPIPConnection] = []
    var queue = dispatch_queue_create("json socket queue", DISPATCH_QUEUE_SERIAL)
    var socket: TCPIPSocket?
    
    init(port: Int, listen: AnyObject -> AnyObject?) throws {
        socket = try TCPIPSocket(address: TCPIPSocketAddress.localhost, port: UInt16(port))
        try socket?.listen { [unowned self] connection in
            dispatch_async(self.queue) { [unowned self] in
                self.connections.append(connection)
            }
            let reader = bufferedBytesReader(jsonReader(listen))
            dispatch_async(dispatch_get_global_queue(0, 0)) {
                _ = try? reader(connection)
            }
        }
    }
    
    /// Write to all connections
    func writeAll(json: AnyObject) {
        dispatch_async(queue) { [unowned self] in
            do { try self._writeAll(json) } catch { }
        }
    }
    
    func _writeAll(json: AnyObject) throws {
        // This should all be done on a serial queue
        let bytes = try jsonToBytes(json)
        for (idx, connection) in connections.enumerate() {
            do { try connection.write(bytes)  } catch {
                connection.close()
                connections.removeAtIndex(idx)
            }
        }
    }
    
    deinit {
        connections.forEach { $0.close() }
    }
}