import XCTest

final class MapsFlowTests: XCTestCase {
    @MainActor
    func testSearchPinDetailsAndPhotos() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<3 {
            let allow = system.alerts.buttons["Allow While Using App"]
            if allow.waitForExistence(timeout: 2) { allow.tap() }
        }
        let search = app.textFields["placeSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        capture("Map and search", app: app)

        app.buttons["Coffee"].tap()
        let pins = app.otherElements.matching(NSPredicate(format: "identifier == 'VKPointFeature' AND label CONTAINS 'Coffee'"))
        XCTAssertTrue(pins.firstMatch.waitForExistence(timeout: 30), app.debugDescription)
        capture("Search results and rating pins", app: app)
        let pin = try XCTUnwrap(pins.allElementsBoundByIndex.first {
            $0.isHittable && $0.frame.minY > 80 && $0.frame.maxY < 400
        })
        let pinLabel = pin.label
        let repeatedTitle = String(pinLabel.prefix(max(0, (pinLabel.count - 2) / 2)))
        let title = pinLabel == "\(repeatedTitle), \(repeatedTitle)" ? repeatedTitle : pinLabel
        pin.tap()
        XCTAssertTrue(app.buttons["Close place details"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["Directions"].exists)
        let photos = app.staticTexts["Photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 30), app.debugDescription)
        app.buttons["Sheet Grabber"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)))
        let photoCredit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Photo:'")).firstMatch
        XCTAssertTrue(photoCredit.waitForExistence(timeout: 30))
        XCTAssertTrue(app.images["loadedPlacePhoto"].firstMatch.waitForExistence(timeout: 30))
        capture("Place details and photo carousel", app: app)

        app.buttons["Close place details"].tap()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        app.buttons["Clear search"].tap()
        XCTAssertEqual(search.value as? String, "Search places")
        XCTAssertTrue(app.staticTexts["Explore your surroundings"].exists)
        capture("Cleared search", app: app)
        XCTAssertTrue(app.otherElements.matching(NSPredicate(format: "identifier == 'VKPointFeature' AND label == %@", pinLabel)).firstMatch.waitForNonExistence(timeout: 5))
        app.buttons["Search Connection"].tap()
        XCTAssertTrue(app.navigationBars["Search Connection"].waitForExistence(timeout: 5))
        app.buttons["Test connection"].tap()
        XCTAssertTrue(app.staticTexts["Connected to your search bridge."].waitForExistence(timeout: 10))
        app.buttons["Cancel"].tap()
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
