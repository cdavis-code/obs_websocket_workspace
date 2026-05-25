---
name: obs-camera-framing
description: >
  Apply preset transforms (wide, close-up, corner placements, zoomed) to a visual source in OBS via the OBS MCP server. Use for short, imperative commands like "zoom in on me", "move my camera top-right", "go wide", "reset camera framing", or "put my cam bottom-left". Encodes named transform presets and uses server-side animation for smooth moves.
---

# OBS Camera Framing

Animate any single visual scene item — camera, image, browser, media, text, etc. — between named framing presets (wide / close-up / corner placements) within the current scene.

**Core philosophy**: Operators want a few well-tuned presets, not arbitrary transform math at the speed of chat. The transforms are source-agnostic — every scene item exposes the same `positionX/Y`, `scaleX/Y`, `rotation`, and `alignment` fields, so this skill works on any visual element on the canvas.

## When to Use

- "Zoom in on me" / "close-up" / "zoom in on the image" / "zoom in on the browser source"
- "Go wide" / "back to wide" / "reset framing"
- "Move my camera top-right" / "corner-tour" / "park the logo bottom-left"
- "Put my cam bottom-left" / "shrink the overlay into the corner"
- "Reset framing" (works on whichever source was last targeted)

Targets are **any visual scene item**: camera (video capture), image, browser, media, text/GDI+, color, group, etc. The transform fields are identical for all of them.

**Do NOT use** for visibility toggles (use `obs-overlay-control`), scene switching (use `obs-fast-scene-switcher`), or full source automation (use the general `obs-mcp` skill).

## Available Tools

All invoked via `execute` with JavaScript `call_tool()`:

- `obs_canvas_get_video_settings` — `{ baseWidth, baseHeight, ... }`. Use for canvas dimensions.
- `obs_scenes_get_current_program` — current scene name.
- `obs_scene_items_list` — list items + their transforms.
- `obs_scene_items_get_id` — resolve `sceneItemId` from a source name.
- `obs_scene_items_get_transform` — read flat transform (`positionX`, `positionY`, `scaleX`, `scaleY`, `rotation`, `width`, `height`, `alignment`, ...).
- `obs_scene_items_set_transform` — set transform fields (immediate). **Preferred for zoom/move operations** because the change persists.
- `obs_scene_items_animate_transform` — server-side easing animation. **WARNING**: on current OBS builds it reports `ok: true` and plays the visual transition, but the final transform is **not persisted** — reading back via `obs_scene_items_get_transform` shows the original values. Avoid for "stick the zoom" operations until this is resolved upstream.

## Shared State Reuse (latency-first)

If a session-wide `obsState` snapshot from `obs-get-state` already exists in memory, **read it instead of calling discovery tools** — every field this skill needs is already there:

- `obsState.currentProgramScene` → `sceneName`
- `obsState.sceneItemsByScene[currentProgramScene]` → `sceneItemId`, `sceneItemTransform.alignment`, `sourceWidth/Height`, baseline `scaleX/Y` and `positionX/Y`
- `obsState.canvas.baseWidth/baseHeight` → preset position math (fallback: 1920×1080)

**Do NOT call `obs-get-state` proactively** to acquire that snapshot — the Fast Path below (≤3 calls on first use, 1 call thereafter) is faster than `obs-get-state`'s full bootstrap. Only invoke `obs-get-state` when:
- The user reports "no visible change" twice in a row (likely scene-cache staleness).
- The cached `currentProgramScene` no longer matches an `obs_scenes_get_current_program` re-verify.
- A multi-skill turn already needs the full bootstrap.

## OBS Alignment Values

`alignment` is a bitmask controlling which point on the source sits at `(positionX, positionY)`. Misreading it is the #1 cause of "transform looks wrong".

| Value | Bits | Anchor point |
|------:|------|--------------|
| 0     | (none)        | **center** (default for new sources) |
| 1     | left          | center-left edge |
| 2     | right         | center-right edge |
| 4     | top           | top-center edge |
| 5     | top \| left   | **top-left corner** |
| 6     | top \| right  | top-right corner |
| 8     | bottom        | bottom-center edge |
| 9     | bottom \| left  | bottom-left corner |
| 10    | bottom \| right | bottom-right corner |

Practical rules:
- `alignment: 0` (center): `(positionX, positionY)` is the **center** of the source. To center on a 1920×1080 canvas: `positionX: 960, positionY: 540`.
- `alignment: 5` (top-left): `(positionX, positionY)` is the **top-left corner**. To fill the canvas: `positionX: 0, positionY: 0`.
- Always read `alignment` from `obs_scene_items_list` before computing positions — never assume.

## Fast Path (Minimal Steps)

For the common "zoom in" / "zoom out" use case, the agent should perform **at most 3 tool calls** on first use, and **1 tool call** on subsequent uses.

### First use in session (3 calls max):

```javascript
// Call 1: Get the current scene name
await call_tool('obs_scenes_get_current_program', {});
// → { currentProgramSceneName: 'image' }

// Call 2: List items to find the target source + cache its sceneItemId, alignment, baseline transform
await call_tool('obs_scene_items_list', { sceneName: 'image' });
// → [{ sourceName: 'Image', sceneItemId: 1, sceneItemTransform: { scaleX: 0.617, alignment: 5, ... } }]

// Call 3: Set the new scale directly (persists). Use set_transform — NOT animate_transform.
// IMPORTANT: if alignment is 5 (top-left), also adjust positionX/Y so the zoom stays centered.
// See "Centered Zoom Math" below for the formula.
await call_tool('obs_scene_items_set_transform', {
  sceneName: 'image',
  sceneItemId: 1,
  scaleX: 0.9,
  scaleY: 0.9,
  // For alignment-5 sources, include compensating positionX/Y here (see Centered Zoom Math).
});
// → returns the new transform; reading back confirms scaleX/Y persisted.
```

### Subsequent commands (1 call):

Once `sceneName`, `sceneItemId`, and the baseline transform are cached, every later zoom/move is a **single** `obs_scene_items_set_transform` call. Do **not** re-call `obs_scenes_get_current_program` or `obs_scene_items_list` unless the user changes scenes or sources.

> **Cache-staleness guard**: if the user could have switched scenes between turns (e.g., long pause, user mentions a different source name, or transforms appear to have no visible effect), re-call `obs_scenes_get_current_program` first. A cached `sceneName` that no longer matches the program scene means every transform you send goes to an off-screen scene and looks like a no-op. Cost: 1 extra call. Benefit: avoids invisible-edit bugs.

```javascript
// Working zoom — verified to persist
await call_tool('obs_scene_items_set_transform', {
  sceneName: 'camera',
  sceneItemId: 1,
  scaleX: 1.5,
  scaleY: 1.5,
});
// → { positionX: 0, positionY: 0, scaleX: 1.5, scaleY: 1.5, ..., width: 2880, height: 1620 }
```

### Critical optimizations from real-world execution:

1. **Use `obs_scene_items_set_transform` for zoom, not `animate_transform`.** `animate_transform` returns `ok: true` and plays the visual transition, but does not persist the final scale on current OBS builds — reading back the transform shows the original values. Use `set_transform` for any change you want to stick.
2. **Do NOT combine multiple `await call_tool()` calls in a single `execute` invocation.** The JS sandbox often errors on multi-step scripts. Issue each tool call as its own `execute`.
3. **Skip `obs_scene_items_get_id` and `obs_scene_items_get_transform`** — the data you need (`sceneItemId`, `alignment`, current transform) is already in the `obs_scene_items_list` response under `sceneItemTransform`.
4. **Skip `obs_canvas_get_video_settings`** unless you need precise canvas-relative positioning. For simple zoom-in/zoom-out, `scaleX/Y` alone is enough.
5. **Pick a sensible default zoom factor** (e.g. `1.5×` current scale) instead of always asking the user.
6. **Zoom must stay centered** — see "Centered Zoom Math" below. Scaling alone (without adjusting `positionX/Y`) makes the source grow from its anchor corner, which looks like a zoom toward the bottom-right.
7. **Re-verify the program scene whenever the user reports "no visible change"** or whenever they mention a source/scene name that doesn't match your cache. Operating on a non-program scene silently succeeds at the API level but produces zero visible effect on the canvas — the most common cause of "nothing happened" reports.

## Centered Zoom Math

A scale change alone pivots the source from its `alignment` anchor:

- `alignment: 5` (top-left): the **top-left corner stays fixed**; the source grows toward the bottom-right. Visually feels like "zooming away from the user".
- `alignment: 0` (center): the **center stays fixed**; the source grows symmetrically. This is the visual the user expects from "zoom in".

For sources with `alignment: 5` (the OBS default for many sources, including the verified "me" source), you must adjust `positionX/Y` whenever you change the scale, otherwise the visual center drifts.

### Formula (for any alignment)

Given the **baseline** transform captured from `obs_scene_items_list` (call it `B`):

```javascript
// Pre-compute baseline visual center (do this once, cache it)
const baselineCenterX = B.positionX + B.scaleX * B.sourceWidth / 2
                        + (B.alignment === 5 ? 0 : B.scaleX * B.sourceWidth / 2 * 0); // top-left anchor case
const baselineCenterY = B.positionY + B.scaleY * B.sourceHeight / 2
                        + (B.alignment === 5 ? 0 : 0);

// Simpler — for the two common cases:
//   alignment 5 (top-left): centerX = positionX + scaleX*sourceWidth/2
//                           centerY = positionY + scaleY*sourceHeight/2
//   alignment 0 (center):   centerX = positionX
//                           centerY = positionY
```

To zoom to a new `scale` while keeping the visual center fixed:

```javascript
// alignment 5 (top-left anchor) — adjust position to compensate
const newPositionX = baselineCenterX - newScale * B.sourceWidth / 2;
const newPositionY = baselineCenterY - newScale * B.sourceHeight / 2;

await call_tool('obs_scene_items_set_transform', {
  sceneName, sceneItemId,
  scaleX: newScale, scaleY: newScale,
  positionX: newPositionX,
  positionY: newPositionY,
});

// alignment 0 (center anchor) — no position math needed; scale alone is centered
await call_tool('obs_scene_items_set_transform', {
  sceneName, sceneItemId, scaleX: newScale, scaleY: newScale,
});
```

### Worked example (verified)

Baseline for source "me" in scene "image": `scaleX=0.4678, positionX=0, positionY=113, sourceWidth=4096, sourceHeight=1864, alignment=5`.

```
baselineCenterX = 0   + 0.4678 * 4096 / 2 ≈ 958
baselineCenterY = 113 + 0.4678 * 1864 / 2 ≈ 549

For newScale = 0.7:
  newPositionX = 958 - 0.7 * 4096 / 2 = 958 - 1433 = -475
  newPositionY = 549 - 0.7 * 1864 / 2 = 549 -  652 = -103
```

Result: `set_transform { scaleX: 0.7, scaleY: 0.7, positionX: -475, positionY: -103 }` — verified visually centered.

## Required: Snapshot the "wide" baseline

The user's "wide" or default framing is whatever the source looks like before this skill runs. Snapshot it on first use so you can `reset` later. This applies to any visual source, not just cameras:

```javascript
const sceneName = await call_tool('obs_scenes_get_current_program', {});
const sceneItemId = (await call_tool('obs_scene_items_get_id', {
  sceneName, sourceName: targetSourceName, // camera, image, browser, etc.
})).sceneItemId;
const baseline = await call_tool('obs_scene_items_get_transform', {
  sceneName, sceneItemId,
});
// Cache `baseline` for "reset" command
```

## Preset Library

Define presets relative to the canvas dimensions. Read them once, cache them.

```javascript
const { baseWidth, baseHeight } = await call_tool('obs_canvas_get_video_settings', {});

// Position math depends on the source's `alignment` (see "OBS Alignment Values" above).
// alignment 0 = center anchor → positionX/Y is the source's center.
// alignment 5 = top-left anchor → positionX/Y is the source's top-left corner.
// The presets below assume alignment 0 (center). For alignment 5, subtract scaledWidth/2 and scaledHeight/2.

const presets = {
  wide:        baseline,                                    // restore original
  closeup:     { positionX: baseWidth/2, positionY: baseHeight/2, scaleX: 1.5, scaleY: 1.5 },
  topLeft:     { positionX: baseWidth*0.20, positionY: baseHeight*0.20, scaleX: 0.5, scaleY: 0.5 },
  topRight:    { positionX: baseWidth*0.80, positionY: baseHeight*0.20, scaleX: 0.5, scaleY: 0.5 },
  bottomLeft:  { positionX: baseWidth*0.20, positionY: baseHeight*0.80, scaleX: 0.5, scaleY: 0.5 },
  bottomRight: { positionX: baseWidth*0.80, positionY: baseHeight*0.80, scaleX: 0.5, scaleY: 0.5 },
};
```

Tune these once with the user; they become the skill's vocabulary.

## Command Mapping

| User says | Preset |
|---|---|
| "Zoom in on me" / "close-up" | `closeup` |
| "Go wide" / "wide shot" / "reset framing" | `wide` (= baseline) |
| "Move my cam top-left" | `topLeft` |
| "Put my cam top-right" | `topRight` |
| "Bottom-left" / "bottom-right" | corresponding preset |
| "Smooth zoom" | animate to `closeup` with `easeInOut` |

## Critical Rules

1. **Always snapshot the baseline first.** Without it, "reset" or "go wide" can't restore exactly.
2. **Read the source's `alignment` before computing positions.** `alignment: 0` = center anchor; `alignment: 5` = top-left anchor. See the "OBS Alignment Values" table above. The math differs.
3. **Use `set_transform` for changes that must stick.** `animate_transform` does not persist the final transform on current OBS builds — the visual animation plays, but the post-animation state reads back as the original values.
4. **One source at a time.** This skill targets one scene item per command; it does not coordinate multi-source choreography.

## Latency-Conscious Behavior

- **Default to `obs_scene_items_set_transform`** for zoom and move commands. It is instant *and* it persists.
- `obs_scene_items_animate_transform` is currently unreliable for "stick the result" use cases — only consider it for transient visual flourishes where reverting is acceptable.
- Never re-list scene items on every command — cache `sceneItemId` per source (camera, image, browser, etc.).

## Example Interactions

### Example 1: Centered zoom in (verified working)

**User**: "Zoom in on me."

Source baseline (from `obs_scene_items_list`): `me` / `sceneItemId: 1` / `scaleX: 0.4678, positionX: 0, positionY: 113, sourceWidth: 4096, sourceHeight: 1864, alignment: 5`.

**Agent** (compute centered position, then `set_transform`):
```javascript
// baseline center (cached once)
const cx = 0   + 0.4678 * 4096 / 2; // ≈ 958
const cy = 113 + 0.4678 * 1864 / 2; // ≈ 549

const newScale = 0.7; // ~1.5× zoom from baseline
await call_tool('obs_scene_items_set_transform', {
  sceneName: 'image',
  sceneItemId: 1,
  scaleX: newScale,
  scaleY: newScale,
  positionX: cx - newScale * 4096 / 2, // -475
  positionY: cy - newScale * 1864 / 2, // -103
});
// → { positionX: -475, positionY: -103, scaleX: 0.7, scaleY: 0.7, ..., width: 2867, height: 1305 }
```

**Agent** (chat): "Zoomed in (centered)."

> Note: do NOT use `animate_transform` here — it returns `ok: true` but the final scale will silently revert.
> Note: scaling without adjusting `positionX/Y` on an `alignment: 5` source visually zooms toward the bottom-right corner.

### Example 2: Move corner (instant)

**User**: "Put my cam bottom-right."

**Agent** (tool):
```javascript
await call_tool('obs_scene_items_set_transform', {
  sceneName: 'main',
  sceneItemId: 4,
  positionX: 1920*0.80,
  positionY: 1080*0.80,
  scaleX: 0.5,
  scaleY: 0.5,
});
```

**Agent** (chat): "Camera moved to bottom-right."

### Example 3: Reset framing

**User**: "Reset camera framing."

**Agent** (tool — animate back to baseline):
```javascript
await call_tool('obs_scene_items_animate_transform', {
  sceneName: 'main',
  sceneItemId: 4,
  durationMs: 500,
  easing: 'easeInOut',
  targetPositionX: baseline.positionX,
  targetPositionY: baseline.positionY,
  targetScaleX: baseline.scaleX,
  targetScaleY: baseline.scaleY,
  targetRotation: baseline.rotation,
});
```

**Agent** (chat): "Camera framing reset to wide."

### Example 4: Corner tour

**User**: "Do a corner tour with my camera."

**Agent** (tool — server-side animate is best for sequences):
```javascript
const corners = [
  { positionX: 1920*0.20, positionY: 1080*0.20 },
  { positionX: 1920*0.80, positionY: 1080*0.20 },
  { positionX: 1920*0.80, positionY: 1080*0.80 },
  { positionX: 1920*0.20, positionY: 1080*0.80 },
];
for (const c of corners) {
  await call_tool('obs_scene_items_animate_transform', {
    sceneName: 'main',
    sceneItemId: 4,
    durationMs: 800,
    easing: 'easeOutBounce',
    targetPositionX: c.positionX,
    targetPositionY: c.positionY,
    targetScaleX: 0.5,
    targetScaleY: 0.5,
  });
}
```

**Agent** (chat): "Corner tour complete."

## Error Handling

- **`Source not found in scene`**: cache is stale. Refresh `obs_scene_items_list`.
- **Transform looks wrong**: alignment is probably the culprit. Re-check whether the source uses `alignment: 0` (center anchor — `positionX/Y` is the center) or `alignment: 5` (top-left anchor — `positionX/Y` is the top-left corner) and adjust the math. See the "OBS Alignment Values" table.
- **Animation never ends**: server-side animations are bounded by `durationMs`; if the user reports an issue, check OBS logs.

## Quick Reference

```javascript
// Snapshot baseline (do once) — pulled directly from obs_scene_items_list
// const baseline = sceneItem.sceneItemTransform;

// Zoom / move (preferred — persists)
await call_tool('obs_scene_items_set_transform', {
  sceneName, sceneItemId, scaleX, scaleY, // + positionX/Y, rotation as needed
});

// Smooth visual transition (CAUTION: does not persist final state)
await call_tool('obs_scene_items_animate_transform', {
  sceneName, sceneItemId,
  durationMs: 500, easing: 'easeInOut',
  targetPositionX, targetPositionY, targetScaleX, targetScaleY,
});
```
