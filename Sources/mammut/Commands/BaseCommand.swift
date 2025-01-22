import ArgumentParser
import Logging

public struct CommonOptions: ParsableCommand {
    @Flag(name: .shortAndLong, help: "Use verbose logging.")
    var verbose = false
    
    public init() {}
}

public protocol BaseCommand: AsyncParsableCommand {
    var commonOptions: CommonOptions { get }
    func runCommand() async throws
}

extension BaseCommand {
    public func run() async throws {
        let logLevel: Logger.Level = commonOptions.verbose ? .info : .notice
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = logLevel
            return handler
        }

        try await self.runCommand()
    }
}
