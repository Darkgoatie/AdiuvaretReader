import Foundation
import Compression

/// Builds small ZIP files for tests. CRC is left zero because the reader does not check it.
struct ZipBuilder {
    var files: [(name: String, data: Data, deflate: Bool)] = []

    mutating func add(_ name: String, _ text: String, deflate: Bool = false) {
        files.append((name, Data(text.utf8), deflate))
    }

    func build() -> Data {
        var out = Data()
        var central = Data()
        func le16(_ v: Int) -> Data { Data([UInt8(v & 255), UInt8((v >> 8) & 255)]) }
        func le32(_ v: Int) -> Data { le16(v & 0xFFFF) + le16((v >> 16) & 0xFFFF) }
        for f in files {
            var payload = f.data
            var method = 0
            if f.deflate, !f.data.isEmpty {
                var buf = [UInt8](repeating: 0, count: f.data.count + 1024)
                let n = f.data.withUnsafeBytes { src in
                    compression_encode_buffer(&buf, buf.count, src.bindMemory(to: UInt8.self).baseAddress!, f.data.count, nil, COMPRESSION_ZLIB)
                }
                payload = Data(buf.prefix(n))
                method = 8
            }
            let name = Data(f.name.utf8)
            let offset = out.count
            out += le32(0x04034b50) + le16(20) + le16(0) + le16(method) + le16(0) + le16(0) + le32(0)
            out += le32(payload.count) + le32(f.data.count) + le16(name.count) + le16(0) + name + payload
            central += le32(0x02014b50) + le16(20) + le16(20) + le16(0) + le16(method) + le16(0) + le16(0) + le32(0)
            central += le32(payload.count) + le32(f.data.count) + le16(name.count) + le16(0) + le16(0) + le16(0) + le16(0) + le32(0) + le32(offset) + name
        }
        let cdOffset = out.count
        out += central
        out += le32(0x06054b50) + le16(0) + le16(0) + le16(files.count) + le16(files.count) + le32(central.count) + le32(cdOffset) + le16(0)
        return out
    }
}
