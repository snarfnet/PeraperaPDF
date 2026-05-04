import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@main
struct PeraperaPDFApp: App {
    init() {
        MobileAds.shared.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        ATTrackingManager.requestTrackingAuthorization { _ in }
                    }
                }
        }
    }
}
