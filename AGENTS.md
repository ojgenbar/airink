# Agent guidelines

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/): `<type>(<scope>): <description>`

- **type**: `feat`, `fix`, `docs`, `refactor`, `test`, `perf`, `build`, `ci`, `chore`
- **scope** (optional): the area touched, usually an `Airink/` folder: `editor`, `hotkey`, `clipboard`, `render`, `model`, `settings`, `app`, or `readme`, `release`, `icon`
- **description**: imperative mood, lowercase, no trailing period, subject line ≤ 72 characters
- Add a body after a blank line when the *why* isn't obvious. Mark breaking changes with `!` (`feat(hotkey)!: …`).

Examples:

```
fix(editor): bind shortcuts to physical keys on every keyboard layout
feat(editor): add pixelate tool
docs(readme): add editor screenshot
build(release): add make-dmg script
```

## Workflow

- Work on a feature branch (`feat/…`, `fix/…`, `docs/…`, `chore/…`), never directly on `main`.
- Run the tests before committing: `xcodebuild -scheme Airink -destination 'platform=macOS' test`
- Open a PR against `main`; the maintainer merges.
