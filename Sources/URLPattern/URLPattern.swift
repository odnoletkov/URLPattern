import Foundation

public extension URL {
    
    /// Match `url` against pattern in the receiver
    ///
    /// 1. When present in the receiver scheme, host, user, password, port and fragment should match exactly
    /// 2. Path should match exactly; path components prefixed with ':' will be captured in the output
    /// 3. Receiver's query items should be a subset of argument's query items
    /// 4. To capture required query parameter: prefix it with ':' and provide any value (empty recommended) in the pattern
    /// 5. To capture optional query parameter: prefix it with ':' and leave it without value (no '=' sign) in the pattern
    ///
    /// - Parameter url: URL to match against pattern in the receiver
    /// - Returns: Parameters captured on successful match; keys preserve the ':' prefix
    func match(_ url: URL) throws -> [String: String] {

        func match<T: Comparable>(_ keyPath: KeyPath<URL, T?>) throws {
            if let patternValue = self[keyPath: keyPath],
               url[keyPath: keyPath] != patternValue {
                throw MatchError.componentDoesNotMatch(keyPath)
            }
        }
        try match(\.scheme)
        try match(\.host)
        try match(\.user)
        try match(\.password)
        try match(\.port)
        try match(\.fragment)

        let pathParameters = try Dictionary(
            zip(self.pathComponents, url.pathComponents)
                .filter { (componentInPattern, _) in componentInPattern.hasPrefix(":") }
        ) { _, _ in throw MatchError.duplicateParameterInPattern }

        let requiredPath = self.pathComponents.map { pathParameters[$0] ?? $0 }
        guard requiredPath.elementsEqual(url.pathComponents) else {
            throw MatchError.pathDoesNotMatch
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let patternComponents = URLComponents(url: self, resolvingAgainstBaseURL: false)
        else {
            throw MatchError.invalidURL
        }

        let queryDictionary = Dictionary(
            (components.queryItems ?? [])
                .compactMap { item in item.value.map { (item.name, $0) } }
        ) { $1 }

        let queryParameters = try Dictionary(
            (patternComponents.queryItems ?? [])
                .filter { $0.name.hasPrefix(":") }
                .compactMap { item in
                    queryDictionary[(item.name as NSString).substring(from: 1)]
                        .map { (item.name, $0) }
                }
        ) { _, _ in throw MatchError.duplicateParameterInPattern }

        let requiredQueryItems = (patternComponents.queryItems ?? [])
            .compactMap { item in
                if item.name.hasPrefix(":") {
                    if item.value != nil {
                        queryParameters[item.name]
                            .map { .init(name: (item.name as NSString).substring(from: 1), value: $0) }
                        ?? item
                    } else {
                        nil
                    }
                } else {
                    item
                }
            }

        let missingQueryItems = Set(requiredQueryItems).subtracting(components.queryItems ?? [])
        guard missingQueryItems.isEmpty else {
            throw MatchError.missingQueryItems(missingQueryItems)
        }

        return try pathParameters.merging(queryParameters) { _, _ in throw MatchError.duplicateParameterInPattern }
    }

    enum MatchError: Error, Equatable {
        case componentDoesNotMatch(PartialKeyPath<URL>)
        case pathDoesNotMatch
        case invalidURL
        case missingQueryItems(Set<URLQueryItem>)
        case duplicateParameterInPattern
    }
    
    /// Inflate URL pattern in the receiver with provided parameter values
    ///
    /// See `URL.match(_: URL)`
    ///
    /// - Parameter params: values to substitute parameters in the pattern
    /// - Returns: URL with substituted values
    func inflate(_ params: [String: String]) throws -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            throw InflateError.invalidURL
        }

        components.path = NSString.path(
            withComponents: try pathComponents.map { component in
                if component.hasPrefix(":") {
                    if let providedValue = params[component] {
                        providedValue
                    } else {
                        throw InflateError.missingParameter(component)
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
                        throw InflateError.missingParameter(item.name)
                    }
                }
            } else {
                item
            }
        }

        guard let url = components.url else {
            throw InflateError.invalidURL
        }

        return url
    }

    enum InflateError: Error, Equatable {
        case missingParameter(String)
        case invalidURL
    }
}
