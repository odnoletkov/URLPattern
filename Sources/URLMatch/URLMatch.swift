import Foundation

public extension URL {
    /// 1. When present in `pattern` scheme, host, user, password, port and fragment should match exactly
    /// 2. Path should match exactly; path components prefixed with ':' will be captured in the output
    /// 3. Pattern's query items should be a subset of receiver's query items
    /// 4. Prefix a query parameter's name with ':' and provide any value (empty recommended) to make it a required parameter captured in output
    /// 5. Prefix a query parameter's name with ':' and leave it without value to make it optional parameter captured in output
    func match(pattern: URL) throws -> [String: String] {

        func match<T: Comparable>(_ keyPath: KeyPath<URL, T?>) throws {
            if let patternValue = pattern[keyPath: keyPath],
               self[keyPath: keyPath] != patternValue {
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
            zip(pattern.pathComponents, pathComponents)
                .filter { (componentInPattern, _) in componentInPattern.hasPrefix(":") }
        ) { _, _ in throw MatchError.duplicateParameterInPattern }

        let requiredPath = pattern.pathComponents.map { pathParameters[$0] ?? $0 }
        guard requiredPath.elementsEqual(pathComponents) else {
            throw MatchError.pathDoesNotMatch
        }

        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let patternComponents = URLComponents(url: pattern, resolvingAgainstBaseURL: false)
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

    func fillPattern(_ params: [String: String]) throws -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            throw FillError.invalidURL
        }

        components.path = NSString.path(
            withComponents: try pathComponents.map { component in
                if component.hasPrefix(":") {
                    if let providedValue = params[component] {
                        providedValue
                    } else {
                        throw FillError.missingParameter(component)
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
                        throw FillError.missingParameter(item.name)
                    }
                }
            } else {
                item
            }
        }

        guard let url = components.url else {
            throw FillError.invalidURL
        }

        return url
    }

    enum FillError: Error, Equatable {
        case missingParameter(String)
        case invalidURL
    }
}
