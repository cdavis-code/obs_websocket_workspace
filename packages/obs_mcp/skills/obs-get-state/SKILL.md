---
name: obs-get-state
description: >
  Bootstrap a structured OBS state snapshot — current/preview program scene,
  all scenes, scene items with their flat transforms, audio inputs,
  special-input slots, canvas dimensions, and studio-mode flag — in one
  batch so other obs-* skills can reuse it without redundant API calls. Use
  at the start of any OBS-control session, or whenever a stale cache is
  suspected (e.g., the user reports "no visible change", switches scenes
  mid-session, or mentions a scene/source name that doesn't match the
  cache).
---

# OBS Get State

Single-purpose discovery skill: capture the live OBS topology once, hand it to other skills as `obsState`.

**Core philosophy**: Every other obs-* skill (`obs-camera-framing`, `obs-overlay-control`, `obs-audio-control`, `obs-fast-scene-switcher`, `obs-transition-control`, …) needs the same bootstrap data. Capture once; reuse everywhere. Eliminates the most common bug class: cached `sceneName` no longer matches the program scene, so transforms succeed at the API level but produce zero visible effect.

## When to Use

- **Start of an OBS-control session**, before any other obs-* skill performs its first action.
- **User reports "no visible change"** after a tool call that returned success.
- **User mentions a scene/source name** that doesn't match the cache.
- **Studio mode toggled** (preview-vs-program separation changes).
- **Long pause between turns** — cheap insurance against the user switching scenes manually.

**Do NOT use** for mutations. This skill is strictly read-only. Reach for the appropriate domain skill (`obs-camera-framing`, `obs-overlay-control`, etc.) for any change.

**Do NOT invoke proactively for single-skill commands.** Each domain skill has a tighter Fast Path than this full bootstrap (typically 1–3 calls vs. 5–6 here). Only run `obs-get-state` when:
1. The agent is orchestrating multiple obs-* skills in one turn and would otherwise duplicate discovery.
2. The user's command spans multiple domains (e.g., "set up my stream" — scenes + audio + transitions).
3. A previous skill's discovery failed or returned stale data and a clean re-snapshot is the simplest recovery.
4. The user explicitly asks for a status report.

For latency-critical single-skill commands (zoom, mute, scene switch), let the domain skill do its own minimal first-use discovery; don't preemptively bootstrap.

## Available Tools

All invoked via `execute` with JavaScript `call_tool()`. Issue each as its own `execute`, **one at a time, sequentially** — do not chain awaits in a single script (the JS sandbox often errors on multi-step scripts), and do not fan out multiple `execute` tool calls in parallel from the agent (observed: 4 of 5 parallel calls return `"An error occurred while processing the request."` while the same calls issued serially all succeed).

- `obs_ui_studio_mode_enabled` → `boolean` (raw — no wrapper object)
- `obs_scenes_list` → `{ scenes: [{ sceneName, sceneIndex, sceneUuid }], currentProgramSceneName, currentPreviewSceneName }`
- `obs_scenes_get_current_program` → `{ currentProgramSceneName }` (cheap re-verify path)
- `obs_scenes_get_current_preview` → `{ currentPreviewSceneName }` (only meaningful when studio mode is on)
- `obs_scene_items_list` → array of `{ sourceName, sceneItemId, inputKind, sceneItemEnabled, sceneItemTransform: { positionX, positionY, scaleX, scaleY, rotation, alignment, sourceWidth, sourceHeight, width, height, … }, … }`
- `obs_video_settings` → `{ baseWidth, baseHeight, outputWidth, outputHeight, fpsNumerator, fpsDenominator }` — **preferred canvas-dimensions source; works on every OBS WebSocket v5+ build**
- `obs_canvases_list` → list of canvases (v5.7.0+; **errors on older builds — wrap in try/catch and use canvas-dimensions fallback below**). Only call this when you specifically need the multi-canvas list shape.
- `obs_inputs_list` → all named inputs (with `inputKind`)
- `obs_inputs_special` → `{ desktop1, desktop2, mic1, mic2, mic3, mic4 }` (any slot may be `null`)

**Tool-name pitfalls (real names confirmed against the live MCP server):** the discovery tools are `obs_ui_studio_mode_enabled` (NOT `obs_studio_mode_get_enabled`), `obs_inputs_special` (NOT `obs_inputs_get_special`), and `obs_canvases_list` (NOT `obs_canvas_get_video_settings`). The wrong names error with "An error occurred while processing the request."

## Capture Workflow

Run these calls in order. Merge results into a single `obsState` object cached for the rest of the session.

```javascript
// 1. Studio-mode flag (returns raw boolean)
const studioModeEnabled = await call_tool('obs_ui_studio_mode_enabled', {});

// 2. Scenes (list + current program + current preview)
const scenesResp = await call_tool('obs_scenes_list', {});

// 3. Canvas dimensions (preferred path — legacy GetVideoSettings, works on every v5+ build)
let canvas = null;
try {
  canvas = await call_tool('obs_video_settings', {});
} catch (_) {
  // Fall back to v5.7.0+ canvases_list only if video_settings is unexpectedly unavailable
  try { canvas = await call_tool('obs_canvases_list', {}); } catch (_) {}
}

// 4. Audio: special slots + named inputs
const special = await call_tool('obs_inputs_special', {});
const inputs  = await call_tool('obs_inputs_list', {});

// 5. Scene items for the program scene only (lazy-load others on demand)
const programItems = await call_tool('obs_scene_items_list', {
  sceneName: scenesResp.currentProgramSceneName,
});
```

For multi-scene workflows (corner-tour, transitions, fast-switching), list items for each scene the agent expects to operate on. Do **not** eagerly list every scene — `obs_scene_items_list` is per-scene and the responses can be large.

## State Schema

Build and cache this object exactly:

```javascript
const obsState = {
  capturedAt: new Date().toISOString(),
  studioModeEnabled,                               // raw boolean from obs_ui_studio_mode_enabled
  currentProgramScene: scenesResp.currentProgramSceneName,
  currentPreviewScene: scenesResp.currentPreviewSceneName ?? null,
  scenes: scenesResp.scenes,                       // [{ sceneName, sceneIndex, sceneUuid }]
  canvas: canvas
    ? canvas                                       // { baseWidth, baseHeight, outputWidth, outputHeight, fpsNumerator, fpsDenominator } from obs_video_settings, OR raw obs_canvases_list payload as fallback
    : null,                                        // null → fall back to inferred dims (see below)
  audio: {
    special,                                       // { mic1, desktop1, ... }
    inputs,                                        // full list with inputKind
  },
  sceneItemsByScene: {
    [scenesResp.currentProgramSceneName]: programItems,
    // populate other scenes lazily as needed
  },
};
```

## Consumer Mapping

Tells downstream skills which fields they should read instead of issuing their own discovery calls.

| Skill | Reads from `obsState` |
|---|---|
| `obs-camera-framing` | `currentProgramScene`, `sceneItemsByScene[currentProgramScene]` (sceneItemId, full `sceneItemTransform` including `alignment`, `sourceWidth/Height`), `canvas.baseWidth`/`canvas.baseHeight` from `obs_video_settings` (or fallback when `canvas` is `null`) |
| `obs-overlay-control` | `sceneItemsByScene[…]` (`sceneItemId`, `sceneItemEnabled`) |
| `obs-audio-control` | `audio.special` (mic/desktop slots), `audio.inputs` (named inputs by `inputKind`) |
| `obs-fast-scene-switcher` | `scenes`, `currentProgramScene`, `currentPreviewScene`, `studioModeEnabled` |
| `obs-transition-control` | `studioModeEnabled`, `currentProgramScene`, `currentPreviewScene` |
| `obs-transport-control` | (no scene/source state needed) |
| `obs-replay-clips`, `obs-timed-recording` | (no scene/source state needed) |

## Invalidation Rules

`obsState` is **stale** (re-capture or partial refresh required) when any of these is true:

1. The agent called a scene-switch tool (`obs_scenes_set_current_program_scene`, `set_current_preview_scene`).
2. The user mentions a scene/source name not present in `obsState.scenes` or any cached `sceneItemsByScene`.
3. The user reports "no visible change" after a successful API call.
4. Studio mode is toggled.
5. Source list mutated (`obs_inputs_create`, scene-item create/remove — rare).
6. Pause longer than the user's typical manual scene-rotation interval.

**Cheap refresh path**: re-run only `obs_scenes_get_current_program` first. If the result differs from `obsState.currentProgramScene`, do a full re-bootstrap or at minimum refresh `sceneItemsByScene[<new program scene>]` and update `currentProgramScene`.

## Canvas-Dimensions Fallback

The preferred canvas-dimensions source is `obs_video_settings` (legacy `GetVideoSettings`, available since OBS WebSocket v5.0). It returns a flat `{ baseWidth, baseHeight, outputWidth, outputHeight, fpsNumerator, fpsDenominator }` object on every supported build. Read `obsState.canvas.baseWidth` / `obsState.canvas.baseHeight` directly when the bootstrap captured this payload.

If `obs_video_settings` is unavailable (very old WebSocket plugin), the bootstrap falls back to `obs_canvases_list` (v5.7.0+). That payload is an opaque list of canvas records with a different shape — treat it as opaque metadata and rely on the inference paths below.

If both fail and `obsState.canvas` is `null`:

1. Look at any cached scene item in `sceneItemsByScene[*]` whose `sceneItemTransform` has `scaleX === 1 && scaleY === 1 && alignment === 5` (top-left, native scale): its `width`/`height` equals canvas `baseWidth`/`baseHeight`.
2. If no such item exists, pick any visible item and compute `canvasWidth ≈ width / scaleX`, `canvasHeight ≈ height / scaleY` — accurate when the item isn't cropped.
3. As a last resort, assume **1920×1080** (the common default).

Downstream skills should encapsulate this fallback (already done in `obs-camera-framing`).

## Critical Rules

1. **Never assume a cached scene is still current.** Re-verify whenever the user's wording is ambiguous or invisible-edit symptoms appear.
2. **Capture is read-only.** This skill never calls a `set_*` or `*_set_*` tool.
3. **One `call_tool` per `execute`, issued sequentially.** Multi-step JS scripts often error in the sandbox, and parallel `execute` tool calls from the agent overwhelm the MCP server (4-of-5 failure rate observed). Always serialize.
4. **Capture the full `sceneItemTransform`**, not just `sceneItemId`. Downstream skills need `alignment`, `sourceWidth/Height`, `scaleX/Y`, `positionX/Y` to compute centered-zoom math correctly (see `obs-camera-framing`).
5. **Treat `canvas: null` as a soft signal**, not an error. Use the fallback paths above. When `canvas` is non-`null`, prefer reading flat fields (`canvas.baseWidth`, `canvas.baseHeight`) as returned by `obs_video_settings`; the `obs_canvases_list` fallback returns a different, opaque shape.
6. **Verify tool names against the live MCP `search` tool before calling.** This MCP server's tool names drift between OBS versions; use the wrong name and every call returns the same generic error string. The names listed in this SKILL.md were confirmed against a live server but may need re-verification on a different OBS build.

## Re-Use Safety (re-running this skill mid-session)

Re-running `obs-get-state` is **safe** for every other obs-* skill. The skill makes only read-only WebSocket requests and writes nothing back to OBS. Concretely:

- **No state mutation in OBS.** Re-bootstrap cannot disrupt an in-progress stream, transition, or transform.
- **`obsState` is regenerated, not merged.** A new bootstrap replaces the previous `obsState` reference. Domain skills that already cached individual fields (e.g., `obs-camera-framing` caching `sceneItemId` for the current program scene) may keep using their local cache — `sceneItemId` is stable for the lifetime of a scene item, so a fresh snapshot won't invalidate it.
- **Lazy `sceneItemsByScene` is preserved-by-design.** The bootstrap only fetches items for `currentProgramSceneName`. Other scenes are populated lazily as domain skills request them. Re-running the bootstrap drops those lazy entries; that's intentional — they're cheap to re-fetch and possibly stale.
- **No race with concurrent skills.** OBS WebSocket requests are serialized server-side. A domain skill's `set_transform` issued just before/after a re-bootstrap will not be reordered or lost.
- **Studio-mode flips and scene switches between snapshots are reflected immediately.** That's the whole point of re-running.

What domain skills must do to consume a refreshed `obsState` without surprise:

1. Always read `obsState.currentProgramScene` afresh at the start of every action — never cache it across turns.
2. Re-resolve `sceneItemId` from `obsState.sceneItemsByScene[<currentProgramScene>]` rather than a long-lived local variable; if the scene was switched and the new program scene's items aren't yet in `sceneItemsByScene`, lazy-fetch via `obs_scene_items_list`.
3. Treat their own caches of `obsState` field values as advisory — re-read on every entry rather than mirroring into a long-lived local.

In short: the bootstrap is idempotent and side-effect-free. Re-run it whenever the invalidation rules above fire; downstream skills will pick up the fresh state on their next read.

## Example

**User**: "I'm about to start streaming — get ready."

**Agent** (5 small `execute` calls; 6th is per-scene-of-interest):

```javascript
// 1
await call_tool('obs_ui_studio_mode_enabled', {});
// 2
await call_tool('obs_scenes_list', {});
// 3 — preferred (works on every v5+ build); fall back to obs_canvases_list only if this errors
await call_tool('obs_video_settings', {});
// 4
await call_tool('obs_inputs_special', {});
// 5
await call_tool('obs_inputs_list', {});
// 6 — uses currentProgramSceneName from #2's response
await call_tool('obs_scene_items_list', { sceneName: '<currentProgramSceneName>' });
```

**Agent** (chat): "Snapshot ready: program scene `camera`, 1 source (`Video Capture Device`, 1920×1080, alignment 5, scaleX/Y 1.0), studio mode off, mic1=`Mic/Aux`. Other obs-* skills can read state from `obsState` for the rest of this session."

## Quick Reference

```javascript
// Bootstrap (first time)
const studioModeEnabled = await call_tool('obs_ui_studio_mode_enabled', {});
const scenesResp        = await call_tool('obs_scenes_list', {});
let canvas              = await call_tool('obs_video_settings', {}).catch(() => null);
if (canvas === null) {
  canvas = await call_tool('obs_canvases_list', {}).catch(() => null);
}
const special           = await call_tool('obs_inputs_special', {});
const inputs            = await call_tool('obs_inputs_list', {});
const programItems      = await call_tool('obs_scene_items_list', {
  sceneName: scenesResp.currentProgramSceneName,
});

// Cheap re-verify (when a stale cache is suspected)
const fresh = await call_tool('obs_scenes_get_current_program', {});
if (fresh.currentProgramSceneName !== obsState.currentProgramScene) {
  // re-bootstrap, or refresh sceneItemsByScene[fresh.currentProgramSceneName]
}
```
