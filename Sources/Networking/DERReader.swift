import Foundation

/// Minimal ASN.1 DER reader, only covering what's needed to unwrap a
/// PKCS#8 PrivateKeyInfo down to the inner PKCS#1 RSAPrivateKey blob
/// that SecKeyCreateWithData expects.
struct DERReader {
    private let data: Data
    private var offset: Int = 0

    init(data: Data) {
        self.data = data
    }

    private mutating func readByte() throws -> UInt8 {
        guard offset < data.count else { throw JWTSignerError.invalidPEM }
        defer { offset += 1 }
        return data[data.startIndex + offset]
    }

    private mutating func readLength() throws -> Int {
        let first = try readByte()
        if first & 0x80 == 0 {
            return Int(first)
        }
        let byteCount = Int(first & 0x7F)
        var length = 0
        for _ in 0..<byteCount {
            length = (length << 8) | Int(try readByte())
        }
        return length
    }

    /// Enters a SEQUENCE: consumes its tag + length header only, leaving
    /// the read cursor positioned at its first child element.
    mutating func enterSequence() throws {
        let tag = try readByte()
        guard tag == 0x30 else { throw JWTSignerError.invalidPEM }
        _ = try readLength()
    }

    /// Skips an entire SEQUENCE (tag + length + content) without entering it.
    mutating func skipSequence() throws {
        let tag = try readByte()
        guard tag == 0x30 else { throw JWTSignerError.invalidPEM }
        let length = try readLength()
        guard offset + length <= data.count else { throw JWTSignerError.invalidPEM }
        offset += length
    }

    @discardableResult
    mutating func readInteger() throws -> Data {
        try readTLV(expectedTag: 0x02)
    }

    mutating func readOctetString() throws -> Data {
        try readTLV(expectedTag: 0x04)
    }

    private mutating func readTLV(expectedTag: UInt8) throws -> Data {
        let tag = try readByte()
        guard tag == expectedTag else { throw JWTSignerError.invalidPEM }
        let length = try readLength()
        guard offset + length <= data.count else { throw JWTSignerError.invalidPEM }
        let start = data.startIndex + offset
        let value = data.subdata(in: start..<(start + length))
        offset += length
        return value
    }
}
