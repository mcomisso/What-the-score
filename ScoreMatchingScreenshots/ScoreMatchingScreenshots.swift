import XCTest

class ScoreMatchingScreenshots: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    func testExample() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        snapshot("Launch page")

        (0...10).forEach { _ in
            if Bool.random() {
                app.tap()
            }
        }

        snapshot("Scored")

        // Settings
        app.buttons.firstMatch.tap()

        snapshot("Settings")
    }

    func testScoreboardAndSettingsAcrossOrientations() throws {
        let app = XCUIApplication()
        app.launch()

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Dismiss"].tap()

        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    func testSwipingScoreInAnyDirectionRemovesExactlyOnePoint() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-currentSportSelection", ""]
        app.launch()

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.press(forDuration: 1)
        app.buttons["Reset all"].tap()

        let teams = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", score "))
        let team = teams.firstMatch
        XCTAssertTrue(team.waitForExistence(timeout: 5))
        XCTAssertEqual(teams.count, 2, "All-direction swipes require the default, non-scrolling scoreboard")
        let scoreLabelPrefix = try XCTUnwrap(team.label.range(of: ", score ", options: .backwards))
        let teamName = String(team.label[..<scoreLabelPrefix.lowerBound])

        func assertScore(_ value: Int, file: StaticString = #filePath, line: UInt = #line) {
            let expected = NSPredicate(format: "label == %@", "\(teamName), score \(value)")
            let expectation = XCTNSPredicateExpectation(predicate: expected, object: team)
            XCTAssertEqual(
                XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
                "Expected score \(value), found '\(team.label)' at \(team.frame)",
                file: file, line: line
            )
        }

        assertScore(0)
        team.tap()
        assertScore(1)
        team.tap()
        assertScore(2)

        let swipes: [(start: CGVector, end: CGVector)] = [
            (CGVector(dx: 0.75, dy: 0.5), CGVector(dx: 0.25, dy: 0.5)),
            (CGVector(dx: 0.25, dy: 0.5), CGVector(dx: 0.75, dy: 0.5)),
            (CGVector(dx: 0.5, dy: 0.75), CGVector(dx: 0.5, dy: 0.25)),
            (CGVector(dx: 0.5, dy: 0.25), CGVector(dx: 0.5, dy: 0.75))
        ]
        for swipe in swipes {
            team.coordinate(withNormalizedOffset: swipe.start)
                .press(forDuration: 0.05, thenDragTo: team.coordinate(withNormalizedOffset: swipe.end))
            assertScore(1)
            team.tap()
            assertScore(2)
        }

        team.press(forDuration: 1)
        XCTAssertFalse(app.buttons["Add 1"].exists)
        XCTAssertTrue(settings.isHittable)

        settings.tap()
        let addTeam = app.buttons["Add team"]
        XCTAssertTrue(addTeam.waitForExistence(timeout: 5))
        for _ in 0..<4 {
            if !addTeam.isHittable { app.swipeUp() }
            addTeam.tap()
        }
        app.buttons["Dismiss"].tap()
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertEqual(teams.count, 6, "The scrolling check requires six teams")

        team.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.75))
            .press(forDuration: 0.05, thenDragTo: team.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.75)))
        assertScore(1)

        let secondTeam = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Team B, score ")).firstMatch
        secondTeam.tap()
        secondTeam.tap()
        XCTAssertEqual(secondTeam.label, "Team B, score 2")
        let initialY = secondTeam.frame.minY
        let beforeScroll = XCTAttachment(screenshot: app.screenshot())
        beforeScroll.name = "Overflow scoreboard before vertical swipe"
        add(beforeScroll)
        secondTeam.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            .press(forDuration: 0.05, thenDragTo: secondTeam.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
        let scrolled = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in secondTeam.frame.minY < initialY - 20 },
            object: secondTeam
        )
        let scrollResult = XCTWaiter.wait(for: [scrolled], timeout: 5)
        let afterScroll = XCTAttachment(screenshot: app.screenshot())
        afterScroll.name = "Overflow scoreboard after vertical swipe"
        add(afterScroll)
        XCTAssertEqual(
            scrollResult, .completed,
            "An overflowing scoreboard must remain scrollable. Team B y: \(initialY) -> \(secondTeam.frame.minY); scroll view: \(app.scrollViews.firstMatch.frame)"
        )
        XCTAssertEqual(secondTeam.label, "Team B, score 2", "Scrolling must not change the score")
    }

//    func testLaunchPerformance() throws {
//        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
//            // This measures how long it takes to launch your application.
//            measure(metrics: [XCTApplicationLaunchMetric()]) {
//                XCUIApplication().launch()
//            }
//        }
//    }
}
