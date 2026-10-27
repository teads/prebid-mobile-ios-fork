import UIKit
import PrebidMobile

fileprivate let storedImpDisplayInterstitial = "outbrain-imp-display"

/// Display interstitial for the Teads test Prebid Server.
/// Uses the server picked in the server menu: on the Prebid server the config id is unknown, so it fails.
class TeadsDisplayInterstitialViewController: UIViewController, InterstitialAdUnitDelegate {

    // Prebid
    private var renderingInterstitial: InterstitialRenderingAdUnit!

    override func loadView() {
        super.loadView()

        createAd()
    }

    func createAd() {
        // 1. Create a InterstitialRenderingAdUnit
        renderingInterstitial = InterstitialRenderingAdUnit(configID: storedImpDisplayInterstitial)

        // 2. Configure the InterstitialRenderingAdUnit
        renderingInterstitial.adFormats = [.banner]
        renderingInterstitial.delegate = self

        // 3. Load the interstitial ad
        renderingInterstitial.loadAd()
    }

    // MARK: - InterstitialAdUnitDelegate

    func interstitialDidReceiveAd(_ interstitial: InterstitialRenderingAdUnit) {
        interstitial.show(from: self)
    }

    func interstitial(_ interstitial: InterstitialRenderingAdUnit, didFailToReceiveAdWithError error: Error?) {
        PrebidDemoLogger.shared.error("Interstitial Rendering ad unit did fail to receive ad with error: \(error)")
    }
}
