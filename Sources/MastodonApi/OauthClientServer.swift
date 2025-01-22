import Foundation
import FlyingFox
import ArgumentParser

private let authBody = """
<!DOCTYPE html>
<html>
<head>
    <title>Authorize mammut</title>
    <style>
        :root {
            --background: #eee;
            --color: #111;
            --border-color: #ccc;
            --modal-background: #f5f5f5;
            @media (prefers-color-scheme: dark) {
                --background: #111;
                --color: #ccc;
                --border-color: #444;
                --modal-background: #181818;
            }
        }

        * {
            box-sizing: border-box;
            text-align: center;
            font-size: 16px;
            font-family: sans-serif;
            color: var(--color);
        }

        body {
            background: var(--background);
        }

        #modal {
            max-width: 400px;
            margin: 3em auto 0 auto;
            background: var(--modal-background);
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 2px 1px var(--border-color);
        }

        h1 {
            margin: 0;
            padding: 1em;
            background: var(--border-color);
        }

        p {
            margin: 0 auto 0 auto;
            padding: 2em;
        }
    </style>
</head>
<body>
    <div id="modal">
        <h1>Authorization Complete</h1>
        <p><strong>mammut</strong> has been authorized. Close this window and 
        return to the terminal to continue.</p>
    </div>
</body>
</html>
"""

/// A local HTTP server to provide an OAuth redirect endpoint.
public class OAuthClientServer {
    private enum OauthServerError: Error {
        case unexpectedError(String)
    }
    
    private let port: UInt16
        
    /// An AsyncStream that provided the OAuth authorization code after redirection
    public let stream: AsyncStream<String>
    
    /// The url to the authorization callback endpoint
    public var redirectUrl: URL {
        return URL(string: "http://localhost:\(port)/auth-callback")!
    }

    private init(port: UInt16, stream: AsyncStream<String>) {
        self.port = port
        self.stream = stream
    }
    
    /// Instantiate a server and start listening. This function returns when the server is fully
    /// up and listeneing.
    public static func start(port: UInt16 = 0) async throws  -> OAuthClientServer {
        let server = HTTPServer(port: port)

        let (localStream, continuation) = Self.makeAsyncStream()

        await server.appendRoute("/auth-callback") { [continuation] request in
            guard let code = request.query["code"] else {
                throw OauthServerError.unexpectedError("/auth-callback unexpectedly called with no code")
            }
            continuation.yield(code)
            return HTTPResponse(statusCode: .ok, body: Data(authBody.utf8))
        }

        Task {
            try await server.run()
        }

        try await server.waitUntilListening()
        
        return OAuthClientServer(
            port: try await getServerPort(server),
            stream: localStream)
    }
    
    private static func makeAsyncStream() -> (AsyncStream<String>, AsyncStream<String>.Continuation) {
        var continuation: AsyncStream<String>.Continuation!
        let stream = AsyncStream<String> { continuation = $0 }
        return (stream, continuation)
    }
    
    private static func getServerPort(_ server: HTTPServer) async throws -> UInt16 {
        switch await server.listeningAddress {
        case .ip4(_, let port), .ip6(_, let port):
            return port
        default:
            throw OauthServerError.unexpectedError("unexpectedly unable to get port number")
        }
    }
}
