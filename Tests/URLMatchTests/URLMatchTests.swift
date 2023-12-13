import XCTest
import URLMatch

// https://github.com/cweb/url-testing

class URLMatchingTests: XCTestCase {
    func testMatch() throws {
        XCTAssertEqual(
            try URL(string: "s://h/v1/v2?q1&q2=3&q3=x&q4")!
                .match(pattern: URL(string: "s://h/:p1/v2?q1&:q2=&q3=x&q4")!),
            [
                ":p1": "v1",
                ":q2": "3",
            ]
        )

        XCTAssertEqual(
            try URL(string: "?required=1&optional=2&reqvalue=3")!
                .match(pattern: URL(string: "?required=1&:optional&:notfound&:reqvalue=")!),
            [
                ":optional": "2",
                ":reqvalue": "3",
            ]
        )
    }

    func testMatchErrors() {
        XCTAssertThrowsError(
            try URL(string: "path")!.match(pattern: URL(string: "scheme://")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .componentDoesNotMatch(\.scheme)) }

        XCTAssertThrowsError(
            try URL(string: "path1")!.match(pattern: URL(string: "path1/path2")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .pathDoesNotMatch) }

        XCTAssertNoThrow(
            try URL(string: "path1/path2")!.match(pattern: URL(string: "path1/path2")!)
        )

        XCTAssertThrowsError(
            try URL(string: "path1/path2/path3")!.match(pattern: URL(string: "path1/path2")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .pathDoesNotMatch) }

        XCTAssertNoThrow(
            try URL(string: " ")!.match(pattern: URL(string: " ")!)
        )

        XCTAssertNoThrow(
            try URL(string: "/")!.match(pattern: URL(string: "/")!)
        )

        XCTAssertThrowsError(
            try URL(string: "?")!.match(pattern: URL(string: "?a=b")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .missingQueryItems([.init(name: "a", value: "b")])) }

        XCTAssertEqual(
            try URL(string: "?a=b")!.match(pattern: URL(string: "?a=b")!),
            [:]
        )

        XCTAssertEqual(
            try URL(string: "?")!.match(pattern: URL(string: "?:a")!),
            [:]
        )

        XCTAssertThrowsError(
            try URL(string: "?")!.match(pattern: URL(string: "?:a=")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .missingQueryItems([.init(name: ":a", value: "")])) }

        XCTAssertThrowsError(
            try URL(string: "?a")!.match(pattern: URL(string: "?:a=")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .missingQueryItems([.init(name: ":a", value: "")])) }

        XCTAssertThrowsError(
            try URL(string: "?")!.match(pattern: URL(string: "?:a=a")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .missingQueryItems([.init(name: ":a", value: "a")])) }

        XCTAssertEqual(
            try URL(string: "?a=b")!.match(pattern: URL(string: "?:a=a")!),
            [":a": "b"]
        )
    }

    func testFill() throws {
        XCTAssertEqual(
            try URL(string: "s://h/:p1/v2?q1&:q2=&q3=x&q4")!
                .fillPattern(
                    [
                        ":p1": "v1",
                        ":q2": "3",
                    ]
                ),
            URL(string: "s://h/v1/v2?q1&q2=3&q3=x&q4")!
        )

        XCTAssertEqual(
            try URL(string: "?required=1&:optional&:notfound&:reqvalue=")!
                .fillPattern(
                    [
                        ":optional": "2",
                        ":reqvalue": "3",
                    ]
                ),
            URL(string: "?required=1&optional=2&reqvalue=3")!
        )
    }

    func testFillErrors() {
        XCTAssertThrowsError(
            try URL(string: "path/:a")!.fillPattern([:])
        ) { XCTAssertEqual($0 as? URL.PatternFillError, .missingParameter(":a")) }

        XCTAssertEqual(
            try URL(string: "path/:a")!.fillPattern([":a": "a"]),
            URL(string: "path/a")!
        )

        XCTAssertThrowsError(
            try URL(string: "?:a=")!.fillPattern([:])
        ) { XCTAssertEqual($0 as? URL.PatternFillError, .missingParameter(":a")) }

        XCTAssertEqual(
            try URL(string: "?:a=b")!.fillPattern([":a": "a"]),
            URL(string: "?a=a")!
        )

        XCTAssertEqual(
            try URL(string: "?:a")!.fillPattern([:]),
            URL(string: "?")!
        )

        XCTAssertEqual(
            try URL(string: "?:a")!.fillPattern([":a": "a"]),
            URL(string: "?a=a")!
        )
    }
}
