import XCTest
import URLMatch

// https://github.com/cweb/url-testing

class URLMatchingTests: XCTestCase {
    func test() {
        XCTAssertEqual(
            URL(string: "s://h/v1/v2?q1&q2=3&q3=x&q4")!
                .match(pattern: URL(string: "s://h/:p1/v2?q1&:q2=&q3=x&q4")!),
            [
                ":p1": "v1",
                ":q2": "3",
            ]
        )

        XCTAssertEqual(
            URL(string: "?required=1&optional=2&reqvalue=3")!
                .match(pattern: URL(string: "?required=1&:optional&:notfound&:reqvalue=")!),
            [
                ":optional": "2",
                ":reqvalue": "3",
            ]
        )
    }
}
