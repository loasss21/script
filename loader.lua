-- NOVA loader v6.3: run THIS, it pulls the right file for the game.
-- Needs ONE of: game:HttpGet, game:HttpGetAsync, request/syn.request/http_request.
-- If none exist, run nova.lua directly instead.

local SB_UNIVERSE = 3734304510 -- South Bronx: The Trenches
local SB_URL = "https://raw.githubusercontent.com/loasss21/script/main/southbronx.lua"
local UNI_URL = "https://raw.githubusercontent.com/loasss21/script/main/universal.lua"

local function fetch(url)
    if typeof(game.HttpGet) == "function" then
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if ok and type(src) == "string" and src ~= "" then return src end
    end
    if typeof(game.HttpGetAsync) == "function" then
        local ok, src = pcall(function() return game:HttpGetAsync(url) end)
        if ok and type(src) == "string" and src ~= "" then return src end
    end
    local req = (typeof(request) == "function" and request)
        or (typeof(syn) == "table" and typeof(syn.request) == "function" and syn.request)
        or (typeof(http_request) == "function" and http_request)
        or (typeof(http) == "table" and typeof(http.request) == "function" and http.request)
    if req then
        local ok, res = pcall(function() return req({Url = url, Method = "GET"}) end)
        if ok and res then
            if type(res) == "string" and res ~= "" then return res end
            if type(res) == "table" and type(res.Body) == "string" and res.Body ~= "" then return res.Body end
        end
    end
    return nil
end

local isSB = false
pcall(function() isSB = game.GameId == SB_UNIVERSE end)
local url = isSB and SB_URL or UNI_URL
print("[NOVA] loader | southbronx=" .. tostring(isSB))
print("[NOVA] loader | thinking...")
task.wait(3)
print("[NOVA] loader | fetching " .. url)
local src = fetch(url)
if not src then
    warn("[NOVA] loader failed: no working HTTP API in this executor and/or bad URL. Run nova.lua directly instead.")
    return
end
local fn, err = loadstring(src)
if not fn then
    warn("[NOVA] loader compile failed: " .. tostring(err))
    return
end
print("[NOVA] loader | running " .. (isSB and "southbronx" or "universal"))
fn()
