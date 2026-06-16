# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.7.1] - 2026-05-26

### Changed
- Bumped `vite` dev dependency from 8.0.10 to 8.0.16

## [5.7.0+3] - 2026-05-25

### Added
- Added npm publishing workflow (GitHub Actions) and `PUBLISHING.md` documentation
- Added 100% typed API coverage — TypeScript declaration files for all 14 OBS WebSocket v5.7.0 namespace classes

### Changed
- Package renamed from `@unngh/obs-websocket-js` to `@unngh/obs-websocket`
  - Previous version: [@unngh/obs-websocket-js](https://www.npmjs.com/package/@unngh/obs-websocket-js)
- Made Node.js the default import path — `@unngh/obs-websocket` (no `/node` subpath needed)
- Clarified dual entrypoints (Node.js vs Browser) in README documentation
- Fixed dart2js WebSocket binding by bypassing broken conditional import (`dart.library.html`) with direct `WebSocketChannel.connect`
- Updated GitHub Actions workflow to use `main` branch instead of `master`
- Fixed README sample code to match actual API signatures
- Removed `--server-mode` flag from dart2js compilation
- Removed `obs_chat` references from workspace configuration
- Bumped `ws` dependency from 8.20.0 to 8.20.1 (resolves uninitialized memory disclosure)