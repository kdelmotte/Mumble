import XCTest
@testable import Mumble

final class AppContextDetectorTests: XCTestCase {

    // MARK: - toneForApp() Mapping Tests

    func testMessages_returnsVeryCasual() {
        let context = AppContext(bundleIdentifier: "com.apple.MobileSMS", appName: "Messages", url: nil)
        XCTAssertEqual(toneForApp(context), .veryCasual, "Messages should map to .veryCasual")
    }

    func testDiscord_returnsVeryCasual() {
        let context = AppContext(bundleIdentifier: "com.hnc.Discord", appName: "Discord", url: nil)
        XCTAssertEqual(toneForApp(context), .veryCasual, "Discord should map to .veryCasual")
    }

    func testMail_returnsCasual() {
        let context = AppContext(bundleIdentifier: "com.apple.mail", appName: "Mail", url: nil)
        XCTAssertEqual(toneForApp(context), .casual, "Mail should map to .casual")
    }

    func testSlack_returnsCasual() {
        let context = AppContext(bundleIdentifier: "com.tinyspeck.slackmacgap", appName: "Slack", url: nil)
        XCTAssertEqual(toneForApp(context), .casual, "Slack should map to .casual")
    }

    func testSafari_returnsCasual() {
        let context = AppContext(bundleIdentifier: "com.apple.Safari", appName: "Safari", url: nil)
        XCTAssertEqual(toneForApp(context), .casual, "Safari should map to .casual")
    }

    func testChrome_returnsCasual() {
        let context = AppContext(bundleIdentifier: "com.google.Chrome", appName: "Google Chrome", url: nil)
        XCTAssertEqual(toneForApp(context), .casual, "Chrome should map to .casual")
    }

    func testArc_returnsCasual() {
        let context = AppContext(bundleIdentifier: "company.thebrowser.Browser", appName: "Arc", url: nil)
        XCTAssertEqual(toneForApp(context), .casual, "Arc should map to .casual")
    }

    func testEdge_returnsCasual() {
        let context = AppContext(bundleIdentifier: "com.microsoft.edgemac", appName: "Microsoft Edge", url: nil)
        XCTAssertEqual(toneForApp(context), .casual, "Edge should map to .casual")
    }

    // MARK: - Unknown / Default Cases

    func testUnknownApp_returnsCasualDefault() {
        let context = AppContext(bundleIdentifier: "com.example.unknown", appName: "Unknown App", url: nil)
        XCTAssertEqual(toneForApp(context), .casual, "Unknown app should default to .casual")
    }

    func testNilBundleID_returnsCasualDefault() {
        let context = AppContext(bundleIdentifier: nil, appName: nil, url: nil)
        XCTAssertEqual(toneForApp(context), .casual, "Nil bundle ID should default to .casual")
    }

    // MARK: - Browser URL-Based Mapping

    func testBrowserWithGmailURL_returnsCasual() {
        let context = AppContext(bundleIdentifier: "com.google.Chrome", appName: "Google Chrome", url: "https://mail.gmail.com/mail/u/0/")
        XCTAssertEqual(toneForApp(context), .casual, "Browser with gmail.com URL should map to .casual")
    }

    func testBrowserWithNonGmailURL_returnsCasual() {
        let context = AppContext(bundleIdentifier: "com.apple.Safari", appName: "Safari", url: "https://www.apple.com")
        XCTAssertEqual(toneForApp(context), .casual, "Browser with non-Gmail URL should map to .casual")
    }

    // MARK: - AppContext Construction

    func testAppContext_constructionWithAllFields() {
        let context = AppContext(bundleIdentifier: "com.apple.Safari", appName: "Safari", url: "https://example.com")
        XCTAssertEqual(context.bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(context.appName, "Safari")
        XCTAssertEqual(context.url, "https://example.com")
    }

    func testAppContext_constructionWithNilFields() {
        let context = AppContext(bundleIdentifier: nil, appName: nil, url: nil)
        XCTAssertNil(context.bundleIdentifier)
        XCTAssertNil(context.appName)
        XCTAssertNil(context.url)
    }

    func testAppContext_equatable() {
        let context1 = AppContext(bundleIdentifier: "com.apple.Safari", appName: "Safari", url: nil)
        let context2 = AppContext(bundleIdentifier: "com.apple.Safari", appName: "Safari", url: nil)
        let context3 = AppContext(bundleIdentifier: "com.google.Chrome", appName: "Chrome", url: nil)

        XCTAssertEqual(context1, context2, "Identical AppContext values should be equal")
        XCTAssertNotEqual(context1, context3, "Different AppContext values should not be equal")
    }
}
