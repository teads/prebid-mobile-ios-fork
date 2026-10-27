import XCTest

/// Runs on the Teads server. Needs the PBS_HOST environment variable (TEST_RUNNER_PBS_HOST from xcodebuild) and VPN.
/// Skipped otherwise.
class TeadsInterstitialAdsTest: BaseAdsTest {

    private var hostURL: String { ProcessInfo.processInfo.environment["PBS_HOST"] ?? "" }

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipIf(hostURL.isEmpty, "PBS_HOST not set")
        app.launchArguments += ["-TeadsPBSHost", hostURL]
    }

    override func tearDown() {
        // Leave the app on the default server for the other tests.
        if app.state == .runningForeground {
            app.terminate()
            app.launch()
            selectServer("Prebid test server")
        }
        super.tearDown()
    }

    public func testTeadsInterstitialAd() {
        app.launch()
        selectServer("Teads test server")
        XCTAssert(app.navigationBars.staticTexts["Teads test server"].waitForExistence(timeout: 5), "Server not shown under the title")

        app.searchFields.element.tap()
        app.searchFields.element.typeText(testCases.teadsDisplayInterstitialCase)
        app.tables.element(boundBy: 0).cells.element(boundBy: 0).tap()

        XCTAssert(app.webViews.element.waitForExistence(timeout: 10), "Interstitial Web View is not displayed")
        let closeButton = app.buttons["PBMCloseButton"]
        XCTAssert(closeButton.waitForExistence(timeout: 10), "Close button is not displayed")
        closeButton.tap()

        // The use case must not change the server picked in the menu.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssert(app.navigationBars.staticTexts["Teads test server"].waitForExistence(timeout: 5), "Server changed")
    }

    private func selectServer(_ title: String) {
        let menu = app.navigationBars.buttons["prebidServerMenu"]
        XCTAssert(menu.waitForExistence(timeout: 5), "Server menu not found")
        menu.tap()
        app.buttons[title].tap()
    }
}
