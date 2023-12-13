import XCTest
import URLPattern

// https://github.com/cweb/url-testing

class URLPatternTests: XCTestCase {
    func testMatch() throws {
        XCTAssertEqual(
            try URL(string: "s://h/:p1/v2?q1&:q2=&q3=x&q4")!
                .match(URL(string: "s://h/v1/v2?q1&q2=3&q3=x&q4")!),
            [
                ":p1": "v1",
                ":q2": "3",
            ]
        )

        XCTAssertEqual(
            try URL(string: "?required=1&:optional&:notfound&:reqvalue=")!
                .match(URL(string: "?required=1&optional=2&reqvalue=3")!),
            [
                ":optional": "2",
                ":reqvalue": "3",
            ]
        )
    }

    func testMatchPath() {
        XCTAssertThrowsError(
            try URL(string: "scheme://")!.match(URL(string: "path")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .componentDoesNotMatch(\.scheme)) }

        XCTAssertThrowsError(
            try URL(string: "path1/path2")!.match(URL(string: "path1")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .pathDoesNotMatch) }

        XCTAssertNoThrow(
            try URL(string: "path1/path2")!.match(URL(string: "path1/path2")!)
        )

        XCTAssertThrowsError(
            try URL(string: "path1/path2")!.match(URL(string: "path1/path2/path3")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .pathDoesNotMatch) }

        XCTAssertNoThrow(
            try URL(string: " ")!.match(URL(string: " ")!)
        )

        XCTAssertNoThrow(
            try URL(string: "/")!.match(URL(string: "/")!)
        )

        XCTAssertThrowsError(
            try URL(string: "path/:p1/:p1")!.match(URL(string: "a/b/c")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .duplicateParameterInPattern) }
    }

    func testMatchQuery() {
        XCTAssertThrowsError(
            try URL(string: "?a=b")!.match(URL(string: "?")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .missingQueryItems([.init(name: "a", value: "b")])) }

        XCTAssertEqual(
            try URL(string: "?a=b")!.match(URL(string: "?a=b")!),
            [:]
        )

        XCTAssertEqual(
            try URL(string: "?:a")!.match(URL(string: "?")!),
            [:]
        )

        XCTAssertThrowsError(
            try URL(string: "?:a=")!.match(URL(string: "?")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .missingQueryItems([.init(name: ":a", value: "")])) }

        XCTAssertThrowsError(
            try URL(string: "?:a=")!.match(URL(string: "?a")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .missingQueryItems([.init(name: ":a", value: "")])) }

        XCTAssertThrowsError(
            try URL(string: "?:a=a")!.match(URL(string: "?")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .missingQueryItems([.init(name: ":a", value: "a")])) }

        XCTAssertEqual(
            try URL(string: "?:a=a")!.match(URL(string: "?a=b")!),
            [":a": "b"]
        )

        XCTAssertEqual(
            try URL(string: "?:a=")!.match(URL(string: "?a=1&a=2")!),
            [":a": "2"]
        )

        XCTAssertThrowsError(
            try URL(string: "?:a=&:a=")!.match(URL(string: "?a=")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .duplicateParameterInPattern) }

        XCTAssertThrowsError(
            try URL(string: "?:a&:a")!.match(URL(string: "?a=")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .duplicateParameterInPattern) }

        XCTAssertThrowsError(
            try URL(string: "path/:p?:p=")!.match(URL(string: "path/p1?p=p2")!)
        ) { XCTAssertEqual($0 as? URL.MatchError, .duplicateParameterInPattern) }
    }

    func testFill() throws {
        XCTAssertEqual(
            try URL(string: "s://h/:p1/v2?q1&:q2=&q3=x&q4")!
                .inflate(
                    [
                        ":p1": "v1",
                        ":q2": "3",
                    ]
                ),
            URL(string: "s://h/v1/v2?q1&q2=3&q3=x&q4")!
        )

        XCTAssertEqual(
            try URL(string: "?required=1&:optional&:notfound&:reqvalue=")!
                .inflate(
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
            try URL(string: "path/:a")!.inflate([:])
        ) { XCTAssertEqual($0 as? URL.InflateError, .missingParameter(":a")) }

        XCTAssertEqual(
            try URL(string: "path/:a")!.inflate([":a": "a"]),
            URL(string: "path/a")!
        )

        XCTAssertThrowsError(
            try URL(string: "?:a=")!.inflate([:])
        ) { XCTAssertEqual($0 as? URL.InflateError, .missingParameter(":a")) }

        XCTAssertEqual(
            try URL(string: "?:a=b")!.inflate([":a": "a"]),
            URL(string: "?a=a")!
        )

        XCTAssertEqual(
            try URL(string: "?:a")!.inflate([:]),
            URL(string: "?")!
        )

        XCTAssertEqual(
            try URL(string: "?:a")!.inflate([":a": "a"]),
            URL(string: "?a=a")!
        )
    }
}
