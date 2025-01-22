import ArgumentParser

@main struct Mammut: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A command-line Mastodon client.",
        subcommands: [LoginCommand.self],
        defaultSubcommand: LoginCommand.self)
}
