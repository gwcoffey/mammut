import Foundation
import MastodonApi

public final actor Config {
        
    private struct Cache<Value: Codable> {
        private let file: URL
        private var content: [String:Value]
        
        init(_ file: URL) throws {
            self.file = file
            if FileManager.default.fileExists(atPath: file.path) {
                content = try JSONDecoder().decode([String:Value].self, from: try Data(contentsOf: file))
            } else {
                content = [:]
            }
        }
        
        func get(_ key: String) -> Value? {
            return content[key]
        }
        
        mutating func set(_ value: Value, forKey key: String) throws {
            content[key] = value
            try store()
        }
        
        mutating func remove(_ key: String) throws {
            content.removeValue(forKey: key)
            try store()
        }
        
        private func store() throws {
            try JSONEncoder().encode(content).write(to: file)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path())
        }
    }
    
    private static var defaultRoot: URL {
        return FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".mammut")
    }
        
    static let shared = try! {
        try FileManager.default
            .createDirectory(at: defaultRoot, withIntermediateDirectories: true, attributes: nil)
        return try Config(defaultRoot)
    }()
    
    private var cachedApps: Cache<OAuthApp>
    private var cachedTokens: Cache<OAuthToken>
    
    internal init(_ root: URL) throws {
        self.cachedApps = try Cache<OAuthApp>(root.appendingPathComponent("apps.json"))
        self.cachedTokens = try Cache<OAuthToken>(root.appendingPathComponent("tokens.json"))
    }
    
    public func getApp(host: String) -> OAuthApp? {
        return cachedApps.get(host)
    }

    public func addApp(host: String, app: OAuthApp) throws {
        try cachedApps.set(app, forKey: host)
    }
    
    public func removeApp(host: String) throws {
        try cachedApps.remove(host)
    }

    public func getToken(handle: String) -> OAuthToken? {
        return cachedTokens.get(handle)
    }

    public func addToken(handle: String, token: OAuthToken) throws {
        try cachedTokens.set(token, forKey: handle)
    }
    
    public func removeToken(handle: String) throws  {
        try cachedTokens.remove(handle)
    }
}
