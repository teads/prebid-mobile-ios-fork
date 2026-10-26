import XCTest

/// Interstitial against the Teads/Outbrain test Prebid Server.
/// IDs refer to the acceptance criteria. SHOULD checks use XCTSkip, so a miss shows as "skipped".
///
/// Environment: PBS_HOST (required), PBS_ACCOUNT_ID, PBS_CONFIG_ID, EXPECTED_SEAT.
/// From xcodebuild, prefix them with TEST_RUNNER_ (e.g. TEST_RUNNER_PBS_HOST=...).
class CustomPbsInterstitialUITest: XCTestCase {

    private let exampleTitle = "Display Interstitial Custom PBS (In-App)"
    private let loadTimeout: TimeInterval = 10
    private let closeButtonTimeout: TimeInterval = 5
    private let centerTolerance: CGFloat = 4

    private let environment = ProcessInfo.processInfo.environment
    private var hostURL: String { environment["PBS_HOST"] ?? "" }
    private var accountID: String { environment["PBS_ACCOUNT_ID"] ?? "outbrain-req" }
    private var configID: String { environment["PBS_CONFIG_ID"] ?? "outbrain-imp-display" }
    private var expectedSeat: String { environment["EXPECTED_SEAT"] ?? "outbrain" }

    private var app: XCUIApplication!

    private var adReceivedButton: XCUIElement { app.buttons["interstitialDidReceiveAd called"] }
    private var adFailedButton: XCUIElement { app.buttons["interstitialDidFailToReceiveAd called"] }

    override func setUpWithError() throws {
        continueAfterFailure = false
        // D2
        try XCTSkipIf(hostURL.isEmpty, "PBS_HOST not set")
        try XCTSkipUnless(isServerReachable(hostURL), "PBS unreachable - VPN?")
    }

    override func tearDown() {
        // Keep the bid info for failed runs too.
        if let label = app?.staticTexts["teadsBidInfo"], label.exists {
            let attachment = XCTAttachment(string: label.label)
            attachment.name = "bid_info_teardown.json"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app?.terminate()
        app = nil
        super.tearDown()
    }

    func testBidResponse() throws {
        launch()
        waitForEnabled(element: adReceivedButton, failElement: adFailedButton, waitSeconds: loadTimeout)
        let bidInfo = try readBidInfo()

        // B1
        XCTAssertEqual(bidInfo["host"] as? String, hostURL)
        XCTAssertEqual(bidInfo["accountId"] as? String, accountID)
        let request = try XCTUnwrap(bidInfo["request"] as? [String: Any])
        XCTAssertEqual(request["publisherId"] as? String, accountID)
        XCTAssertEqual(request["storedImpId"] as? String, configID)

        // B2
        XCTAssertEqual(request["instl"] as? Int, 1, "imp.instl")
        XCTAssertFalse((request["bannerFormats"] as? [Any] ?? []).isEmpty, "imp.banner.format is empty")

        // B3
        XCTAssertGreaterThan(bidInfo["price"] as? Double ?? 0, 0, "price")
        XCTAssertGreaterThan(bidInfo["admLength"] as? Int ?? 0, 0, "adm is empty")
        let targeting = try XCTUnwrap(bidInfo["targeting"] as? [String: String])
        XCTAssertNotNil(targeting["hb_pb"], "hb_pb missing")
        XCTAssertNotNil(targeting["hb_bidder"], "hb_bidder missing")

        // A8 on device (SHOULD)
        try XCTSkipUnless(bidInfo["hasWinEvent"] as? Bool == true && bidInfo["hasImpEvent"] as? Bool == true,
                          "A8 win/imp event URLs missing")

        // B4 (SHOULD)
        try XCTSkipUnless(bidInfo["seat"] as? String == expectedSeat, "B4 seat is \(bidInfo["seat"] ?? "")")
        try XCTSkipUnless(targeting["hb_bidder"] == expectedSeat, "B4 hb_bidder is \(targeting["hb_bidder"] ?? "")")
    }

    func testRenderAndClose() {
        launch()
        // C1
        waitForEnabled(element: adReceivedButton, failElement: adFailedButton, waitSeconds: loadTimeout)
        showInterstitial()

        // C2
        creativeShouldNotBeBlank()
        attachScreenshot(name: "interstitial_shown")

        // C4
        let closeButton = app.buttons["PBMCloseButton"]
        waitForHittable(element: closeButton, waitSeconds: closeButtonTimeout)
        closeButton.tap()
        waitForEnabled(element: app.buttons["interstitialDidDismissAd called"])
        waitForNotExist(element: closeButton)

        // C3
        XCTAssertTrue(app.buttons["interstitialWillPresentAd called"].isEnabled)
        XCTAssertFalse(adFailedButton.isEnabled)
    }

    /// C5 (SHOULD)
    func testCreativeLayout() throws {
        launch()
        waitForEnabled(element: adReceivedButton, failElement: adFailedButton, waitSeconds: loadTimeout)
        showInterstitial()
        creativeShouldNotBeBlank()
        attachScreenshot(name: "interstitial_layout")

        // iOS sizes the web view to the creative, so its frame is the creative's frame.
        let creative = settledFrame(of: app.webViews["PBMInternalWebViewAccessibilityIdentifier"])
        let window = app.windows.firstMatch.frame
        let offset = abs(creative.midX - window.midX)
        try XCTSkipUnless(offset <= centerTolerance, "C5 creative is \(offset)pt off centre (creative \(creative), window \(window))")
    }

    /// C6 (SHOULD). The in-app browser runs out of process on iOS 26, so its UI is not queryable:
    /// rely on the SDK click event instead.
    func testClickFiresClickEvent() throws {
        launch()
        waitForEnabled(element: adReceivedButton, failElement: adFailedButton, waitSeconds: loadTimeout)
        showInterstitial()
        creativeShouldNotBeBlank()
        
        app.webViews.firstMatch.tap()

        // The click opens Safari. Bring the app back before reading its event buttons.
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        if safari.wait(for: .runningForeground, timeout: 5) {
            safari.terminate()
            app.activate()
        }

        let clicked = app.buttons["interstitialDidClickAd called"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: clicked)
        let fired = XCTWaiter.wait(for: [enabled], timeout: 5) == .completed
        let events = app.buttons.matching(NSPredicate(format: "label ENDSWITH ' called'")).allElementsBoundByIndex
            .filter(\.isEnabled).map(\.label)
        try XCTSkipUnless(fired, "C6 interstitialDidClickAd not fired. Fired: \(events)")
    }
    
    /// D1
    func testUnknownConfigIdFails() throws {
        launch(configID: "teads-unknown-config-id")
        waitForEnabled(element: adFailedButton, failElement: adReceivedButton, waitSeconds: loadTimeout)
        XCTAssertFalse(adReceivedButton.isEnabled)

        let bidInfo = try readBidInfo()
        XCTAssertNil(bidInfo["price"], "price must not be set")
        // Fail for the right reason: the server rejects the unknown stored imp.
        let error = bidInfo["error"] as? String ?? ""
        XCTAssertTrue(error.contains("does not recognize Config Id"), "unexpected error: \(error)")
    }

    // MARK: - Helpers

    /// Opens the Custom PBS screen directly, without going through the example list.
    private func launch(configID: String? = nil) {
        app = XCUIApplication()
        app.launchArguments = [
            "-keyUITests",
            "OPEN_TEST_CASE", exampleTitle,
            "PBS_HOST", hostURL,
            "PBS_ACCOUNT_ID", accountID,
            "PBS_CONFIG_ID", configID ?? self.configID,
        ]
        addUIInterruptionMonitor(withDescription: "System Dialog") { alert in
            alert.buttons["Don’t Allow"].tap()
            return true
        }
        app.launch()
    }

    private func showInterstitial() {
        let showButton = app.buttons["Show"]
        waitForEnabled(element: showButton)
        showButton.tap()
    }

    /// First DOM element with a label. WebKit may expose the creative as one Link, without StaticTexts.
    private var creativeElement: XCUIElement {
        let labelled = NSPredicate(format: "label != '' AND NOT (label CONTAINS 'scroll bar')")
        return app.webViews.firstMatch.descendants(matching: .any).matching(labelled).firstMatch
    }

    /// C2: a web view is shown and its accessibility tree (DOM) is not empty.
    private func creativeShouldNotBeBlank() {
        waitForExists(element: app.webViews.firstMatch, waitSeconds: 5)
        waitForExists(element: creativeElement, waitSeconds: 5)
    }

    /// Frame once the present animation is over (two equal reads in a row).
    private func settledFrame(of element: XCUIElement, timeout: TimeInterval = 3) -> CGRect {
        var frame = element.frame
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            usleep(300_000)
            let next = element.frame
            if next == frame { break }
            frame = next
        }
        return frame
    }
    
    private func readBidInfo() throws -> [String: Any] {
        let label = app.staticTexts["teadsBidInfo"]
        waitFor(element: label, predicate: NSPredicate(format: "label BEGINSWITH '{'"),
                message: "Bid info not filled", waitSeconds: 5, file: #file, line: #line)
        let attachment = XCTAttachment(string: label.label)
        attachment.name = "bid_info.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        let data = try XCTUnwrap(label.label.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func attachScreenshot(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func isServerReachable(_ auctionURL: String) -> Bool {
        guard let url = URL(string: auctionURL.replacingOccurrences(of: "/openrtb2/auction", with: "/status")) else {
            return false
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        let done = DispatchSemaphore(value: 0)
        var reachable = false
        URLSession.shared.dataTask(with: request) { _, response, _ in
            reachable = (response as? HTTPURLResponse)?.statusCode == 200
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 5)
        return reachable
    }
}
