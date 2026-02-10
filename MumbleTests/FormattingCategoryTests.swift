import XCTest
@testable import Mumble

final class FormattingCategoryTests: XCTestCase {

    // MARK: - Tier 1: Native App Bundle ID Classification

    func testNativeMailApp_classifiesAsEmail() {
        let context = AppContext(bundleIdentifier: "com.apple.mail", appName: "Mail", windowTitle: nil)
        XCTAssertEqual(FormattingCategory.classify(context), .email)
    }

    func testMessages_classifiesAsMessaging() {
        let context = AppContext(bundleIdentifier: "com.apple.MobileSMS", appName: "Messages", windowTitle: nil)
        XCTAssertEqual(FormattingCategory.classify(context), .messaging)
    }

    func testDiscord_classifiesAsMessaging() {
        let context = AppContext(bundleIdentifier: "com.hnc.Discord", appName: "Discord", windowTitle: nil)
        XCTAssertEqual(FormattingCategory.classify(context), .messaging)
    }

    func testSlack_classifiesAsMessaging() {
        let context = AppContext(bundleIdentifier: "com.tinyspeck.slackmacgap", appName: "Slack", windowTitle: nil)
        XCTAssertEqual(FormattingCategory.classify(context), .messaging)
    }

    func testXcode_classifiesAsCode() {
        let context = AppContext(bundleIdentifier: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil)
        XCTAssertEqual(FormattingCategory.classify(context), .code)
    }

    func testVSCode_classifiesAsCode() {
        let context = AppContext(bundleIdentifier: "com.microsoft.VSCode", appName: "Visual Studio Code", windowTitle: nil)
        XCTAssertEqual(FormattingCategory.classify(context), .code)
    }

    // MARK: - Tier 2: Browser Window Title Classification

    func testChrome_gmailTitle_classifiesAsEmail() {
        let context = AppContext(bundleIdentifier: "com.google.Chrome", appName: "Google Chrome", windowTitle: "Inbox (3) - Gmail")
        XCTAssertEqual(FormattingCategory.classify(context), .email)
    }

    func testChrome_outlookTitle_classifiesAsEmail() {
        let context = AppContext(bundleIdentifier: "com.google.Chrome", appName: "Google Chrome", windowTitle: "Mail - John Doe - Outlook")
        XCTAssertEqual(FormattingCategory.classify(context), .email)
    }

    func testChrome_discordTitle_classifiesAsMessaging() {
        let context = AppContext(bundleIdentifier: "com.google.Chrome", appName: "Google Chrome", windowTitle: "Discord | #general")
        XCTAssertEqual(FormattingCategory.classify(context), .messaging)
    }

    func testChrome_slackTitle_classifiesAsMessaging() {
        let context = AppContext(bundleIdentifier: "com.google.Chrome", appName: "Google Chrome", windowTitle: "Slack | company-workspace")
        XCTAssertEqual(FormattingCategory.classify(context), .messaging)
    }

    func testChrome_githubTitle_classifiesAsCode() {
        let context = AppContext(bundleIdentifier: "com.google.Chrome", appName: "Google Chrome", windowTitle: "Fix bug #42 by user - Pull Request - GitHub")
        XCTAssertEqual(FormattingCategory.classify(context), .code)
    }

    // MARK: - Fallback to General

    func testChrome_noTitle_classifiesAsGeneral() {
        let context = AppContext(bundleIdentifier: "com.google.Chrome", appName: "Google Chrome", windowTitle: nil)
        XCTAssertEqual(FormattingCategory.classify(context), .general)
    }

    func testChrome_genericTitle_classifiesAsGeneral() {
        let context = AppContext(bundleIdentifier: "com.google.Chrome", appName: "Google Chrome", windowTitle: "Google Search")
        XCTAssertEqual(FormattingCategory.classify(context), .general)
    }

    func testUnknownApp_classifiesAsGeneral() {
        let context = AppContext(bundleIdentifier: "com.example.notes", appName: "Notes", windowTitle: nil)
        XCTAssertEqual(FormattingCategory.classify(context), .general)
    }

    func testNilEverything_classifiesAsGeneral() {
        let context = AppContext(bundleIdentifier: nil, appName: nil, windowTitle: nil)
        XCTAssertEqual(FormattingCategory.classify(context), .general)
    }

    // MARK: - CustomStringConvertible

    func testDescription_email() {
        XCTAssertEqual(FormattingCategory.email.description, "email")
    }

    func testDescription_messaging() {
        XCTAssertEqual(FormattingCategory.messaging.description, "messaging")
    }

    func testDescription_code() {
        XCTAssertEqual(FormattingCategory.code.description, "code")
    }

    func testDescription_general() {
        XCTAssertEqual(FormattingCategory.general.description, "general")
    }
}
