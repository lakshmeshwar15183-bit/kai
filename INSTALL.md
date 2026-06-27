# Installing Kai

## For users (macOS 14+)

1. Download `Kai.dmg` from the releases page (or build it — see below).
2. Open the DMG and drag **Kai** to **Applications**.
3. Launch Kai. On first run, open **Permissions** and grant what you need
   (Accessibility, Screen Recording, Microphone, Speech). Kai works with zero
   configuration using its offline assistant; add an AI provider in **Settings**
   for full intelligence.

> Kai is asleep by default and only acts when you type, click the mic, or use
> the wake phrase. Say **Stop / Pause / Cancel / Abort** to halt it instantly.

## For developers (any platform)

The engines, skills, AI providers, and tests build and run anywhere Swift 6 is
installed:

```bash
swift build         # compile everything
swift test          # run the full suite (104 tests)
swift run kai-cli   # exercise the whole pipeline end-to-end (offline)
make                # see all developer shortcuts
```

## Building the macOS app

On a Mac with Xcode 16 / Swift 6:

```bash
make run-app        # launch in development
make app            # build dist/Kai.app
make dmg            # build dist/Kai.dmg installer
```

Full details, signing, notarization, and provider key setup are in
[`docs/MACOS_STEPS.md`](docs/MACOS_STEPS.md).
