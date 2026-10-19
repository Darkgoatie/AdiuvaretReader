import Foundation
import Compression

public enum ZipError: Error, Equatable {
    case notAnArchive
    case unsupported
    case corrupt
    case unsafePath
}

/// Reads stored and deflated entries from a ZIP file held in memory. Zip64 and encryption are not supported.
public struct ZipArchive: Sendable {
    public struct Entry: Sendable, Equatable {
        public let name: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localOffset: Int
        public var isDirectory: Bool { name.hasSuffix("/") }
    }

    private let data: Data
    public let entries: [Entry]

    public init(data: Data) throws {
        let data = Data(data)
        self.data = data
        guard data.count >= 22 else { throw ZipError.notAnArchive }
        func u16(_ o: Int) -> Int { Int(data[o]) | Int(data[o + 1]) << 8 }
        func u32(_ o: Int) -> Int { u16(o) | u16(o + 2) << 16 }

        var eocd = -1
        var i = data.count - 22
        let lowest = max(0, data.count - 22 - 65535)
        while i >= lowest {
            if u32(i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw ZipError.notAnArchive }
        let count = u16(eocd + 10)
        var offset = u32(eocd + 16)
        if count == 0xFFFF || offset == 0xFFFF_FFFF { throw ZipError.unsupported }

        var found: [Entry] = []
        for _ in 0..<count {
            guard offset + 46 <= data.count, u32(offset) == 0x02014b50 else { throw ZipError.corrupt }
            let flags = u16(offset + 8)
            let method = UInt16(u16(offset + 10))
            let csize = u32(offset + 20)
            let usize = u32(offset + 24)
            let nameLen = u16(offset + 28)
            let extraLen = u16(offset + 30)
            let commentLen = u16(offset + 32)
            let local = u32(offset + 42)
            guard offset + 46 + nameLen <= data.count else { throw ZipError.corrupt }
            if flags & 1 != 0 { throw ZipError.unsupported }
            let nameData = data.subdata(in: (offset + 46)..<(offset + 46 + nameLen))
            let name = String(data: nameData, encoding: .utf8) ?? String(decoding: nameData, as: UTF8.self)
            found.append(Entry(name: name, method: method, compressedSize: csize, uncompressedSize: usize, localOffset: local))
            offset += 46 + nameLen + extraLen + commentLen
        }
        entries = found
    }

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url, options: .mappedIfSafe))
    }

    public func entry(named name: String) -> Entry? { entries.first { $0.name == name } }

    public func data(for entry: Entry) throws -> Data {
        func u16(_ o: Int) -> Int { Int(data[o]) | Int(data[o + 1]) << 8 }
        let base = entry.localOffset
        guard base + 30 <= data.count,
              Int(data[base]) | Int(data[base + 1]) << 8 | Int(data[base + 2]) << 16 | Int(data[base + 3]) << 24 == 0x04034b50
        else { throw ZipError.corrupt }
        let start = base + 30 + u16(base + 26) + u16(base + 28)
        let end = start + entry.compressedSize
        guard start <= end, end <= data.count else { throw ZipError.corrupt }
        let slice = data.subdata(in: start..<end)
        switch entry.method {
        case 0:
            return slice
        case 8:
            if entry.uncompressedSize == 0 { return Data() }
            var out = Data(count: entry.uncompressedSize)
            let written = out.withUnsafeMutableBytes { dst -> Int in
                slice.withUnsafeBytes { src -> Int in
                    guard let d = dst.bindMemory(to: UInt8.self).baseAddress, let s = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                    return compression_decode_buffer(d, dst.count, s, src.count, nil, COMPRESSION_ZLIB)
                }
            }
            guard written == entry.uncompressedSize else { throw ZipError.corrupt }
            return out
        default:
            throw ZipError.unsupported
        }
    }

    public func data(named name: String) throws -> Data? {
        guard let e = entry(named: name) else { return nil }
        return try data(for: e)
    }

    /// Writes every file under `directory`. Entries whose path would leave it are rejected.
    public func extractAll(to directory: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let rootPath = directory.standardizedFileURL.path
        for e in entries {
            let parts = e.name.split(separator: "/", omittingEmptySubsequences: true)
            if e.name.hasPrefix("/") || parts.contains("..") { throw ZipError.unsafePath }
            let target = directory.appendingPathComponent(e.name).standardizedFileURL
            guard target.path.hasPrefix(rootPath) else { throw ZipError.unsafePath }
            if e.isDirectory {
                try fm.createDirectory(at: target, withIntermediateDirectories: true)
            } else {
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data(for: e).write(to: target, options: .atomic)
            }
        }
    }
}
