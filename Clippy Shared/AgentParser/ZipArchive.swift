//
//  ZipArchive.swift
//  Clippy
//
//  Minimal ZIP reader, replacing the `unzip` step of the former `agents-unzip.sh`.
//
//  Only what a `.agent.zip` actually needs is supported: the central directory is
//  authoritative, entries are either stored or deflated, and nothing is encrypted.
//  `Compression`'s `COMPRESSION_ZLIB` is raw DEFLATE — the exact stream a ZIP
//  method-8 entry holds — so no zlib header is fed in or expected out.
//

import Foundation
import Compression

struct ZipArchiveEntry {
    let name: String
    let method: UInt16
    let compressedSize: Int
    let uncompressedSize: Int
    let localHeaderOffset: Int
}

enum ZipArchiveError: LocalizedError {
    case truncated
    case missingEndOfCentralDirectory
    case malformedCentralDirectory
    case unsupportedCompression(UInt16)
    case inflateFailed(name: String, got: Int, expected: Int)

    var errorDescription: String? {
        switch self {
        case .truncated:
            return "The archive ends unexpectedly."
        case .missingEndOfCentralDirectory:
            return "The archive has no central directory and is not a ZIP file."
        case .malformedCentralDirectory:
            return "The archive's central directory is corrupt."
        case .unsupportedCompression(let method):
            return "The archive uses unsupported compression method \(method)."
        case .inflateFailed(let name, let got, let expected):
            return "Could not decompress \"\(name)\" (got \(got) of \(expected) bytes)."
        }
    }
}

struct ZipArchive {
    private let data: Data

    init(url: URL) throws {
        data = try Data(contentsOf: url, options: .mappedIfSafe)
    }

    /// Every entry in the archive, in central-directory order.
    func entries() throws -> [ZipArchiveEntry] {
        let eocd = try endOfCentralDirectoryOffset()
        let count = Int(read16(eocd + 10))
        var offset = Int(read32(eocd + 16))
        var result: [ZipArchiveEntry] = []
        result.reserveCapacity(count)

        for _ in 0..<count {
            guard offset + 46 <= data.count, read32(offset) == 0x0201_4b50 else {
                throw ZipArchiveError.malformedCentralDirectory
            }
            let method = read16(offset + 10)
            let compressedSize = Int(read32(offset + 20))
            let uncompressedSize = Int(read32(offset + 24))
            let nameLength = Int(read16(offset + 28))
            let extraLength = Int(read16(offset + 30))
            let commentLength = Int(read16(offset + 32))
            let localHeaderOffset = Int(read32(offset + 42))
            guard offset + 46 + nameLength <= data.count else { throw ZipArchiveError.truncated }
            let name = String(decoding: data[(offset + 46)..<(offset + 46 + nameLength)], as: UTF8.self)
            result.append(ZipArchiveEntry(name: name,
                                          method: method,
                                          compressedSize: compressedSize,
                                          uncompressedSize: uncompressedSize,
                                          localHeaderOffset: localHeaderOffset))
            offset += 46 + nameLength + extraLength + commentLength
        }
        return result
    }

    /// The uncompressed bytes of a single entry.
    func data(for entry: ZipArchiveEntry) throws -> Data {
        let offset = entry.localHeaderOffset
        guard offset + 30 <= data.count, read32(offset) == 0x0403_4b50 else {
            throw ZipArchiveError.malformedCentralDirectory
        }
        // The local header repeats the name and may carry a *different* extra field
        // than the central directory, so the payload offset has to come from here.
        let nameLength = Int(read16(offset + 26))
        let extraLength = Int(read16(offset + 28))
        let start = offset + 30 + nameLength + extraLength
        guard start + entry.compressedSize <= data.count else { throw ZipArchiveError.truncated }
        let raw = data.subdata(in: start..<(start + entry.compressedSize))

        switch entry.method {
        case 0:
            return raw
        case 8:
            return try inflate(raw, entry: entry)
        default:
            throw ZipArchiveError.unsupportedCompression(entry.method)
        }
    }

    // MARK: - Inflation

    private func inflate(_ raw: Data, entry: ZipArchiveEntry) throws -> Data {
        if entry.uncompressedSize == 0 { return Data() }

        // A single `compression_decode_buffer` call can stop early on a large
        // stream, so the buffer is decoded in a loop until it is exhausted.
        var output = Data(count: entry.uncompressedSize)
        let produced: Int = output.withUnsafeMutableBytes { destination in
            guard let destinationBase = destination.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            var decoded: Int = 0
            while decoded < entry.uncompressedSize {
                let written = raw.withUnsafeBytes { source -> Int in
                    guard let sourceBase = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                    return compression_decode_buffer(destinationBase + decoded,
                                                     entry.uncompressedSize - decoded,
                                                     sourceBase,
                                                     entry.compressedSize,
                                                     nil,
                                                     COMPRESSION_ZLIB)
                }
                if written <= 0 { break }
                decoded += written
            }
            return decoded
        }

        guard produced == entry.uncompressedSize else {
            throw ZipArchiveError.inflateFailed(name: entry.name,
                                                got: produced,
                                                expected: entry.uncompressedSize)
        }
        return output
    }

    // MARK: - Little-endian primitives

    private func read16(_ offset: Int) -> UInt16 {
        return UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private func read32(_ offset: Int) -> UInt32 {
        return UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    /// Scans backwards for the end-of-central-directory record. It is the only
    /// fixed-position structure in a ZIP and may be followed by up to 64 KiB of
    /// archive comment, which is why this cannot be computed from the file size.
    private func endOfCentralDirectoryOffset() throws -> Int {
        guard data.count >= 22 else { throw ZipArchiveError.missingEndOfCentralDirectory }
        let earliest = max(0, data.count - 22 - 0xFFFF)
        var offset = data.count - 22
        while offset >= earliest {
            if read32(offset) == 0x0605_4b50 { return offset }
            offset -= 1
        }
        throw ZipArchiveError.missingEndOfCentralDirectory
    }
}
