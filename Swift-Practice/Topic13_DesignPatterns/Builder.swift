import Foundation

// Builder: assemble a complex object step by step with a fluent chain.

struct RequestBuilder {
    private let base: String
    private var httpMethod = "GET"
    private var path = ""
    private var queryItems: [URLQueryItem] = []
    private var headers: [String: String] = [:]
    private var body: Data?

    init(base: String) { self.base = base }

    func method(_ value: String) -> RequestBuilder { var c = self; c.httpMethod = value; return c }
    func path(_ value: String) -> RequestBuilder { var c = self; c.path = value; return c }
    func query(_ name: String, _ value: String) -> RequestBuilder {
        var c = self; c.queryItems.append(URLQueryItem(name: name, value: value)); return c
    }
    func header(_ name: String, _ value: String) -> RequestBuilder {
        var c = self; c.headers[name] = value; return c
    }
    func body(_ data: Data) -> RequestBuilder { var c = self; c.body = data; return c }

    func build() -> URLRequest {
        var comps = URLComponents(string: base + path)!
        if !queryItems.isEmpty { comps.queryItems = queryItems }
        var request = URLRequest(url: comps.url!)
        request.httpMethod = httpMethod
        request.httpBody = body
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        return request
    }
}
