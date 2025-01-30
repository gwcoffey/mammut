import Foundation
import Testing
import MastodonApi
import XCTest

@testable import mammut

private enum TestError: Error {
    case resourceNotFound(String)
}

@Test func testLoadEmptyConfig() async throws {
    let config = try Config(findTestConfig("EmptyConfig"))
    
    await #expect(config.getApp(host: "https://example.com") == nil)
    await #expect(config.getToken(handle: "@me@example.com") == nil)
}

@Test func testLoadConfigWithApps() async throws {
    let config = try Config(findTestConfig("ConfigWithApp"))
    let app = await config.getApp(host: "https://example.com")
    
    #expect(app != nil)
    #expect(app!.name == "My App")
}

@Test func testLoadConfigWithTokens() async throws {
    let config = try Config(findTestConfig("ConfigWithToken"))
    let token = await config.getToken(handle: "@me@example.com")
    
    #expect(token != nil)
    #expect(token!.accessToken == "some-token")
}

@Test func testWriteConfig() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    
    defer {
        try! FileManager.default.removeItem(at: tempDir)
    }

    var config = try Config(tempDir)
    var cachedApp = await config.getApp(host: "https://example.com")
    var cachedToken = await config.getToken(handle: "@me@example.com")
    #expect(cachedApp == nil)
    #expect(cachedToken == nil)

    let app = try! JSONDecoder().decode(OAuthApp.self, from:
            """
            {
                "redirect_uri": "http://localhost:5001/auth-callback",
                "name": "My App",
                "scopes": [
                  "read"
                ],
                "client_secret": "some-secret",
                "id": "1",
                "redirect_uris": [
                  "http://localhost:5001/auth-callback"
                ],
                "client_id": "some-id"
            }
            """.data(using: .utf8)!
    )
    let token = try! JSONDecoder().decode(OAuthToken.self, from:
            """
            {
                "access_token": "some-token",
                "scope": "read",
                "token_type": "Bearer",
                "created_at": 1737408663
            }            
            """.data(using: .utf8)!
    )
    
    try await config.addApp(host: "https://example.com", app: app)
    try await config.addToken(handle: "@me@example.com", token: token)
    
    config = try Config(tempDir)
    cachedApp = await config.getApp(host: "https://example.com")
    cachedToken = await config.getToken(handle: "@me@example.com")
    
    #expect(cachedApp != nil)
    #expect(cachedApp!.name == "My App")
    #expect(cachedToken != nil)
    #expect(cachedToken!.accessToken == "some-token")
}

private func findTestConfig(_ name: String) throws -> URL {
    let resources = try XCTUnwrap(Bundle.module.resourceURL)
    let spmUrl = resources.appendingPathComponent("ConfigTests/\(name)")
    let xcodeUrl = resources.appendingPathComponent("Resources/ConfigTests/\(name)")
    
    if FileManager.default.fileExists(atPath: spmUrl.path) {
        return spmUrl
    }
    else if FileManager.default.fileExists(atPath: xcodeUrl.path) {
        return xcodeUrl
    }
    else {
        XCTFail("Could not find test config '\(name)' at either \(spmUrl) or \(xcodeUrl)")
        throw TestError.resourceNotFound(name)
    }
}
