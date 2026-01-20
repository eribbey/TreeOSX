import XCTest
@testable import Core

final class ScannerTests: XCTestCase {
    func testAggregatesDirectorySizes() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let fileA = tmp.appendingPathComponent("a.txt")
        let fileB = tmp.appendingPathComponent("b.txt")
        let dataA = Data(repeating: 0x11, count: 1024)
        let dataB = Data(repeating: 0x22, count: 2048)
        try dataA.write(to: fileA)
        try dataB.write(to: fileB)

        let scanner = Scanner()
        let result = try await scanner.scan(rootPath: tmp.path, options: ScanOptions()) { _ in }
        XCTAssertEqual(result.root.children.count, 2)
        XCTAssertEqual(result.root.metrics.logicalBytes, 3072)
    }

    func testSymlinkNotFollowedByDefault() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let dir = tmp.appendingPathComponent("dir")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let link = tmp.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: dir)

        let scanner = Scanner()
        let result = try await scanner.scan(rootPath: tmp.path, options: ScanOptions()) { _ in }
        let linkNode = result.root.children.first { $0.name == "link" }
        XCTAssertNotNil(linkNode)
        XCTAssertEqual(linkNode?.kind, .symlink)
    }
}
