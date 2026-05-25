---
name: obs-transition-control
description: >
  Control OBS transitions and Studio Mode via the OBS MCP server.
  Use for short, imperative commands like "cut to preview", "fade to the
  next scene", "roll the stinger", "enable studio mode", "set transition
  duration to 500 ms", or "switch to fade transition". Optimized for live
  production switching.
---

# OBS Transition Control

Control over the active transition kind, transition duration, the Studio Mode "Transition" button, and Studio Mode itself.

**Core philosophy**: Operators want explicit transition control beyond just switching scenes — give them the verbs that match a hardware switcher.

## When to Use

- "Cut to preview" / "transition to preview" / "take it"
- "Fade to the next scene" / "fade out"
- "Roll the stinger" / "use the stinger transition"
- "Switch to fade transition" / "set transition to cut"
- "Set transition duration to 500 ms"
- "Enable studio mode" / "turn off studio mode"

**Do NOT use** for plain scene switching when not in Studio Mode (use `obs-fast-scene-switcher`).

## Available Tools

All invoked via `execute` with JavaScript `call_tool()`:

### Transitions
- `obs_transitions_list` — list scene transitions in OBS. Returns `{ currentSceneTransitionName, currentSceneTransitionKind, currentSceneTransitionDuration, transitions }`.
- `obs_transitions_get_kind_list` — list available transition kinds (e.g., `cut_transition`, `fade_transition`, `slide_transition`, `obs_stinger_transition`).
- `obs_transitions_get_current` / `obs_transitions_set_current` — get / set the active transition by `transitionName`.
- `obs_transitions_trigger_studio_mode` — trigger the main "Transition" button (only meaningful in Studio Mode).
- `obs_transitions_get_duration` / `obs_transitions_set_duration` — `transitionDuration` in ms (50–20000).
- `obs_transitions_get_settings` / `obs_transitions_set_settings` — per-transition settings (e.g., stinger media path).

### Studio Mode
- `obs_ui_get_studio_mode_enabled` — `{ studioModeEnabled }`.
- `obs_ui_set_studio_mode_enabled` — pass `{ studioModeEnabled: true | false }`.

## Shared State Reuse (latency-first)

If a session-wide `obsState` snapshot from `obs-get-state` already exists in memory, **read it instead of re-querying**:

- `obsState.studioModeEnabled` → routes "transition" to either an immediate program switch or a `trigger_studio_mode` call
- `obsState.currentProgramScene` / `currentPreviewScene` → required for stinger and manual-transition flows

**Do NOT call `obs-get-state` proactively** — `obs_transitions_list` alone is sufficient first-use discovery. Only fall back to `obs-get-state` if studio mode appears mismatched with the cached value or transitions reference scene names not in `obsState.scenes`.

## Command Mapping

| User says | Action |
|---|---|
| "Cut to preview" / "take it" | `obs_transitions_trigger_studio_mode` (requires Studio Mode) |
| "Fade to the next scene" | Set current transition to a Fade, then trigger |
| "Use the stinger" / "roll the stinger" | Set current transition to a Stinger, then trigger |
| "Set transition to fade" | `obs_transitions_set_current` with the Fade transition's name |
| "Transition duration 500 ms" | `obs_transitions_set_duration` with `transitionDuration: 500` |
| "Enable studio mode" | `obs_ui_set_studio_mode_enabled` with `studioModeEnabled: true` |
| "Disable studio mode" | `obs_ui_set_studio_mode_enabled` with `studioModeEnabled: false` |

## Studio Mode Awareness

`obs_transitions_trigger_studio_mode` only does something meaningful when **Studio Mode is on**.

Workflow for "fade to next scene" without Studio Mode:
1. Studio Mode is off → just call `obs_scenes_set_current_program` with the next scene name (the active transition fires automatically).
2. Studio Mode is on → set the next scene as **preview**, then call `obs_transitions_trigger_studio_mode`.

```javascript
const studio = await call_tool('obs_ui_get_studio_mode_enabled', {});
if (studio.studioModeEnabled) {
  await call_tool('obs_scenes_set_current_preview', { sceneName: 'Break' });
  await call_tool('obs_transitions_trigger_studio_mode', {});
} else {
  await call_tool('obs_scenes_set_current_program', { sceneName: 'Break' });
}
```

## Transition Selection by Kind

User typically says "fade" or "stinger", not the exact transition name. Resolve by listing and matching:

```javascript
const { transitions } = await call_tool('obs_transitions_list', {});
const fade = transitions.find(t => t.transitionKind === 'fade_transition');
await call_tool('obs_transitions_set_current', {
  transitionName: fade.transitionName,
});
```

Cache the kind → name map after first lookup.

## Latency-Conscious Behavior

1. **For "take it" / "cut to preview", call `obs_transitions_trigger_studio_mode` immediately** — assume Studio Mode is on. Catch the error if not.
2. **Don't list transitions on every command.** Cache after the first call.
3. **Combine set + trigger in one execute** when the user wants a specific transition kind for the next take.

## Example Interactions

### Example 1: Cut to preview

**User**: "Cut to preview."

**Agent** (tool):
```javascript
await call_tool('obs_transitions_trigger_studio_mode', {});
```

**Agent** (chat): "Transitioned to preview."

### Example 2: Set duration

**User**: "Set transition to 750 ms."

**Agent** (tool):
```javascript
await call_tool('obs_transitions_set_duration', { transitionDuration: 750 });
```

**Agent** (chat): "Transition duration set to 750 ms."

### Example 3: Roll the stinger

**User**: "Roll the stinger to BRB."

**Agent** (tool):
```javascript
const { transitions } = await call_tool('obs_transitions_list', {});
const stinger = transitions.find(t => t.transitionKind === 'obs_stinger_transition');
await call_tool('obs_transitions_set_current', {
  transitionName: stinger.transitionName,
});
await call_tool('obs_scenes_set_current_preview', { sceneName: 'BRB' });
await call_tool('obs_transitions_trigger_studio_mode', {});
```

**Agent** (chat): "Stinger rolling to BRB."

### Example 4: Enable studio mode

**User**: "Enable studio mode."

**Agent** (tool):
```javascript
await call_tool('obs_ui_set_studio_mode_enabled', { studioModeEnabled: true });
```

**Agent** (chat): "Studio Mode enabled."

## Error Handling

- **`Studio Mode is not active`**: prompt to enable it, or fall back to `obs_scenes_set_current_program`.
- **No stinger configured**: tell the user to add a Stinger transition in OBS Settings → Scene Transitions.
- **Duration out of range**: clamp to 50–20000 ms and inform the user.

## Quick Reference

```javascript
// Trigger studio mode transition (the "Transition" button)
await call_tool('obs_transitions_trigger_studio_mode', {});

// Set the current transition
await call_tool('obs_transitions_set_current', { transitionName: 'Fade' });

// Set duration (ms)
await call_tool('obs_transitions_set_duration', { transitionDuration: 500 });

// Toggle studio mode
await call_tool('obs_ui_set_studio_mode_enabled', { studioModeEnabled: true });
```
