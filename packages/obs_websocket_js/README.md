# obs_websocket_js

![obs_websocket_js Banner](https://raw.githubusercontent.com/cdavis-code/obs_websocket_workspace/main/packages/obs_websocket_js/image/banner.svg)

**Universal JavaScript/TypeScript client for OBS Studio** — Connect to OBS from Node.js or browsers with full protocol support, type safety, and zero compromises.

Built on the battle-tested [`obs_websocket`](https://pub.dev/packages/obs_websocket) Dart SDK, compiled to JavaScript via `dart2js`. Every request parsed and validated by the same codebase that powers the official Dart package, CLI tools, and MCP server.

[![npm version](https://img.shields.io/npm/v/@unngh/obs-websocket.svg)](https://www.npmjs.com/package/@unngh/obs-websocket)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.6-blue.svg)](https://www.typescriptlang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Why obs_websocket_js?

| Feature | @unngh/obs-websocket | obs-websocket-js |
|---------|------------------|------------------|
| **Protocol Version** | OBS WebSocket v5.7.0 (latest) | v5.x |
| **Type Safety** | Full TypeScript with strict types | TypeScript support |
| **Typed Namespaces** | ✅ `obs.scenes`, `obs.inputs`, `obs.stream` | ❌ Manual `obs.call()` |
| **Promise-based API** | ✅ Modern async/await | ✅ Promise-based |
| **Event System** | EventEmitter3 with typed events | EventEmitter3 |
| **Browser Support** | ✅ Native WebSocket | ✅ Native WebSocket |
| **Node.js Support** | ✅ Auto-detects native WS or polyfills | ✅ Native + ws polyfill |
| **Environment Variables** | ✅ `connectFromEnv()` for easy setup | ❌ Manual configuration |
| **Batch Requests** | ✅ `obs.sendBatch()` | ✅ `obs.callBatch()` |
| **Raw Request Escape** | ✅ `obs.send()` for any protocol method | ✅ `obs.call()` |
| **Bundle Size** | ~150-300 KB (gzipped) | ~50-100 KB (gzipped) |
| **Dual Entrypoints** | ✅ Separate `node` and `browser` builds | ✅ JSON/Msgpack builds |
| **Shared Protocol Core** | ✅ Same logic as Dart/CLI/MCP packages | Standalone implementation |
| **Auto Reconnection** | Planned for v6 | ✅ Built-in |
| **RPC Version Control** | ✅ Automatic negotiation | ✅ Manual `rpcVersion` param |

### Key Advantages

✨ **Typed API Namespaces** — No more guessing request types. IntelliSense guides you with `obs.scenes.getSceneList()`, `obs.inputs.setInputMute()`, etc.

🔒 **Type-Safe Events** — Get full autocomplete on event names and payloads: `obs.on('SceneCreated', (e) => ...)`.

🌍 **Universal Runtime** — One package works everywhere: Node.js 18+, modern browsers, bundlers (Webpack, Vite, Rollup).

⚙️ **Environment Variable Support** — Quick local development with `OBS_WEBSOCKET_URL` and `OBS_WEBSOCKET_PASSWORD`.

🔗 **Protocol Parity** — If it exists in OBS WebSocket protocol, it works here. Backed by the comprehensive Dart SDK.

## Quick Start

### Installation

```bash
npm install @unngh/obs-websocket
# or
yarn add @unngh/obs-websocket
```

### Basic Usage (Node.js / TypeScript)

```typescript
import { ObsWebSocket, EventSubscription } from '@unngh/obs-websocket';

// Connect to OBS
const obs = await ObsWebSocket.connect('ws://localhost:4455', {
  password: 'your_password',
  logLevel: 'info',
});

// List scenes
const { scenes, currentProgramSceneName } = await obs.scenes.getSceneList();
console.log('Current scene:', currentProgramSceneName);
console.log('All scenes:', scenes.map((s) => s.sceneName));

// Subscribe to events
await obs.subscribe(EventSubscription.All);

obs.on('SceneCreated', (event) => {
  console.log('New scene created:', event.eventData.sceneName);
});

// Control inputs
await obs.inputs.setInputMute(true, 'Mic/Aux');
await obs.inputs.setInputVolume(-6.0, 'Mic/Aux');

// Switch scenes
await obs.scenes.setCurrentProgramScene('Gameplay');

// Disconnect when done
await obs.disconnect();
```

### Environment Variable Setup (Node.js only)

Perfect for local development and CI/CD:

```typescript
import { ObsWebSocket } from '@unngh/obs-websocket';

// Reads OBS_WEBSOCKET_URL, OBS_WEBSOCKET_PASSWORD, OBS_WEBSOCKET_TIMEOUT
const obs = await ObsWebSocket.connectFromEnv();
if (!obs) throw new Error('OBS_WEBSOCKET_URL not set in environment');

console.log('Connected via environment config!');
```

Create a `.env` file:
```env
OBS_WEBSOCKET_URL=ws://localhost:4455
OBS_WEBSOCKET_PASSWORD=your_password
OBS_WEBSOCKET_TIMEOUT=120
```

### Browser Usage

```typescript
import { ObsWebSocket } from '@unngh/obs-websocket/browser';

const obs = await ObsWebSocket.connect('ws://localhost:4455', {
  password: 'your_password',
});

// Control OBS from your web app
await obs.scenes.setCurrentProgramScene('Live Scene');
await obs.stream.startStream();
```

> **Note:** Browsers cannot use `connectFromEnv()` — always pass credentials explicitly.

### Choosing an Import Path

This package supports both Node.js and browser environments. Use the appropriate import for your target:

| Import Path | Environment | WebSocket | Typical Use Case |
|---|---|---|---|
| `@unngh/obs-websocket` | **Node.js** (default) | Native (Node 22+) or `ws` polyfill (Node 18-21) | Streaming bots, automation scripts, server integrations, CLI tools |
| `@unngh/obs-websocket/browser` | **Browser** | Native `WebSocket` | Web dashboards, browser extensions, OBS remote control UIs |

**When in doubt, use `@unngh/obs-websocket`** — Node.js is the primary use case for OBS WebSocket automation. Only use the `/browser` subpath if you're building a web application that runs directly in a browser.

> **Browser caveat:** Connecting from a browser requires OBS to accept WebSocket connections from arbitrary origins. OBS does not send CORS headers by default, so you may need to run a local proxy or use a browser extension to bypass CORS restrictions.

## API Reference

### Connection Methods

| Method | Description | Example |
|--------|-------------|---------|
| `ObsWebSocket.connect(url, options)` | Connect to OBS WebSocket server | `await ObsWebSocket.connect('ws://localhost:4455', { password: '...' })` |
| `ObsWebSocket.connectFromEnv()` | Connect using environment variables (Node.js only) | `await ObsWebSocket.connectFromEnv()` |
| `obs.disconnect()` | Close connection gracefully | `await obs.disconnect()` |

### Typed Namespaces

#### Scenes (`obs.scenes`)

```typescript
const { scenes, currentProgramSceneName } = await obs.scenes.getSceneList();
await obs.scenes.setCurrentProgramScene('Scene Name');
await obs.scenes.createScene('New Scene');
await obs.scenes.removeScene('Old Scene');
```

#### Scene Items (`obs.sceneItems`)

```typescript
const { sceneItems } = await obs.sceneItems.getSceneItemList('Scene Name');
await obs.sceneItems.setSceneItemEnabled('Scene', itemId, true);
await obs.sceneItems.setSceneItemTransform('Scene', itemId, {
  positionX: 100,
  positionY: 200,
  rotation: 0,
});
```

#### Inputs (`obs.inputs`)

```typescript
const { inputs } = await obs.inputs.getInputList();
await obs.inputs.setInputMute(true, 'Mic');
await obs.inputs.setInputVolume(-6.0, 'Mic');
const { inputSettings } = await obs.inputs.getInputSettings('Camera');
await obs.inputs.setInputSettings({ ...inputSettings, brightness: 0.5 }, 'Camera');
```

#### Streaming (`obs.stream`)

```typescript
const status = await obs.stream.getStreamStatus();
await obs.stream.startStream();
await obs.stream.stopStream();
await obs.stream.toggleStream();
await obs.stream.sendStreamCaption('Live caption text');
```

#### Recording (`obs.record`)

```typescript
const status = await obs.record.getRecordStatus();
await obs.record.startRecord();
await obs.record.stopRecord();
await obs.record.pauseRecord();
await obs.record.resumeRecord();
await obs.record.toggleRecordPause();
```

#### General (`obs.general`)

```typescript
const version = await obs.general.getVersion();
const stats = await obs.general.getStats();
await obs.general.triggerHotkeyByName('OBSBasic.StartRecording');
await obs.general.broadcastCustomEvent({ custom: 'data' });
```

#### Raw Request Escape Hatch

For any protocol method not covered by typed namespaces:

```typescript
// Send any OBS WebSocket request by name
const response = await obs.send('GetVideoSettings');
await obs.send('SetSceneName', {
  sceneName: 'Old Name',
  newSceneName: 'New Name',
});

// Batch multiple requests
const results = await obs.sendBatch([
  { requestType: 'GetVersion' },
  { requestType: 'GetCurrentProgramScene' },
]);
```

### Event System

Typed event handling with EventEmitter3:

```typescript
import { EventSubscription } from '@unngh/obs-websocket';

// Subscribe to event categories
await obs.subscribe(EventSubscription.All);
// or specific categories:
// await obs.subscribe(EventSubscription.Scenes | EventSubscription.Inputs);

// Listen to specific events
obs.on('SceneCreated', (event) => {
  console.log('Scene created:', event.eventData.sceneName);
});

obs.on('InputMuteStateChanged', (event) => {
  console.log('Input muted:', event.eventData.inputMuted);
});

// Catch-all listener
obs.on('*', (event) => {
  console.log('Event:', event.eventType, event.eventData);
});

// One-time listener
obs.once('StreamStateChanged', (event) => {
  console.log('Stream state changed:', event.outputActive);
});
```

## Builds

The package provides dual entrypoints optimized for different environments:

| Build | Import Path | WebSocket Implementation | Use Case |
|-------|-------------|-------------------------|----------|
| **Node.js (ESM)** | `@unngh/obs-websocket` *(default)* | Native (Node 22+) or `ws` polyfill (Node 18-21) | Server-side apps, CLI tools |
| **Node.js (CommonJS)** | `require('@unngh/obs-websocket')` | Same as above | Legacy Node.js projects |
| **Browser** | `@unngh/obs-websocket/browser` | Native `WebSocket` | Web apps, browser extensions |

### Automatic WebSocket Selection

On Node.js, the package automatically chooses the best WebSocket implementation:
- **Node 22+**: Uses native `globalThis.WebSocket` (no polyfill needed)
- **Node 18-21**: Dynamically loads the `ws` package for compatibility

---

## Configuration Options

### Connection Options

```typescript
interface ConnectOptions {
  password?: string;        // OBS WebSocket password (if required)
  timeout?: number;         // Connection timeout in seconds (default 120)
  logLevel?: 'all' | 'debug' | 'info' | 'warning' | 'error';  // Logging verbosity
}
```

### Environment Variables (Node.js only)

| Variable | Description | Default |
|----------|-------------|---------|
| `OBS_WEBSOCKET_URL` | WebSocket URL to connect to | *Required* |
| `OBS_WEBSOCKET_PASSWORD` | Authentication password | `undefined` (no auth) |
| `OBS_WEBSOCKET_TIMEOUT` | Connection timeout in seconds | `120` |

---

## Examples

### Complete Streaming Workflow

```typescript
import { ObsWebSocket, EventSubscription } from '@unngh/obs-websocket';

const obs = await ObsWebSocket.connectFromEnv();
if (!obs) throw new Error('Set OBS_WEBSOCKET_URL in environment');

// Check OBS version
const { obsVersion } = await obs.general.getVersion();
console.log(`Connected to OBS ${obsVersion}`);

// Get current scene and switch
const { currentProgramSceneName } = await obs.scenes.getSceneList();
console.log(`Currently on: ${currentProgramSceneName}`);

await obs.scenes.setCurrentProgramScene('Live Scene');

// Start streaming
await obs.stream.startStream();
console.log('Stream started!');

// Listen for stream events
obs.on('StreamStateChanged', (event) => {
  if (event.eventData.outputActive) {
    console.log('Stream is live!');
  } else {
    console.log('Stream stopped');
  }
});

// Graceful shutdown
process.on('SIGINT', async () => {
  await obs.stream.stopStream();
  await obs.disconnect();
  process.exit(0);
});
```

### Scene Transition with Animation

```typescript
// Smooth scene switching with transition
await obs.scenes.setSceneSceneTransitionOverride('My Scene', {
  transitionName: 'Fade',
  transitionDuration: 1000,
});
await obs.scenes.setCurrentProgramScene('My Scene');

// Or use global transition
await obs.transitions.setCurrentSceneTransition('Stinger');
await obs.transitions.setCurrentSceneTransitionDuration(500);
```

---

## Caveats & Limitations

1. **Bundle Size**: The dart2js runtime ships as a single ES module. Expect ~150-300 KB gzipped. Tree-shaking is limited since dart2js emits a self-contained runtime.

2. **Logging**: The underlying `loggy` package writes to `console.log`. Adjust `logLevel` in connection options to silence output.

3. **Browser Environment Variables**: `connectFromEnv()` is Node.js only. In browsers, always pass credentials explicitly to `connect()`.

4. **Node Version Support**: Tested on Node 18+. On Node 22+, native `globalThis.WebSocket` is used; on Node 18-21, the `ws` package is loaded dynamically.

5. **Auto-Reconnection**: Not yet implemented (planned for v6.0.0). Handle reconnection manually in production apps.

---

## Building from Source

```bash
# Install dependencies
npm install

# Build everything (dart2js + TypeScript)
npm run build

# Build only Dart to JS
npm run build:dart

# Build only TypeScript bundles
npm run build:ts

# Run tests
npm test

# Type checking
npm run typecheck

# Clean build artifacts
npm run clean
```

### Build Outputs

- `dist/browser.js` — Browser bundle (native WebSocket)
- `dist/node.js` — Node.js ESM bundle
- `dist/node.cjs` — Node.js CommonJS bundle
- `dist/*.d.ts` — TypeScript declaration files

**Requirements**: Dart SDK ^3.8.0 for `dart2js` compilation.

---

## Relation to the Dart Package

All protocol logic lives in [`packages/obs_websocket/`](../obs_websocket/). This package is a thin JS/TS shim over the exact same code:

```
obs_websocket (Dart SDK)
    ↓ shared protocol logic
obs_websocket_js (JS/TS bindings)
    ↓ compiled via dart2js
obs_mcp (MCP server for AI agents)
    ↓ uses same Dart SDK
obs_cli (CLI tool)
```

**Feature parity is guaranteed** — if a request exists in the Dart package, it works here via `obs.send(name, args)`, and the typed helpers in the sub-API classes cover commonly-used requests.

---

## Contributing

Contributions welcome! This package is part of the [`obs_websocket`](https://github.com/cdavis-code/obs_websocket_workspace) monorepo.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Run tests: `npm test`
5. Submit a pull request

For the Dart SDK changes, see the [main package](../obs_websocket/).

### Publishing to npm

This package uses GitHub Actions for automated npm publishing. When you push a tag with the format `obs_websocket_js-v*`, it will automatically build and publish to npm.

#### Using the Publish Script (Recommended)

```bash
# Bump patch version (5.7.0 -> 5.7.1)
./scripts/publish-npm.sh patch

# Bump minor version (5.7.0 -> 5.8.0)
./scripts/publish-npm.sh minor

# Bump major version (5.7.0 -> 6.0.0)
./scripts/publish-npm.sh major

# Set specific version
./scripts/publish-npm.sh 5.8.0
```

The script will:
1. Update the version in package.json
2. Build the package (dart2js + tsup)
3. Run tests
4. Create a git commit and tag
5. Provide instructions to push and trigger the GitHub Action

#### Manual Publishing

```bash
# Build and publish manually
npm run build
npm publish --access=public
```

#### GitHub Action Trigger

Push the tag to trigger automated publishing:

```bash
git push origin main --tags
```

The workflow will:
- ✅ Run all tests and type checks
- ✅ Build the package
- ✅ Publish to npm with public access
- ✅ Available at `https://www.npmjs.com/package/@unngh/obs-websocket`

**Note**: You need to set `NPM_TOKEN` as a GitHub secret for the workflow to authenticate with npm.

---

## License

MIT License — see [LICENSE](./LICENSE).

---

## Resources

- **[OBS WebSocket Protocol Documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md)**
- **[Dart SDK (obs_websocket)](https://pub.dev/packages/obs_websocket)**
- **[MCP Server (obs_mcp)](../obs_mcp)**
- **[CLI Tool (obs_cli)](../obs_cli)**
- **[GitHub Repository](https://github.com/cdavis-code/obs_websocket_workspace)**
