# Bible Flashcards

A personal Android app for memorizing and reviewing Bible verses. Built around the Navigator Topical Memory System (TMS) packs, it supports structured weekly learning with active testing and passive audio review.

## What it does

**Verse management** — Browse pre-loaded Navigator TMS packs (Series 1 & 2) across ESV, CSB, and NLT. Set one verse as your verse-of-the-week, mark verses memorized as you go, and add custom verses outside the packs.

**Testing** — Actively test recall in three formats: recite (self-rated), type (scored by word-level LCS), or fill-in-the-blank. Two modes: verse-of-week (current verse only) or review (5 random memorized verses). Results are stored per-session with per-card scores.

**Audio review** — Text-to-speech playback sequences reference → timed pause → verse text. A continuous shuffle mode plays through all memorized verses in the background. An optional interruption feature fires a random verse at a configurable probability and threshold to reinforce spaced repetition during other activities.

**Privacy-first, fully offline** — No network access, no accounts, no cloud sync. The SQLite database is encrypted with a hardware-backed key (Android Keystore). Typed test input is never written to storage.

## Documentation

| Doc | Contents |
|---|---|
| [docs/overview.md](docs/overview.md) | Architecture, tech stack, key constraints |
| [docs/features/verse-management.md](docs/features/verse-management.md) | Verse lifecycle, packs, encryption |
| [docs/features/test-modes.md](docs/features/test-modes.md) | Test modes, formats, scoring algorithm |
| [docs/features/audio.md](docs/features/audio.md) | TTS state machine, review loop, interruption service |
| [DEVELOPER.md](DEVELOPER.md) | Setup, build, emulator, device testing, running tests |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

## Platform

Android only (target: Android 13+, tested on Google Pixel 9 Pro with Android 16). No iOS, web, or desktop support.
