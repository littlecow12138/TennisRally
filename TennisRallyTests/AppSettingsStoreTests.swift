import XCTest
import SwiftUI
@testable import TennisRally

@MainActor
final class AppSettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppSettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsToDarkThemeAndEnglish() {
        let store = AppSettingsStore(defaults: defaults)
        XCTAssertEqual(store.theme, .dark)
        XCTAssertEqual(store.language, .english)
        XCTAssertEqual(store.theme.preferredColorScheme, .dark)
        XCTAssertEqual(store.language.locale.identifier, "en")
    }

    func testThemePersistsAcrossRelaunch() {
        let store = AppSettingsStore(defaults: defaults)
        store.theme = .light
        let relaunched = AppSettingsStore(defaults: defaults)
        XCTAssertEqual(relaunched.theme, .light)
        XCTAssertEqual(relaunched.theme.preferredColorScheme, .light)
    }

    func testSystemThemeClearsPreferredColorScheme() {
        let store = AppSettingsStore(defaults: defaults)
        store.theme = .system
        XCTAssertNil(store.theme.preferredColorScheme)
        let relaunched = AppSettingsStore(defaults: defaults)
        XCTAssertEqual(relaunched.theme, .system)
        XCTAssertNil(relaunched.theme.preferredColorScheme)
    }

    func testLanguagePersistsAndExposesLocale() {
        let store = AppSettingsStore(defaults: defaults)
        store.language = .simplifiedChinese
        XCTAssertEqual(store.language.locale.identifier, "zh-Hans")
        let relaunched = AppSettingsStore(defaults: defaults)
        XCTAssertEqual(relaunched.language, .simplifiedChinese)
    }
}
