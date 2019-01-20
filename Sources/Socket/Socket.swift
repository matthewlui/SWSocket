//
//  Socket.swift
//  Sweet
//
//  Copyright (c) <2019> <Matthew Lui>
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the Software
//  is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

let posixSocket = socket
let posixBind = bind
let posixClose = close
let posixListen = listen
let posixAccept = accept

public typealias CSocket = CInt

public protocol Socket {
    associatedtype SocketType

    var socket: SocketType { get }

    init(socket: SocketType)

    func bind(ip: String, port: UInt8) throws
    func close() throws
}

public protocol SocketListening {
    func listen()
    func accept() throws -> SocketListening
}

public protocol POSIXSocket: Socket, SocketListening {

    typealias SocketType = CInt

    static func createSocket(proto: CInt, type: CInt, blocking: Bool) throws -> Self

    var maxConnection: CInt { get }
}

public extension POSIXSocket {
    static func createSocket(proto: CInt = AF_INET, type: CInt = SOCK_STREAM, blocking: Bool = false) throws -> Self {
        var target = type
        #if os(Linux)
        if !blocking {
            target = type | Linux.SOCK_NONBLOCK
        }
        #endif
        let socket = posixSocket(proto, target, 0)
        if proto == AF_INET6 {
            let socklen = socklen_t(MemoryLayout.size(ofValue: CInt.self))
            setsockopt(socket, IPPROTO_IPV6, IPV6_V6ONLY, nil, socklen)
        }
        return Self.init(socket: socket)
    }

    func bind(ip: String, port: UInt8) throws {
        var addr = sockaddr_in()
        addr.sin_len = __uint8_t(MemoryLayout.size(ofValue: sockaddr_in.self))
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr(ip)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        var socketAddr = sockaddr()
        memcpy(&socketAddr, &addr, MemoryLayout.size(ofValue: sockaddr_in.self))
        let len = socklen_t(MemoryLayout.size(ofValue: sockaddr_in.self))
        if posixBind(socket, &socketAddr, len) == -1 {
            try close()
            throw SWTSocketCreateError.BindError
        }
    }

    func close() throws {
        shutdown(socket, SHUT_RDWR)
        posixClose(socket)
    }
}

extension POSIXSocket {
    func listen() throws {
        if posixListen(socket, maxConnection) == -1 {
            throw SWTSocketListeningError.RequestNotAccept
        }
    }

    func accept() throws -> Self {
        var socketIn = sockaddr_in()
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        var incoming: CInt
        try UnsafeMutablePointer.withMemoryRebound(&socketIn)(to: sockaddr.self, capacity: 1, { ptr in
            #if os(Linux)
            // Use accept4 when available to prevent posix block
            incoming = Linux.accept4(socket, ptr, &size)
            #else
            incoming = posixAccept(socket, ptr, &size)
            #endif
        })
        if incoming < 0 {
            throw SWTSocketListeningError.RequestNotAccept
        }
        return Self.init(socket: incoming)
    }
}
