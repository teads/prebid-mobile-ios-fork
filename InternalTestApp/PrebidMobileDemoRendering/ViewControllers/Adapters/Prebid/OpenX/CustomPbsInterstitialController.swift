import UIKit
import PrebidMobile

/// In-App interstitial against the custom Prebid Server from `CustomPbsSettings`.
/// Publishes a "Bid info" JSON summary so UI tests can check the bid response.
class CustomPbsInterstitialController: PrebidInterstitialController {

    private static let bidResponseLogMarker = "Bid Response: "

    private let bidInfoLabel = UILabel()
    /// Prebid Server event URLs (win, imp) the app has called, as a JSON array.
    private let firedEventsLabel = UILabel()

    required init(rootController: AdapterViewController) {
        super.init(rootController: rootController)
        prebidConfigId = CustomPbsSettings.configID
        adFormats = [.banner]

        bidInfoLabel.accessibilityIdentifier = "teadsBidInfo"
        bidInfoLabel.numberOfLines = 0
        bidInfoLabel.font = .systemFont(ofSize: 9)
        rootController.actionsView.addArrangedSubview(bidInfoLabel)

        firedEventsLabel.accessibilityIdentifier = "teadsFiredEvents"
        firedEventsLabel.numberOfLines = 0
        firedEventsLabel.font = .systemFont(ofSize: 9)
        firedEventsLabel.text = "[]"
        rootController.actionsView.addArrangedSubview(firedEventsLabel)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateFiredEvents),
            name: RequestRecorder.didRecord,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        CustomPbsSettings.restore()
    }

    @objc private func updateFiredEvents() {
        let events = RequestRecorder.recordedURLs.filter { $0.contains("/event?") }
        let text = (try? JSONSerialization.data(withJSONObject: events)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        DispatchQueue.main.async { [weak self] in
            self?.firedEventsLabel.text = text
        }
    }

    override func loadAd() {
        CustomPbsSettings.apply()
        super.loadAd()
    }

    override func interstitialDidReceiveAd(_ interstitial: InterstitialRenderingAdUnit) {
        super.interstitialDidReceiveAd(interstitial)
        bidInfoLabel.text = jsonString(buildBidInfo())
    }

    override func interstitial(_ interstitial: InterstitialRenderingAdUnit, didFailToReceiveAdWithError error: Error?) {
        super.interstitial(interstitial, didFailToReceiveAdWithError: error)
        var info = baseInfo()
        info["error"] = error?.localizedDescription ?? "unknown"
        bidInfoLabel.text = jsonString(info)
    }

    private func baseInfo() -> [String: Any] {
        [
            "host": (try? Host.shared.getHostURL()) ?? "",
            "accountId": Prebid.shared.prebidServerAccountId,
            "configId": prebidConfigId,
        ]
    }

    private func buildBidInfo() -> [String: Any] {
        var info = baseInfo()
        guard let response = lastLoggedBidResponse() else {
            info["error"] = "no bid response in the SDK log"
            return info
        }

        let seatbid = (response["seatbid"] as? [[String: Any]])?.first
        let bid = (seatbid?["bid"] as? [[String: Any]])?.first ?? [:]
        let prebid = (bid["ext"] as? [String: Any])?["prebid"] as? [String: Any] ?? [:]
        let events = prebid["events"] as? [String: Any] ?? [:]

        info["seat"] = seatbid?["seat"] ?? ""
        info["price"] = bid["price"] ?? 0
        info["admLength"] = (bid["adm"] as? String)?.count ?? 0
        info["w"] = bid["w"] ?? 0
        info["h"] = bid["h"] ?? 0
        info["type"] = prebid["type"] ?? ""
        info["targeting"] = prebid["targeting"] ?? [:]
        info["hasWinEvent"] = !((events["win"] as? String) ?? "").isEmpty
        info["hasImpEvent"] = !((events["imp"] as? String) ?? "").isEmpty
        info["winEventUrl"] = events["win"] ?? ""
        info["impEventUrl"] = events["imp"] ?? ""

        // Present because CustomPbsSettings enables PBS debug.
        let debug = (response["ext"] as? [String: Any])?["debug"] as? [String: Any]
        let request = debug?["resolvedrequest"] as? [String: Any] ?? [:]
        let imp = (request["imp"] as? [[String: Any]])?.first ?? [:]
        let impPrebid = (imp["ext"] as? [String: Any])?["prebid"] as? [String: Any]
        info["request"] = [
            "publisherId": ((request["app"] as? [String: Any])?["publisher"] as? [String: Any])?["id"] ?? "",
            "storedImpId": (impPrebid?["storedrequest"] as? [String: Any])?["id"] ?? "",
            "instl": imp["instl"] ?? 0,
            "bannerFormats": (imp["banner"] as? [String: Any])?["format"] ?? [],
        ]
        return info
    }

    /// The SDK logs the raw auction response at info level, and this app writes logs to a file.
    private func lastLoggedBidResponse() -> [String: Any]? {
        guard let log = Log.getLogFileAsString(),
              let markerRange = log.range(of: Self.bidResponseLogMarker, options: .backwards) else {
            return nil
        }
        let line = log[markerRange.upperBound...].prefix { $0 != "\n" }
        guard let start = line.firstIndex(of: "{"), let end = line.lastIndex(of: "}") else {
            return nil
        }
        let data = Data(line[start...end].utf8)
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private func jsonString(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
