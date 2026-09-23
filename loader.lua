-- NOVA loader v6.2: run THIS, it pulls the right file for the game.
-- 1) Upload southbronx.lua + universal.lua to a PUBLIC GitHub repo
-- 2) Open each file on GitHub -> Raw -> copy the URL
-- 3) Paste the URLs below (keep the quotes)
-- Needs an executor with game:HttpGet. If yours lacks it, run nova.lua directly.

local SB_UNIVERSE = 3734304510 -- South Bronx: The Trenches
local SB_URL = "https://raw.githubusercontent.com/loasss21/script/main/southbronx.lua"
local UNI_URL = "https://raw.githubusercontent.com/loasss21/script/main/universal.lua"

local isSB = false
pcall(function() isSB = game.GameId == SB_UNIVERSE end)
print("[NOVA] loader | southbronx=" .. tostring(isSB))

local url = isSB and SB_URL or UNI_URL
local ok, src = pcall(function() return game:HttpGet(url) end)
if not ok or type(src) ~= "string" or src == "" then
    warn("[NOVA] loader failed: check the URLs, repo must be PUBLIC, executor needs HttpGet. Run nova.lua directly instead.")
    return
end
loadstring(src)()
