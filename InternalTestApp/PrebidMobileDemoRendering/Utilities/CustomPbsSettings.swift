import Foundation
import PrebidMobile

/// Teads/Outbrain test Prebid Server. Set with the PBS_HOST (required),
/// PBS_ACCOUNT_ID and PBS_CONFIG_ID launch arguments.
enum CustomPbsSettings {

    static let defaultHostURL = ""
    static let defaultAccountID = "outbrain-req"
    static let defaultConfigID = "outbrain-imp-display"

    static var hostURL = defaultHostURL
    static var accountID = defaultAccountID
    static var configID = defaultConfigID

    /// Title of a test case to open on launch (OPEN_TEST_CASE launch argument).
    static var testCaseToOpen: String?

    private static var previousHostURL: String?
    private static var previousPbsDebug = false

    static func apply() {
        previousHostURL = try? Host.shared.getHostURL()
        previousPbsDebug = Prebid.shared.pbsDebug

        try? Host.shared.setHostURL(hostURL, nonTrackingURLString: nil)
        Prebid.shared.prebidServerAccountId = accountID
        // Makes the server echo the resolved request in ext.debug, so tests can check what was sent.
        Prebid.shared.pbsDebug = true
        // The bid info is read back from the SDK log file (see CustomPbsInterstitialController).
        Log.clearLogFile()
    }

    /// Account id is reset by TestCasesViewController on the next test case.
    static func restore() {
        if let previousHostURL {
            try? Host.shared.setHostURL(previousHostURL, nonTrackingURLString: nil)
        }
        previousHostURL = nil
        Prebid.shared.pbsDebug = previousPbsDebug
    }
}
