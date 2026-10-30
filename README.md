# OpenTile

A native, open-source macOS grid window manager with Divvy shortcut migration.

**Status:** in development. macOS 13+, Swift 6. No third-party dependencies.

## Build and run

```sh
./scripts/build-app.sh
open build/OpenTile.app
```

Grant OpenTile Accessibility permission when prompted so it can move windows. Quit Divvy before enabling overlapping global shortcuts. Settings → Import Divvy reads your local preferences without modifying Divvy. Configuration is stored locally in Application Support/OpenTile; personal shortcuts are never committed.

## Development

```sh
swift test
./scripts/build-app.sh
```

See [implementation plan](docs/PLAN.md), [feature research](docs/FEATURES.md), and [validation](docs/VALIDATION.md). Contributions welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). MIT licensed. Independent project; not affiliated with Mizage. Divvy is its owner's trademark; no vendor code or artwork is included.
