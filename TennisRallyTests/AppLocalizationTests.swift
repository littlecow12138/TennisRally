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

    func testTC06_modelDownloadFailureCopyMatchesEnglishAndChinese() {
        let en = Locale(identifier: "en")
        let zh = Locale(identifier: "zh-Hans")

        XCTAssertEqual(AppLocalization.text("ai.model.connecting", locale: en), "Connecting…")
        XCTAssertEqual(AppLocalization.text("ai.model.connecting", locale: zh), "正在连接…")
        XCTAssertEqual(AppLocalization.text("ai.model.stalled.title", locale: en), "Download stalled")
        XCTAssertEqual(AppLocalization.text("ai.model.stalled.title", locale: zh), "下载停滞")
        XCTAssertEqual(AppLocalization.text("ai.model.failed.title", locale: en), "Download failed")
        XCTAssertEqual(AppLocalization.text("ai.model.failed.title", locale: zh), "下载失败")
        XCTAssertEqual(AppLocalization.text("ai.model.retry", locale: en), "Retry")
        XCTAssertEqual(AppLocalization.text("ai.model.retry", locale: zh), "重试")
        XCTAssertEqual(AppLocalization.text("ai.model.retry_download", locale: en), "Retry download")
        XCTAssertEqual(AppLocalization.text("ai.model.retry_download", locale: zh), "重新下载")
        XCTAssertEqual(AppLocalization.text("ai.model.status.stalled_fmt", locale: en), "Stalled · 0%")
        XCTAssertEqual(AppLocalization.text("ai.model.status.stalled_fmt", locale: zh), "已停滞 · 0%")
        XCTAssertEqual(AppLocalization.text("ai.model.status.failed_fmt", locale: en), "Failed · tap to retry")
        XCTAssertEqual(AppLocalization.text("ai.model.status.failed_fmt", locale: zh), "失败 · 点按重试")
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
        XCTAssertEqual(
            AppLocalization.text("ai.assist.entry", locale: zh),
            "AI 辅助"
        )
        XCTAssertEqual(
            AppLocalization.text("ai.verdict.needs_review", locale: Locale(identifier: "en")),
            "Needs review"
        )
    }
}
