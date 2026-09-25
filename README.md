# NOVA v7.0

Roblox script: ESP / Aimbot / Misc / Utility (+ Farm-tab in South Bronx: The Trenches).

## Files

- `loader.lua` — run this. Shows ESP ONLY / FULL choice, detects the game, pulls the right file.
- `universal.lua` — main script (auto-detects South Bronx, no Farm tab).
- `southbronx.lua` — South Bronx build, extra Farm tab (fly/noclip live in Utility).
- `arsenal.lua` — Arsenal build (team-check on, faster smoothing, 1500m range).
- `nova.lua` — offline mirror of `universal.lua`. Paste directly when HTTP is unavailable.

## Tabs

ESP (chams, health bar) / Aimbot (Camera + Mouse, target lock, prediction) / Rage (ragebot, recoil control) / Misc (server hop, keybinds window, FPS cap/overlay, copy JobId/PlaceId) / Utility (crosshair) / Arsenal-tab alleen in `arsenal.lua` (silent aim, gun mods, hitbox expander) / Farm-tab alleen in `southbronx.lua`.

Triggerbot is verwijderd. Sidebar heeft een Discord-knop (vervang `https://discord.gg/REPLACE-ME` in de `discBtn` handler door je invite-link).

HUD rechtsboven toont NOVA + FPS (toggle in Misc). Keybinds-window staat standaard uit, zet aan via Misc.

## Usage (executor)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/loasss21/script/main/loader.lua"))()
```

Menu: RightShift • Panic (unload): Delete
