import Foundation
import PrebidMobile

/// Prebid Server used by the examples. Picked from the server menu on the examples screen.
enum PrebidServer: String, CaseIterable {

    case prebid
    case teads

    /// UserDefaults keys. Both can be set with launch arguments too, e.g. `-TeadsPBSHost <url>`.
    static let selectedKey = "PrebidServer"
    static let teadsHostKey = "TeadsPBSHost"

    var title: String {
        switch self {
        case .prebid: return "Prebid test server"
        case .teads: return "Teads test server"
        }
    }

    /// The Teads host is not in the repo: it is entered in the app or passed as a launch argument.
    var hostURL: String? {
        switch self {
        case .prebid:
            return "https://prebid-server-test-j.prebid.org/openrtb2/auction"
        case .teads:
            let host = UserDefaults.standard.string(forKey: Self.teadsHostKey)
            return host?.isEmpty == false ? host : nil
        }
    }

    var accountID: String {
        switch self {
        case .prebid: return "0689a263-318d-448b-a3d4-b02e8a709d9d"
        case .teads: return "outbrain-req"
        }
    }

    static var selected: PrebidServer {
        get {
            let server = UserDefaults.standard.string(forKey: selectedKey).flatMap(PrebidServer.init(rawValue:))
            return server?.hostURL != nil ? server! : .prebid
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: selectedKey)
        }
    }

    /// Keeps a host passed as a launch argument for the next launches too.
    static func saveLaunchArguments() {
        let arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        if let host = arguments[teadsHostKey] as? String {
            UserDefaults.standard.set(host, forKey: teadsHostKey)
        }
    }

    /// Host and account are read on every request, so this works after SDK init too.
    func apply() {
        guard let hostURL else { return }
        try? Host.shared.setHostURL(hostURL, nonTrackingURLString: nil)
        Prebid.shared.prebidServerAccountId = accountID
    }
}
