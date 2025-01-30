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
        let host = handle.replacing(/.*@/, with: "https://")
                        
        if await Config.shared.getToken(handle: handle) != nil {
            throw ValidationError("Already logged in to \(handle). Run `mammut logout` to log out.")
        }
                
        guard let instanceUrl = URL(string: host) else {
            throw ValidationError("invalid URL")
        }
        
        // start server to receive oauth response
        let server = try await OAuthClientServer.start(port: listeningPort)
        
        let app: OAuthApp
        if let cached = await Config.shared.getApp(host: host) {
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
            try await Config.shared.addApp(host: host, app: app)
        }
        
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
        try await Config.shared.addToken(handle: handle, token: token)
        
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

