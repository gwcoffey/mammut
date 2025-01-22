import ArgumentParser
import Foundation
import MastodonApi

private let listeningPort: UInt16 = 31548

struct LoginCommand: BaseCommand {
    @OptionGroup var commonOptions: CommonOptions

    @Argument(help: "The mastodon handle (eg @me@example.com)")
    var handle: String
    
    static let configuration = CommandConfiguration(
        commandName: "login",
        abstract: "Login to a Mastodon instance.")

    func validate() throws {
        if try /@.+@.+/.wholeMatch(in: handle) == nil {
            throw ValidationError("\(handle) is not a Mastodon handle. Use the @me@example.com form.")
        }
    }
    
    func runCommand() async throws {
        // parse the handle
        var host = handle.replacing(/.*@/, with: "https://")
                
        // make sure we have a local config dir
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let targetURL = homeDirectory.appendingPathComponent(".mammut")
        try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
        var appConfigPath = targetURL.appendingPathComponent("apps.json")
        var tokenConfigPath = targetURL.appendingPathComponent("tokens.json")

        var cachedTokens: [String: Token]
        if fileManager.fileExists(atPath: tokenConfigPath.path()) {
            cachedTokens = try JSONDecoder().decode([String: Token].self, from: try Data(contentsOf: tokenConfigPath))
        } else {
            cachedTokens = [:]
        }
        
        if cachedTokens[handle] != nil {
            throw ValidationError("Already logged in to \(handle). Run `mammut logout` to log out.")
        }
        
        var cachedApps: [String: CreateAppResponse]
        if fileManager.fileExists(atPath: appConfigPath.path()) {
            cachedApps = try JSONDecoder().decode([String: CreateAppResponse].self, from: try Data(contentsOf: appConfigPath))
        } else {
            cachedApps = [:]
        }
        
        guard let instanceUrl = URL(string: host) else {
            throw ValidationError("invalid URL")
        }
        
        // start server to receive oauth response
        let server = try await OAuthClientServer.start(port: listeningPort)
        
        let app: CreateAppResponse
        if let cached = cachedApps[host] {
            app = cached
        } else {
            // create app on this instance
            print("creating new app")
            app = try await createApp(
                instance: instanceUrl,
                appx: CreateAppRequest(
                    clientName: "mammut",
                    redirectUris: [server.redirectUrl.absoluteString],
                    scopes: ["read"]
                )
            )
            cachedApps[host] = app
        }
        
        // store this server app info for future use
        try JSONEncoder().encode(cachedApps).write(to: appConfigPath)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: appConfigPath.path())

        // open the oauth page on the instance
        openURLInBrowser(URL(
            string: "/oauth/authorize?response_type=code&client_id=\(app.clientId)&scope=read&force_login=true&redirect_uri=\(server.redirectUrl)",
            relativeTo: instanceUrl)!.absoluteString)
        
        // wait for the oauth response
        print("waiting for signal from browser")
        var code = ""
        for await signal in server.stream {
            print("Received signal: \(signal)")
            if !signal.isEmpty {
                code = signal
                break
            }
        }
        
        // exchange auth code for user token
        let token = try await getOAuthToken(instance: instanceUrl, app: app, code: code)
        cachedTokens[handle] = token
        
        // store this token info for future use
        try JSONEncoder().encode(cachedTokens).write(to: tokenConfigPath)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenConfigPath.path())

        print(token)
    }
}

func openURLInBrowser(_ url: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [url]
    
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        print("Error opening URL: \(error)")
    }
}

