---
name: obs-audio-control
description: >
  Fast, reliable microphone and desktop audio control via the OBS MCP
  server. Use for short, imperative commands like "mute my mic",
  "unmute me", "mute game audio", "kill desktop audio", "silence everything
  except my mic", or "turn down the music to -12 dB". Encodes mute/unmute
  and volume workflows for live production.
---

# OBS Audio Control

Low-latency audio guardrail for live production. Handles microphone, desktop, game, and any named input source.

**Core philosophy**: A bad mute is worse than a slow mute, but a slow mute is still bad. Cache input names; act fast.

## When to Use

- "Mute my mic" / "unmute me" / "mute the microphone"
- "Mute game audio" / "kill desktop audio" / "mute the music"
- "Silence everything except my mic"
- "Turn down the music to -12 dB" / "set mic volume to 0 dB"
- "Push to mute the mic" / "ducking" requests

**Do NOT use** for hiding visual sources (that's `obs-overlay-control`) or audio routing/monitoring config (use the general `obs-mcp` skill).

## Available Tools

All invoked via `execute` with JavaScript `call_tool()`:

- `obs_inputs_list` — list inputs. Filter by `inputKind` to narrow (e.g., `coreaudio_input_capture`, `wasapi_output_capture`). Use to build an audio input cache.
- `obs_inputs_get_special` — get OBS's "special" inputs: desktop audio 1/2, mic/aux 1–4. Returns `{ desktop1, desktop2, mic1, mic2, mic3, mic4 }`.
- `obs_inputs_get_mute` / `obs_inputs_set_mute` / `obs_inputs_toggle_mute` — `inputName`, `inputMuted`.
- `obs_inputs_get_volume` / `obs_inputs_set_volume` — `inputName`, `inputVolumeDb` (-100 to 26 dB) or `inputVolumeMul` (linear).

## Shared State Reuse (latency-first)

If a session-wide `obsState` snapshot from `obs-get-state` already exists in memory, **skip discovery and read directly**:

- `obsState.audio.special` → `mic1`, `desktop1`, etc. (semantic-name → exact input-name map)
- `obsState.audio.inputs` → full named-input list (filter by `inputKind` to find Music, Game, etc.)

**Do NOT call `obs-get-state` proactively** — this skill's two-call audio cache is already minimal. Only invoke `obs-get-state` when:
- An input name the user mentioned isn't found in the cache and `obs_inputs_list` alone doesn't resolve it.
- A mute/volume call returned success but the user reports no audible change (rare; usually means the wrong input was named).

## Audio Input Cache

On first audio request:

```javascript
// Get OBS's "special" sources (mic and desktop slots)
const special = await call_tool('obs_inputs_get_special', {});
// Get all inputs to find named ones (Music, Game, etc.)
const inputs = await call_tool('obs_inputs_list', {});
```

Build a semantic-name → exact-input-name map:
- "mic" / "microphone" / "my mic" → `special.mic1` (or first non-null mic slot)
- "desktop" / "desktop audio" / "system audio" → `special.desktop1`
- "game" / "game audio" → match input named like "Game" or `wasapi_process_output_capture`
- "music" → match input with "music" in the name (case-insensitive)

Reuse this cache for the rest of the session.

## Command Mapping

| User says | Action |
|---|---|
| "Mute my mic" | `obs_inputs_set_mute` on mic1, `inputMuted: true` |
| "Unmute me" / "unmute mic" | `obs_inputs_set_mute` on mic1, `inputMuted: false` |
| "Toggle mic" | `obs_inputs_toggle_mute` on mic1 |
| "Mute desktop" / "kill desktop audio" | `obs_inputs_set_mute` on desktop1, `inputMuted: true` |
| "Silence everything except my mic" | Mute all audio inputs except mic1 |
| "Set mic to -6 dB" | `obs_inputs_set_volume` on mic1, `inputVolumeDb: -6` |
| "Turn down the music" | `obs_inputs_set_volume` on Music, lower by 6 dB from current |

## Critical Rules

1. **Source names are case-sensitive.** "Mic/Aux" and "mic/aux" are different. Always use the exact name from the cache.
2. **Prefer `inputVolumeDb` over `inputVolumeMul`.** Decibels are user-intuitive; multipliers are not.
3. **Volume range is -100 dB to +26 dB.** Clamp user requests to this range.
4. **Don't mute every input on "silence everything".** Only mute audio-capable inputs (mic, desktop, media, browser). Use `obs_inputs_list` to filter.

## Example Interactions

### Example 1: Mute mic

**User**: "Mute my mic."

**Agent** (tool — first time, builds cache):
```javascript
const { mic1 } = await call_tool('obs_inputs_get_special', {});
await call_tool('obs_inputs_set_mute', { inputName: mic1, inputMuted: true });
```

**Agent** (chat): "Mic muted."

### Example 2: Volume change

**User**: "Set mic to -6 dB."

**Agent** (tool — uses cached mic1):
```javascript
await call_tool('obs_inputs_set_volume', {
  inputName: 'Mic/Aux',
  inputVolumeDb: -6.0
});
```

**Agent** (chat): "Mic set to -6 dB."

### Example 3: Silence everything except mic

**User**: "Silence everything except my mic."

**Agent** (tool):
```javascript
const special = await call_tool('obs_inputs_get_special', {});
const audioInputs = ['desktop1', 'desktop2', 'mic2', 'mic3', 'mic4']
  .map(k => special[k])
  .filter(Boolean);
await Promise.all(
  audioInputs.map(name =>
    call_tool('obs_inputs_set_mute', { inputName: name, inputMuted: true })
  )
);
```

**Agent** (chat): "Muted all audio inputs except your mic."

### Example 4: Push-to-mute pattern

**User**: "Mute mic for 30 seconds."

**Agent** (tool):
```javascript
await call_tool('obs_inputs_set_mute', { inputName: 'Mic/Aux', inputMuted: true });
await call_tool('obs_client_sleep', { ms: 30000 });
await call_tool('obs_inputs_set_mute', { inputName: 'Mic/Aux', inputMuted: false });
```

**Agent** (chat): "Muting mic for 30 seconds…" then "Mic unmuted."

## Error Handling

- **"Input not found"**: the cached name is stale or wrong. Refresh with `obs_inputs_list` and retry.
- **No mic detected**: `obs_inputs_get_special` returned `null` for all mic slots. Tell the user to configure Mic/Aux in OBS Settings → Audio.

## Quick Reference

```javascript
// Mute / unmute
await call_tool('obs_inputs_set_mute', { inputName: 'Mic/Aux', inputMuted: true });
await call_tool('obs_inputs_toggle_mute', { inputName: 'Mic/Aux' });

// Volume in dB
await call_tool('obs_inputs_set_volume', {
  inputName: 'Mic/Aux',
  inputVolumeDb: -6.0
});

// Special slots (cached helper)
const { mic1, desktop1 } = await call_tool('obs_inputs_get_special', {});
```
