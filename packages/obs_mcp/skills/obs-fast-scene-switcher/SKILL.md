---
name: obs-fast-scene-switcher
description: >
  Optimize OBS scene switching using the OBS MCP server. 
  Use for short, imperative commands like "switch to product placement scene", 
  "go to intro scene", "show main camera", or "switch back to gameplay". 
  Encodes a cached scene map workflow for low-latency scene changes. 
  Prefer direct tool calls over long reasoning.
---

# OBS Fast Scene Switcher

Low-latency scene switching workflow for the OBS MCP server.

**Core philosophy**: Treat this as a low-latency control panel, not a general automation brain.

## When to Use

- User issues short, imperative commands about changing views: "switch to X", "go to X", "show X", "use X scene", "switch back to main"
- Examples: "switch to product placement scene", "go to camera-only", "switch back to main", "show intro"

**Do NOT use** for complex OBS automation (layout changes, source configuration, creating new scenes) — use the general `obs-mcp` skill for those.

## Available Tools

All invoked via `execute` with JavaScript `call_tool()`:

- `obs_scenes_list` — list all scenes with names/ids and current program/preview. Use to build scene cache.
- `obs_scenes_get_current_program` — get current program scene name. Optional, for context.
- `obs_scenes_set_current_program` — switch to a scene by name. **Primary action tool.**

## Shared State Reuse (latency-first)

If a session-wide `obsState` snapshot from `obs-get-state` already exists in memory, **skip the first-use list and read directly**:

- `obsState.scenes` → name list for fuzzy matching
- `obsState.currentProgramScene` → live program scene
- `obsState.currentPreviewScene` → live preview scene (when `obsState.studioModeEnabled`)
- `obsState.studioModeEnabled` → routing decision (program vs preview)

**Do NOT call `obs-get-state` proactively** — `obs_scenes_list` alone is the leanest first-use call here. Only fall back to `obs-get-state` if a scene the user named isn't in any cached list and a refresh of `scenes` doesn't help.

After every successful switch, **update `obsState.currentProgramScene` (or `currentPreviewScene`)** so downstream skills don't re-fetch.

## Scene Cache Workflow

### First scene-related request in session:

```javascript
// 1. List scenes once
const scenes = await call_tool('obs_scenes_list', {});
// 2. Build mental map: scene names (lowercased, normalized) → exact name
// scenes.scenes is the array, scenes.currentProgramSceneName is current
// 3. Optionally note current scene
const current = scenes.currentProgramSceneName;
```

### Subsequent commands:

- **Reuse the cached scene list** from memory — do NOT call `obs_scenes_list` again
- Only refresh cache if user explicitly says scenes changed ("I added a new scene")

This prevents burning latency on every switch.

## Command Handling Rules

### Recognize these patterns as direct switch commands:

- "switch to X", "go to X", "show X", "use X scene", "switch back to X"
- "go back to main", "show product placement", "switch to gameplay view"

### Fuzzy matching algorithm:

1. Lowercase and trim the user's input **for matching purposes only**
2. Strip trailing word "scene" or "view" if present
3. Match against cached scene names (case-insensitive comparison)
4. Prefer exact or near-exact matches
5. **CRITICAL**: Once you find a match, use the **exact scene name** from the cache (preserving its original case) when calling `obs_scenes_set_current_program`

**Important**: OBS scene names are **case-sensitive**. Never alter the case of a scene name when passing it to OBS tools. Only use case-insensitive matching for the fuzzy search step — the actual tool call must use the exact case as returned by `obs_scenes_list`.

**Examples**:
- "product placement scene" → matches "product placement" or "Product_Placement" → call with exact cached name
- "main camera" → matches "main" or "Main Camera" → call with exact cached name
- "gameplay view" → matches "gameplay" or "Gameplay View" → call with exact cached name
- "image" → matches "image" → call with exact cached name "image" (not "Image")

### Conflict resolution:

If multiple close matches exist (e.g., "Gameplay" and "Gameplay – No Cam"):
- Ask a **very short clarifying question**: "Did you mean 'Gameplay' or 'Gameplay – No Cam'?"
- After clarification, call `obs_scenes_set_current_program` immediately

If no good match found:
- Ask: "I don't see a scene matching 'X'. Available scenes are: [list 3-5 closest]"
- Wait for user clarification

## Latency-Conscious Behavior

**Critical rules for low-latency operation**:

1. **Keep chain-of-thought short.** For clear commands, call the tool in your first response, then optionally confirm.
2. **Prioritize tool calls over verbose reasoning.** When confident about the scene name, call `obs_scenes_set_current_program` **without asking for confirmation**.
3. **Confirm after the switch**, not before: "Switched to Product Placement scene."
4. **Avoid exploratory tool use.** Do not list scenes repeatedly if you already know them.
5. **Do not ask "should I switch to X?"** — just switch, then confirm.

## Example Interactions

### Example 1: Clear command (first use)

**User**: "Switch to product placement scene."

**Agent** (tool call):
```javascript
const scenes = await call_tool('obs_scenes_list', {});
// Build cache: ["Product Placement", "Main", "Gameplay", ...]
await call_tool('obs_scenes_set_current_program', {
  sceneName: 'Product Placement'
});
```

**Agent** (chat): "Switched to Product Placement scene."

### Example 2: Cached switch (subsequent)

**User**: "Go back to main."

**Agent** (tool call — no need to list scenes again):
```javascript
await call_tool('obs_scenes_set_current_program', {
  sceneName: 'main'
});
```

**Agent** (chat): "Switched to main scene."

### Example 3: Ambiguous match

**User**: "Switch to gameplay view."

**Agent** (checks cache, finds "Gameplay" and "Gameplay – No Cam"):
**Agent** (chat): "I found 'Gameplay' and 'Gameplay – No Cam'. Which one?"

**User**: "The one without camera."

**Agent** (tool call):
```javascript
await call_tool('obs_scenes_set_current_program', {
  sceneName: 'Gameplay – No Cam'
});
```

**Agent** (chat): "Switched to Gameplay – No Cam."

### Example 4: No match

**User**: "Show the tutorial scene."

**Agent** (checks cache, no match for "tutorial"):
**Agent** (chat): "I don't see a 'tutorial' scene. Closest matches: 'Starting Soon', 'BRB Screen'. Did you mean one of these, or should I list all available scenes?"

## Studio Mode Awareness

If studio mode is enabled, the user might want to switch **preview** instead of program:

- If user says "preview X", "cue X", or "set up X": use `obs_scenes_set_current_preview`
- Otherwise: use `obs_scenes_set_current_program` (program output)

Default to **program** unless the user explicitly mentions preview/studio mode.

## Error Handling

If `obs_scenes_set_current_program` fails:
- **Verify the scene name is exact (case-sensitive)** — OBS requires the exact case as returned by `obs_scenes_list`
- Check if scene name matches exactly (including capitalization)
- Verify OBS is still connected: `call_tool('obs_connection_status', {})`
- Return short error: "Failed to switch to X. Scene may not exist or OBS disconnected."

## Quick Reference

```javascript
// Connection check (if needed)
const status = await call_tool('obs_connection_status', {});
if (!status?.connected) {
  // Handle connection issue
}

// List scenes (first time only)
const scenes = await call_tool('obs_scenes_list', {});

// Switch scene (primary action)
await call_tool('obs_scenes_set_current_program', {
  sceneName: 'Exact Scene Name'
});

// Get current scene (optional, for context)
const current = await call_tool('obs_scenes_get_current_program', {});
```
