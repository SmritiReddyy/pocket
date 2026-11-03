# Developer docs

Everything here is for people who want to build, change or ship Pocket. If you only want
to use the app, see [How to use it](HOW-TO-USE.md).

| Doc | What's in it |
|---|---|
| [Research](RESEARCH.md) | What the iPhone Dynamic Island does and what moved to the Mac |
| [Design](DESIGN.md) | Sizes, colours, type and motion |
| [Architecture](ARCHITECTURE.md) | How the code is organised, data flow, debug commands |
| [QA report](QA.md) | Tests, on-screen checks, performance, known limitations |
| [Shipping](SHIPPING.md) | Versions, the changelog, and making a release |
| [Changelog](../CHANGELOG.md) | What changed in each version |

## Build and run

Needs Swift 6, from Xcode or just Apple's Command Line Tools (`xcode-select --install`).

The scripts pick the SDK for you: some Command Line Tools updates ship an SDK that can't build
SwiftUI on its own, so they use the newest one that can (`Scripts/sdk.sh`) and print which. Set
`SDKROOT` to choose one yourself.

```bash
git clone https://github.com/SmritiReddyy/pocket.git
```

```bash
cd pocket && ./Scripts/build-app.sh
```

```bash
open "build/Pocket.app"
```

`CONFIG=debug ./Scripts/build-app.sh` builds a debug app that also accepts the debug commands
listed in [Architecture](ARCHITECTURE.md). You can also open `Package.swift` in Xcode.

## Checks

Unit tests plus a release build where any warning is an error:

```bash
./Scripts/check.sh
```
