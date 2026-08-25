import XCTest
@testable import Tickytacky

final class GroceryModeTests: XCTestCase {
    func testListNameDetection() {
        XCTAssertTrue(GroceryMode.isGroceryListName("Groceries"))
        XCTAssertTrue(GroceryMode.isGroceryListName("Weekly grocery run"))
        XCTAssertFalse(GroceryMode.isGroceryListName("Work"))
        XCTAssertFalse(GroceryMode.isGroceryListName("Inbox"))
    }

    func testTitleSuggestion() {
        XCTAssertTrue(GroceryMode.titleSuggestsGrocery("Buy groceries"))
        XCTAssertTrue(GroceryMode.titleSuggestsGrocery("grocery milk"))
        XCTAssertFalse(GroceryMode.titleSuggestsGrocery("Call dentist"))
    }

    func testSplitItemLines() {
        XCTAssertEqual(
            GroceryMode.splitItemLines("Milk\nEggs\n\n Bread "),
            ["Milk", "Eggs", "Bread"]
        )
    }
}
