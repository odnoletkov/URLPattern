import Foundation

public extension URL {
    /// 1. When present in `pattern` scheme, host, user, password, port and fragment should match exactly
    /// 2. Path should match exactly; path components prefixed with ':' will be captured in the output
    /// 3. Pattern's query items should be a subset of receiver's query items
    /// 4. Prefix a query parameter's name with ':' and provide any value (empty recommended) to make it a required parameter captured in output
    /// 5. Prefix a query parameter's name with ':' and leave it without value to make it optional parameter captured in output
    func match(pattern: URL) throws -> [String: String] {

        func check<T: Comparable>(_ keyPath: KeyPath<URL, T?>) throws {
            if let patternValue = pattern[keyPath: keyPath],
               self[keyPath: keyPath] != patternValue {
                throw MatchError.componentDoesNotMatch(keyPath)
            }
        }
        try check(\.scheme)
        try check(\.host)
        try check(\.user)
        try check(\.password)
        try check(\.port)
        try check(\.fragment)

        let pathParameters = Dictionary(
            zip(pattern.pathComponents, pathComponents)
                .filter { $0.0.hasPrefix(":") }
        ) { $1 }
        let rewrittenPath = pattern.pathComponents.map { pathParameters[$0] ?? $0 }
        guard rewrittenPath.elementsEqual(pathComponents) else {
            throw MatchError.pathDoesNotMatch
        }

        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let patternComponents = URLComponents(url: pattern, resolvingAgainstBaseURL: false)
        else {
            throw MatchError.invalidURL
        }
        let queryDictionary = Dictionary(
            (components.queryItems ?? []).map { ($0.name, $0.value) }
        ) { $1 }
        var queryParameters = Dictionary(
            (patternComponents.queryItems ?? [])
                .filter { $0.name.hasPrefix(":") && $0.value != nil }
                .compactMap { item in
                    queryDictionary[(item.name as NSString).substring(from: 1)]
                        .map { (item.name, $0) }
                }
        ) { $1 }
        let rewrittenQuery: [URLQueryItem] = (patternComponents.queryItems ?? [])
            .compactMap { item in
                if item.name.hasPrefix(":") {
                    if item.value != nil {
                        queryParameters[item.name]
                            .map { URLQueryItem(name: (item.name as NSString).substring(from: 1), value: $0) }
                            ?? item
                    } else {
                        nil
                    }
                } else {
                    item
                }
            }

        let missingQueryItems = Set(rewrittenQuery).subtracting(components.queryItems ?? [])
        guard missingQueryItems.isEmpty else {
            throw MatchError.missingQueryItems(missingQueryItems)
        }

        queryParameters.merge(
            (patternComponents.queryItems ?? [])
                .filter { $0.value == nil && $0.name.hasPrefix(":") }
                .compactMap { item in
                    queryDictionary[(item.name as NSString).substring(from: 1)]
                        .map { (item.name, $0) }
                }
        ) { $1 }

        return pathParameters.merging(
            queryParameters.compactMap { key, value in value.map { (key, $0) } }
        ) { $1 }
    }

    enum MatchError: Error, Equatable {
        case componentDoesNotMatch(PartialKeyPath<URL>)
        case pathDoesNotMatch
        case invalidURL
        case missingQueryItems(Set<URLQueryItem>)
    }

    func fillPattern(_ params: [String: String]) throws -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            throw PatternFillError.invalidURL
        }

        components.path = NSString.path(
            withComponents: try pathComponents.map { component in
                if component.hasPrefix(":") {
                    if let providedValue = params[component] {
                        providedValue
                    } else {
                        throw PatternFillError.missingParameter(component)
                    }
                } else {
                    component
                }
            }
        )

        components.queryItems = try components.queryItems?.compactMap { item in
            if item.name.hasPrefix(":") {
                if let providedValue = params[item.name] {
                    .init(name: (item.name as NSString).substring(from: 1), value: providedValue)
                } else {
                    if item.value == nil {
                        nil
                    } else {
                        throw PatternFillError.missingParameter(item.name)
                    }
                }
            } else {
                item
            }
        }

        guard let url = components.url else {
            throw PatternFillError.invalidURL
        }

        return url
    }

    enum PatternFillError: Error {
        case missingParameter(String)
        case invalidURL
    }
}
