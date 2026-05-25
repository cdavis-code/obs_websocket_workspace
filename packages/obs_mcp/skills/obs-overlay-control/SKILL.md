---
name: obs-overlay-control
description: >
  Toggle visibility of OBS sources (overlays, webcams, lower thirds, BRB
  text, alerts) via the OBS MCP server. Use for short, imperative
  commands like "show my webcam", "hide the lower third", "bring up the
  BRB text", "turn off my camera", or "show the chat overlay". Encodes
  semantic-name → source-name mapping with a per-scene visibility cache.
---

# OBS Overlay & Source Visibility

Low-latency control for showing and hiding sources within the **current scene**. Operators often toggle overlays, cameras, and text rather than changing scenes — this skill specializes in that pattern.

**Core philosophy**: Map semantic names ("nameplate", "BRB", "chat") to actual source names, then flip `sceneItemEnabled`.

## When to Use

- "Show / hide my webcam"
- "Show / hide the lower third" (or "nameplate")
- "Bring up the BRB text" / "turn off the BRB"
- "Show / hide the chat overlay"
- "Turn off my camera" (visibility, not the device)
- "Hide the alert overlay"

**Do NOT use** for switching scenes (use `obs-fast-scene-switcher`) or for transforming source size/position (use `obs-camera-framing`).

## Available Tools

All invoked via `execute` with JavaScript `call_tool()`:

- `obs_scenes_get_current_program` — get the active scene name.
- `obs_scene_items_list` — list items in a scene with `sceneItemId`, `sourceName`, `sceneItemEnabled`.
- `obs_scene_items_get_id` — resolve `sceneItemId` from `(sceneName, sourceName)`.
- `obs_scene_items_get_enabled` — read current visibility.
- `obs_scene_items_set_enabled` — set visibility. **Primary action tool.**

## Shared State Reuse (latency-first)

If a session-wide `obsState` snapshot from `obs-get-state` already exists in memory, **skip discovery and read directly**:

- `obsState.currentProgramScene` → `sceneName`
- `obsState.sceneItemsByScene[currentProgramScene]` → `sceneItemId` and current `sceneItemEnabled` per overlay name

**Do NOT call `obs-get-state` proactively** — this skill's own per-scene cache is faster. Only invoke `obs-get-state` when:
- An overlay name the user just mentioned isn't in any cache.
- A toggle returned success but the user says nothing changed (likely scene-cache staleness).

## Source Name Cache (per scene)

On first overlay request:

```javascript
const sceneName = await call_tool('obs_scenes_get_current_program', {});
const items = await call_tool('obs_scene_items_list', { sceneName });
// Build cache: { sourceName -> { sceneItemId, sceneItemEnabled } }
```

Refresh the cache if the user switches scenes or says "I added an overlay".

## Semantic-Name Mapping

OBS source names vary by user. Build a fuzzy map from common phrases to real sources:

| User says | Match against source names containing |
|---|---|
| "webcam" / "my camera" / "cam" | "cam", "webcam", "camera" |
| "lower third" / "nameplate" | "lower third", "nameplate", "name" |
| "BRB" / "be right back" | "brb", "be right back" |
| "starting soon" | "starting soon", "intro" |
| "chat" / "chat overlay" | "chat" |
| "alert" / "alerts" | "alert" |
| "music" / "music overlay" | "music", "now playing" |

**Always lowercase both sides for matching, then call the tool with the exact cached name.**

If multiple matches exist, ask a one-line clarifying question.

## Command Mapping

| User says | Action |
|---|---|
| "Show my webcam" | `obs_scene_items_set_enabled` with `sceneItemEnabled: true` |
| "Hide the lower third" | `obs_scene_items_set_enabled` with `sceneItemEnabled: false` |
| "Toggle the chat overlay" | Read current state, flip it |
| "Bring up the BRB text" | Set enabled `true` |

## Latency-Conscious Behavior

1. **Build the cache once per scene.** Don't re-list items on every command.
2. **Use `sceneItemId` (int) when calling `set_enabled`** — it's required alongside `sceneName`.
3. **Confirm after the change**, not before.
4. **Don't toggle ambiguously.** If "show camera" matches two sources, ask which one.

## Example Interactions

### Example 1: Show webcam

**User**: "Show my webcam."

**Agent** (tool — first time, builds cache):
```javascript
const sceneName = await call_tool('obs_scenes_get_current_program', {});
const items = await call_tool('obs_scene_items_list', { sceneName });
const cam = items.find(i => /cam|webcam/i.test(i.sourceName));
await call_tool('obs_scene_items_set_enabled', {
  sceneName,
  sceneItemId: cam.sceneItemId,
  sceneItemEnabled: true,
});
```

**Agent** (chat): "Webcam shown."

### Example 2: Hide lower third (cached)

**User**: "Hide the lower third."

**Agent** (tool — uses cached items):
```javascript
await call_tool('obs_scene_items_set_enabled', {
  sceneName: 'main',
  sceneItemId: 7,
  sceneItemEnabled: false,
});
```

**Agent** (chat): "Lower third hidden."

### Example 3: Toggle

**User**: "Toggle the BRB text."

**Agent** (tool):
```javascript
const current = await call_tool('obs_scene_items_get_enabled', {
  sceneName: 'main',
  sceneItemId: 12,
});
await call_tool('obs_scene_items_set_enabled', {
  sceneName: 'main',
  sceneItemId: 12,
  sceneItemEnabled: !current.sceneItemEnabled,
});
```

**Agent** (chat): "BRB text toggled — now visible."

### Example 4: Ambiguous

**User**: "Hide the camera."

Cache contains "Webcam HD" and "Phone Cam".

**Agent** (chat): "I see 'Webcam HD' and 'Phone Cam'. Which one?"

## Error Handling

- **Source not found**: refresh the cache; the user may have renamed/added a source.
- **Wrong scene**: the source might exist in a different scene. Confirm the active scene first.
- **Multiple ambiguous matches**: ask a short clarifying question.

## Quick Reference

```javascript
// Get active scene
const sceneName = await call_tool('obs_scenes_get_current_program', {});

// List items (build cache)
const items = await call_tool('obs_scene_items_list', { sceneName });

// Show / hide
await call_tool('obs_scene_items_set_enabled', {
  sceneName,
  sceneItemId: 4,
  sceneItemEnabled: true, // or false
});

// Read state for toggle
const { sceneItemEnabled } = await call_tool('obs_scene_items_get_enabled', {
  sceneName, sceneItemId: 4,
});
```
