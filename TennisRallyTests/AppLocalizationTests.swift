import XCTest
@testable import TennisRally

final class AppLocalizationTests: XCTestCase {
    func testResolvesKeysForEnglishAndChineseLocales() {
        let en = Locale(identifier: "en")
        let zh = Locale(identifier: "zh-Hans")

        XCTAssertEqual(AppLocalization.localizationFolderName(for: zh), "zh-Hans")
        XCTAssertEqual(AppLocalization.text("process.title", locale: en), "Processing")
        XCTAssertEqual(AppLocalization.text("process.title", locale: zh), "处理中")
        XCTAssertEqual(AppLocalization.text("rallies.title", locale: en), "Rallies")
        XCTAssertEqual(AppLocalization.text("rallies.title", locale: zh), "回合")
        XCTAssertEqual(AppLocalization.text("correction.done", locale: en), "Done")
        XCTAssertEqual(AppLocalization.text("correction.done", locale: zh), "完成")
        XCTAssertEqual(AppLocalization.text("review.share_photos", locale: en), "Share to Photos")
        XCTAssertEqual(AppLocalization.text("review.share_photos", locale: zh), "保存到相册")
    }

    func testFormatsInterpolatedCopyForOverrideLocale() {
        let zh = Locale(identifier: "zh-Hans")
        XCTAssertEqual(
            AppLocalization.format("common.rally", locale: zh, 3 as CVarArg),
            "回合 03"
        )
        XCTAssertEqual(
            AppLocalization.format("process.clip_progress", locale: zh, 7 as CVarArg, 18 as CVarArg),
            "片段 7 / 约 18"
        )
    }
}
