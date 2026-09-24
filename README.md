# NOVA v7.0

Roblox script: ESP / Aimbot / Misc / Utility (+ Farm-tab in South Bronx: The Trenches).

## Files

- `loader.lua` — run this. Shows ESP ONLY / FULL choice, detects the game, pulls the right file.
- `universal.lua` — main script (auto-detects South Bronx, no Farm tab).
- `southbronx.lua` — South Bronx build, extra Farm tab (fly/noclip live in Utility).
- `nova.lua` — offline mirror of `universal.lua`. Paste directly when HTTP is unavailable.

## Usage (executor)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/loasss21/script/main/loader.lua"))()
```

Menu: RightShift • Panic (unload): Delete
