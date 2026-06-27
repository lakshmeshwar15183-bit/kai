import XCTest
@testable import KaiVoice
import KaiCore

final class VoiceSessionTests: XCTestCase {
    private func makeSession(state: VoiceState = .sleeping) -> (VoiceSession, StopController) {
        let stop = StopController()
        return (VoiceSession(wakePhrase: "hey kai", state: state, stopController: stop), stop)
    }

    func testSleepingIgnoresNonWakeSpeech() async {
        let (session, _) = makeSession()
        let event = await session.handle("what's the weather")
        XCTAssertEqual(event, .ignoredWhileSleeping)
        let state = await session.state
        XCTAssertEqual(state, .sleeping)
    }

    func testWakePhraseWakes() async {
        let (session, _) = makeSession()
        let event = await session.handle("Hey Kai")
        XCTAssertEqual(event, .wokeUp)
        let state = await session.state
        XCTAssertEqual(state, .listening)
    }

    func testStopWordHaltsAndSleepsFromAnyState() async {
        let (session, stop) = makeSession(state: .listening)
        let event = await session.handle("stop")
        XCTAssertEqual(event, .stopped(.stop))
        let requested = await stop.isStopRequested
        XCTAssertTrue(requested)
        let state = await session.state
        XCTAssertEqual(state, .sleeping)
    }

    func testAwakeReturnsCommandAndStripsWakePrefix() async {
        let (session, _) = makeSession(state: .listening)
        let event = await session.handle("Hey Kai, open Safari")
        XCTAssertEqual(event, .command("open Safari"))
    }

    func testGoToSleep() async {
        let (session, _) = makeSession(state: .listening)
        let event = await session.handle("go to sleep")
        XCTAssertEqual(event, .wentToSleep)
        let state = await session.state
        XCTAssertEqual(state, .sleeping)
    }
}
