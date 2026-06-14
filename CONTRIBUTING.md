# Contributing

Thanks for considering a contribution.

## Development

Requirements:

- macOS 13 or newer
- Xcode Command Line Tools
- Swift 5.9 or newer

Run the app locally:

```bash
./script/build_and_run.sh
```

Run tests:

```bash
swift test
```

## Pull Requests

- Keep changes focused.
- Add or update tests for parser, replay, and classification behavior.
- Run `swift test` before opening a pull request.
- Avoid committing generated artifacts such as `.build/` or `dist/`.

## Notes

This project reads Codex Desktop's local JSONL session logs. Those logs are not a public stable API, so parser changes should be defensive and covered by tests.
