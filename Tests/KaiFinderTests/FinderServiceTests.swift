import XCTest
@testable import KaiFinder

final class FinderServiceTests: XCTestCase {
    private var root: URL!
    private var controller: LocalFileSystemController!
    private var service: FinderService!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kai-finder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        controller = LocalFileSystemController(trashDirectory: root.appendingPathComponent(".trash"))
        service = FinderService(controller: controller)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ name: String, _ contents: String) throws {
        try contents.data(using: .utf8)!.write(to: root.appendingPathComponent(name))
    }

    func testOrganizeByType() async throws {
        try write("photo.png", "img")
        try write("notes.txt", "text")
        try write("report.pdf", "pdf")

        let counts = try await service.organizeByType(in: root)
        XCTAssertEqual(counts["Images"], 1)
        XCTAssertEqual(counts["Documents"], 1)
        XCTAssertEqual(counts["PDFs"], 1)

        let imageMoved = await controller.exists(root.appendingPathComponent("Images/photo.png"))
        XCTAssertTrue(imageMoved)
    }

    func testFindDuplicates() async throws {
        try write("a.txt", "identical content")
        try write("b.txt", "identical content")
        try write("c.txt", "different")

        let groups = try await service.findDuplicates(in: root)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.items.count, 2)
        XCTAssertEqual(groups.first?.redundant.count, 1)
    }

    func testSearch() async throws {
        try write("budget-2026.csv", "x")
        try write("vacation.png", "y")
        let results = try await service.search(in: root, matching: "budget")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "budget-2026.csv")
    }

    func testSHA256KnownVector() {
        // SHA-256("abc") known digest.
        let digest = SHA256.hexDigest(Data("abc".utf8))
        XCTAssertEqual(digest, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
