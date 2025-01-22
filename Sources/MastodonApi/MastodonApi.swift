import Foundation
import Logging

private let logger = Logger(label: "com.gwcoffey.MastodonApi")

private enum MastodonApiError: Error {
    case unexpected(String)
}

public func createApp(instance: URL, appx: CreateAppRequest) async throws -> CreateAppResponse {
    guard let url = URL(string: Endpoint.createApp.properties.url, relativeTo: instance)?.absoluteURL else {
        throw MastodonApiError.unexpected("unexpectedly unable to make URL")
    }
        
    // create app
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = try JSONEncoder().encode(appx)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    logger.info("Call: \(String(describing: request.httpMethod)) \(request) \(String(data: request.httpBody!, encoding: .utf8))")

    let (data, _) = try await URLSession.shared.data(for: request)
    do {
        let response = try JSONDecoder().decode(CreateAppResponse.self, from: data)
        return response
    } catch {
        logger.info("Response: \(String(describing: String(data: data, encoding: .utf8)))")
        throw error
    }
}

public func getOAuthToken(instance: URL, app: CreateAppResponse, code: String) async throws -> Token {
    guard let url = URL(string: Endpoint.oauthToken.properties.url, relativeTo: instance)?.absoluteURL else {
        throw MastodonApiError.unexpected("unexpectedly unable to make URL")
    }
        
    // create app
    var request = URLRequest(url: url)
    request.httpMethod = Endpoint.oauthToken.properties.method.rawValue
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    let formData: [String: String] = [
        "client_id": app.clientId,
        "client_secret": app.clientSecret,
        "redirect_uri": app.redirectUri,
        "grant_type": "authorization_code",
        "code": code,
        "scope": "read"
    ]
    let formEncodedString = formData.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    request.httpBody = formEncodedString.data(using: .utf8)

    logger.info("Call: \(String(describing: request.httpMethod)) \(request) \(String(data: request.httpBody!, encoding: .utf8))")

    let (data, _) = try await URLSession.shared.data(for: request)
    do {
        let response = try JSONDecoder().decode(Token.self, from: data)
        return response
    } catch {
        logger.info("Response: \(String(describing: String(data: data, encoding: .utf8)))")
        throw error
    }

}

// ENDPOINTS
private enum Method: String {
    case post = "POST"
}

private enum Endpoint {
    case createApp
    case oauthToken
    
    struct Properties {
        let url: String
        let method: Method
    }
    
    var properties: Properties {
        switch self {
        case .createApp:
            return Properties(url: "/api/v1/apps", method: .post)
        case .oauthToken:
            return Properties(url: "/oauth/token", method: .post)
        }
    }
}

// ENTITIES

public struct CreateAppRequest: Codable {
    let clientName: String
    let redirectUris: [String]
    let scopes: [String]?
    let website: String?
    
    enum CodingKeys: String, CodingKey {
        case clientName = "client_name"
        case redirectUris = "redirect_uris"
        case scopes = "scopes"
        case website = "website"
    }
    
    public init(clientName: String, redirectUris: [String], scopes: [String]? = nil, website: String? = nil) {
        self.clientName = clientName
        self.redirectUris = redirectUris
        self.scopes = scopes
        self.website = website
    }
}

public struct CreateAppResponse: Codable {
    public let id: String
    public let name: String
    public let website: URL?
    public let scopes: [String]
    public let redirectUri: String
    public let redirectUris: [String]
    public let clientId: String
    public let clientSecret: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case website
        case scopes
        case redirectUri = "redirect_uri"
        case redirectUris = "redirect_uris"
        case clientId = "client_id"
        case clientSecret = "client_secret"
    }
}

public struct Token: Codable {
    public let accessToken: String
    public let tokenType: String
    public let scope: String
    public let createdAt: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case createdAt = "created_at"
    }
}
