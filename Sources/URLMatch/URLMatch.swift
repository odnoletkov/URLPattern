import Foundation

public extension URL {
    /// 1. When present in `pattern` scheme, host, user, password, port and fragment should match exactly
    /// 2. Path should match exactly; path components prefixed with ':' will be captured in the output
    /// 3. Pattern's query items should be a subset of receiver's query items
    /// 4. Prefix a query parameter's name with ':' and make the value empty to make it a required parameter captured in output
    /// 5. Prefix a query parameter's name with ':' and leave it without value to make it optional parameter captured in output
    func match(pattern: URL) -> [String: String]? {
        guard
            pattern.scheme == nil || pattern.scheme == scheme,
            pattern.host == nil || pattern.host == host,
            pattern.user == nil || pattern.user == user,
            pattern.password == nil || pattern.password == password,
            pattern.port == nil || pattern.port == port,
            pattern.fragment == nil || pattern.fragment == fragment,
            pattern.pathComponents.count == pathComponents.count
        else {
            return nil
        }

        let pathParameters = Dictionary(
            zip(pattern.pathComponents, pathComponents)
                .filter { $0.0.hasPrefix(":") }
        ) { $1 }
        let rewrittenPath = pattern.pathComponents.map { pathParameters[$0] ?? $0 }
        guard rewrittenPath.elementsEqual(pathComponents) else {
            return nil
        }

        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let patternComponents = URLComponents(url: pattern, resolvingAgainstBaseURL: false)
        else {
            return nil
        }
        let queryDictionary = Dictionary(
            (components.queryItems ?? []).map { ($0.name, $0.value) }
        ) { $1 }
        var queryParameters = Dictionary(
            (patternComponents.queryItems ?? [])
                .filter { $0.name.hasPrefix(":") && $0.value == "" }
                .compactMap { item in
                    queryDictionary[(item.name as NSString).substring(from: 1)]
                        .map { (item.name, $0) }
                }
        ) { $1 }
        let rewrittenQuery: [URLQueryItem] = (patternComponents.queryItems ?? [])
            .compactMap { item in
                if item.name.hasPrefix(":") {
                    if item.value == "" {
                        return queryParameters[item.name]
                            .map { URLQueryItem(name: (item.name as NSString).substring(from: 1), value: $0) }
                            ?? item
                    } else {
                        return nil
                    }
                } else {
                    return item
                }
            }
        guard Set(rewrittenQuery).isSubset(of: components.queryItems ?? []) else {
            return nil
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

    enum PatternFillError: Error {
        case missingParameter(String)
        case invalidURL
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
                    switch item.value {
                    case nil:
                        nil
                    case "":
                        throw PatternFillError.missingParameter(item.name)
                    case .some:
                        item
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
}
