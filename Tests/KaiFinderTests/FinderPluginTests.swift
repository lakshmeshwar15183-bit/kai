import XCTest
@testable import KaiFinder
import KaiCore
import KaiPlugins
import KaiAI
import KaiMemory

final class FinderCommandParserTests: XCTestCase {
    private let parser = FinderCommandParser()

    func testParsesIntents() {
        XCTAssertEqual(parser.parse("undo"), .undo)
        if case .organize? = parser.parse("organize ~/Downloads") {} else { XCTFail("organize") }
        if case .findDuplicates? = parser.parse("find duplicates in ~/Downloads") {} else { XCTFail("dupes") }
        if case let .search(query, _)? = parser.parse("search budget in ~/Documents") {
            XCTAssertEqual(query, "budget")
        } else { XCTFail("search") }
        if case let .rename(_, newName)? = parser.parse("rename ~/a.txt to b.txt") {
            XCTAssertEqual(newName, "b.txt")
        } else { XCTFail("rename") }
        XCTAssertNil(parser.parse("what is the weather"))
    }
}

final class FinderPluginTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kai-fp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDown() async throws { try? FileManager.default.removeItem(at: root) }

    private func services(_ stop: StopController) -> PluginServices {
        PluginServices(ai: EchoAIProvider(), memory: InMemoryStore(),
                       logger: KaiLogger(minimumLevel: .error), stopController: stop, eventBus: EventBus())
    }

    func testTrashThenUndoRestoresFile() async throws {
        let file = root.appendingPathComponent("delete-me.txt")
        try "bye".data(using: .utf8)!.write(to: file)

        let controller = LocalFileSystemController(trashDirectory: root.appendingPathComponent(".trash"))
        let plugin = FinderPlugin(controller: controller)
        let stop = StopController()

        let trashResult = try await plugin.handle(KaiCommand(text: "trash \(file.path)"), services: services(stop))
        XCTAssertTrue(trashResult.didSucceed)
        let gone = !FileManager.default.fileExists(atPath: file.path)
        XCTAssertTrue(gone)

        let undoResult = try await plugin.handle(KaiCommand(text: "undo"), services: services(stop))
        XCTAssertTrue(undoResult.didSucceed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testSearchCapabilityIsReadOnly() {
        let plugin = FinderPlugin(controller: LocalFileSystemController())
        XCTAssertEqual(plugin.capability(for: KaiCommand(text: "search x in ~/Documents"))?.sideEffect, false)
        XCTAssertEqual(plugin.capability(for: KaiCommand(text: "organize ~/Downloads"))?.sideEffect, true)
    }
}
