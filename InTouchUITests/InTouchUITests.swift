import XCTest

final class InTouchUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testRejectingPeopleExhaustsThePoolAndCanBeUndone() {
        app.buttons["suggestButton"].tap()
        XCTAssertEqual(app.staticTexts["suggestedContactName"].label, "Alex Morgan")

        app.buttons["rejectButton"].tap()
        XCTAssertEqual(app.staticTexts["suggestedContactName"].label, "Beatrice Nilsson")

        app.buttons["rejectButton"].tap()
        XCTAssertEqual(app.staticTexts["suggestedContactName"].label, "Chris Lee")

        app.buttons["rejectButton"].tap()
        XCTAssertTrue(app.staticTexts["No one left in the hat"].waitForExistence(timeout: 2))

        app.buttons["Review excluded people"].tap()
        XCTAssertTrue(app.staticTexts["Alex Morgan"].waitForExistence(timeout: 2))
        app.buttons["Restore Alex Morgan"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["suggestButton"].waitForExistence(timeout: 2))
    }

    func testOpeningACallReturnsHomeAndUpdatesActivity() {
        app.buttons["suggestButton"].tap()
        app.buttons["callButton"].tap()

        XCTAssertTrue(app.buttons["suggestButton"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["callsOpenedValue"].label, "1")
        XCTAssertEqual(app.staticTexts["uniquePeopleValue"].label, "1")
    }

    func testSkippingShowsSomeoneElseWithoutExcludingAnyone() {
        app.buttons["suggestButton"].tap()
        XCTAssertEqual(app.staticTexts["suggestedContactName"].label, "Alex Morgan")

        app.buttons["skipButton"].tap()

        XCTAssertEqual(app.staticTexts["suggestedContactName"].label, "Beatrice Nilsson")
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.staticTexts["No one has been excluded."].waitForExistence(timeout: 2))
    }

    func testContactCanBeMarkedNotInterestedAndRestored() {
        app.tabBars.buttons["Contacts"].tap()
        XCTAssertTrue(app.staticTexts["Alex Morgan"].waitForExistence(timeout: 2))

        app.buttons["Not interested in Alex Morgan"].tap()

        XCTAssertTrue(app.staticTexts["Not interested"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Restore Alex Morgan"].exists)
        app.buttons["Restore Alex Morgan"].tap()
        XCTAssertTrue(app.buttons["Not interested in Alex Morgan"].waitForExistence(timeout: 2))
    }
}
