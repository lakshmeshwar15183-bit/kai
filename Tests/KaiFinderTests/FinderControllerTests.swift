import XCTest
@testable import KaiFinder

final class FinderControllerTests: XCTestCase {
    private var root: URL!
    private var controller: LocalFileSystemController!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kai-fc-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        controller = LocalFileSystemController(trashDirectory: root.appendingPathComponent(".trash"))
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testTrashAndRestoreRoundTrip() async throws {
        let file = root.appendingPathComponent("doc.txt")
        try "hello".data(using: .utf8)!.write(to: file)

        let token = try await controller.moveToTrash(file)
        let goneAfterTrash = await controller.exists(file)
        XCTAssertFalse(goneAfterTrash)

        let restored = try await controller.restore(token)
        let backAgain = await controller.exists(restored)
        XCTAssertTrue(backAgain)
    }

    func testMoveRejectsOverwrite() async throws {
        let a = root.appendingPathComponent("a.txt")
        let b = root.appendingPathComponent("b.txt")
        try "a".data(using: .utf8)!.write(to: a)
        try "b".data(using: .utf8)!.write(to: b)
        do {
            try await controller.move(from: a, to: b)
            XCTFail("expected alreadyExists")
        } catch let error as FinderError {
            XCTAssertEqual(error, .alreadyExists(path: b.path))
        }
    }

    func testRename() async throws {
        let a = root.appendingPathComponent("old.txt")
        try "x".data(using: .utf8)!.write(to: a)
        let renamed = try await controller.rename(a, to: "new.txt")
        XCTAssertEqual(renamed.lastPathComponent, "new.txt")
        let exists = await controller.exists(renamed)
        XCTAssertTrue(exists)
    }
}
