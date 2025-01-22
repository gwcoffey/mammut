A command-line client for Mastodon


# Proposed Interface

mammut <command> <subcommand> [-v] [--in=] [--out=] [--in:*=] [--template=]

* `-v` verbose mode
* `--in` input format, one of:
  * `json`: json on STDIN of the underlying mastodon API
  * `text`: (only applies to single-required-property) the value of the property on STDIN
  * `args`: (default) arguments of the form `in:foo` where foo is a property of the mastodon JSON
* `--out` output format, one of:
  * `raw`: the raw mastodon API response
  * `pretty`: the raw mastodon API response, pretty printed
  * `template`: applies the response data to template in `--template` and returns the result
  * `visual`: (default) applies a pretty ansi-colored builtin template

Example:

Post a status:
```sh
mammut status post --in:status="Hello World!" --in:visibility=public
```

List feed
```sh
mammus timeline get home --out=raw
```
