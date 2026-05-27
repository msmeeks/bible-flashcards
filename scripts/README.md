# scripts/

## setup-mac.sh

One-command macOS setup for the Bible Flashcards Flutter/Android project.

```sh
cd /path/to/bible-flashcards
bash scripts/setup-mac.sh
```

Installs Homebrew, Java 17, Flutter ≥ 3.22, Android command-line tools (API 35),
and creates a Pixel 9 Pro emulator AVD. Safe to re-run; skips anything already
present. See the script header for flags (`--skip-emulator`, `--verify-only`,
`--help`) and the embedded troubleshooting table.

Full instructions: [DEVELOPER.md](../DEVELOPER.md)
