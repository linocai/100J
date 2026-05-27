import XCTest
@testable import PersonalAffairsApp

/// v1.2.4.2 P1-14: unit coverage for the pure-function half of
/// `InlineQuickAddRow`. Driving SwiftUI focus state from XCTest is brittle
/// across iOS / macOS targets, so the view exposes a `sanitize(_:)` helper
/// that owns the "should we submit?" decision. Those branches are what
/// users see in the real flow:
///
///   * trim whitespace before POST,
///   * ignore empty / whitespace-only / newline-only input,
///   * preserve interior content verbatim.
final class InlineQuickAddRowTests: XCTestCase {

    func test_sanitize_trims_surrounding_whitespace() {
        XCTAssertEqual(InlineQuickAddRow.sanitize("  开会  "), "开会")
        XCTAssertEqual(InlineQuickAddRow.sanitize("\tbuy milk\n"), "buy milk")
    }

    func test_sanitize_returns_nil_for_blank_input() {
        XCTAssertNil(InlineQuickAddRow.sanitize(""))
        XCTAssertNil(InlineQuickAddRow.sanitize("   "))
        XCTAssertNil(InlineQuickAddRow.sanitize("\n\t  \n"))
    }

    func test_sanitize_preserves_interior_whitespace_and_unicode() {
        // Inside-the-string spaces and unicode (emoji, Chinese, punctuation)
        // must round-trip unchanged so users can record multi-word entries.
        XCTAssertEqual(
            InlineQuickAddRow.sanitize("跟进 Q3 财报 📊"),
            "跟进 Q3 财报 📊"
        )
    }

    func test_sanitize_drops_only_outer_whitespace_not_inner() {
        // Regression guard: a previous draft of the helper used
        // `.replacingOccurrences(of: " ", with: "")` which would have
        // collapsed multi-word titles. This asserts the contract.
        let result = InlineQuickAddRow.sanitize("  a   b   c  ")
        XCTAssertEqual(result, "a   b   c")
    }
}
