import Foundation
import Testing
@testable import Airink

struct SettingsTests {
    @Test func versionStringShowsVersionAndBuild() {
        // Tests run inside the host app, so Bundle.main is Airink.app.
        #expect(Bundle.main.versionString.wholeMatch(of: /\d+\.\d+\.\d+ \(\d+\)/) != nil)
    }
}
