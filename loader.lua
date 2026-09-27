-- NOVA loader v8.0: one LAUNCH button, boots FULL for the detected game.
-- Routes: South Bronx -> southbronx.lua | Arsenal -> arsenal.lua | else -> nova.lua
-- Needs ONE of: game:HttpGet, game:HttpGetAsync, request/syn.request/http_request.

local SB_UNIVERSE = 3734304510 -- South Bronx: The Trenches
local SB_PLACES = { [10179538382] = true }
local ARSENAL_UNIVERSE = 111958650 -- Arsenal by ROLVe
local ARSENAL_PLACES = { [286090429] = true }
local SB_URL = "https://raw.githubusercontent.com/loasss21/script/main/southbronx.lua"
local ARS_URL = "https://raw.githubusercontent.com/loasss21/script/main/arsenal.lua"
local UNI_URL = "https://raw.githubusercontent.com/loasss21/script/main/nova.lua"

local THEME_BG = Color3.fromRGB(16,16,22)
local THEME_PANEL = Color3.fromRGB(24,24,34)
local THEME_ACCENT = Color3.fromRGB(124,92,255)
local THEME_ITEM = Color3.fromRGB(34,34,50)
local THEME_DIM = Color3.fromRGB(175,175,190)
local THEME_STROKE = Color3.fromRGB(58,58,80)

local parentGui = nil
pcall(function()
    local lp = game:GetService("Players").LocalPlayer
    parentGui = lp and lp:WaitForChild("PlayerGui")
end)
if gethui then pcall(function() parentGui = gethui() end) end
if not parentGui then
    warn("[NOVA] loader: no GUI parent, running blind")
end

-- clear stale loader GUIs from previous executions
pcall(function() if parentGui then
    for _,g in ipairs(parentGui:GetChildren()) do
        if g.Name == "NovaLoader" then g:Destroy() end
    end
end end)

-- game subtitle for the loader card
local function detectName()
    local uni, place = 0, 0
    pcall(function() uni = game.GameId end)
    pcall(function() place = game.PlaceId end)
    if uni == ARSENAL_UNIVERSE or ARSENAL_PLACES[place] == true then return "Arsenal" end
    if uni == SB_UNIVERSE or SB_PLACES[place] == true then return "South Bronx" end
    return "Universal"
end

local statusLbl, barFill, loadGui, launchRow
if parentGui then
    loadGui = Instance.new("ScreenGui")
    loadGui.Name = "NovaLoader"
    loadGui.ResetOnSpawn = false
    loadGui.DisplayOrder = 1000
    loadGui.Parent = parentGui
    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5,0.5)
    frame.Position = UDim2.new(0.5,0,0.5,0)
    frame.Size = UDim2.new(0,300,0,168)
    frame.BackgroundColor3 = THEME_BG
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = loadGui
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0,12) fc.Parent = frame
    local fs = Instance.new("UIStroke") fs.Color = THEME_STROKE fs.Thickness = 1 fs.Parent = frame
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,0,0,36) title.BackgroundTransparency = 1
    title.Text = "NOVA  •  Loader" title.Font = Enum.Font.GothamBold
    title.TextSize = 15 title.TextColor3 = Color3.new(1,1,1) title.Parent = frame
    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1,0,0,18) subLbl.Position = UDim2.new(0,0,0,36) subLbl.BackgroundTransparency = 1
    subLbl.Text = detectName() .. "  •  FULL" subLbl.Font = Enum.Font.GothamBold
    subLbl.TextSize = 13 subLbl.TextColor3 = THEME_ACCENT subLbl.Parent = frame
    launchRow = Instance.new("Frame")
    launchRow.Size = UDim2.new(1,-20,0,32) launchRow.Position = UDim2.new(0,10,0,58)
    launchRow.BackgroundTransparency = 1 launchRow.Parent = frame
    local btnLaunch = Instance.new("TextButton")
    btnLaunch.Size = UDim2.new(1,0,1,0) btnLaunch.Text = "LAUNCH"
    btnLaunch.Font = Enum.Font.GothamBold btnLaunch.TextSize = 14
    btnLaunch.BackgroundColor3 = THEME_ACCENT btnLaunch.TextColor3 = Color3.new(1,1,1)
    btnLaunch.AutoButtonColor = false btnLaunch.Active = true btnLaunch.Parent = launchRow
    local c1 = Instance.new("UICorner") c1.CornerRadius = UDim.new(0,8) c1.Parent = btnLaunch
    statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1,-20,0,20) statusLbl.Position = UDim2.new(0,10,0,96)
    statusLbl.BackgroundTransparency = 1 statusLbl.Text = "ready..."
    statusLbl.Font = Enum.Font.Gotham statusLbl.TextSize = 12
    statusLbl.TextColor3 = THEME_DIM statusLbl.Parent = frame
    local barBG = Instance.new("Frame")
    barBG.Size = UDim2.new(1,-20,0,12) barBG.Position = UDim2.new(0,10,0,122)
    barBG.BackgroundColor3 = THEME_PANEL barBG.BorderSizePixel = 0 barBG.Parent = frame
    local bbgc = Instance.new("UICorner") bbgc.CornerRadius = UDim.new(0,6) bbgc.Parent = barBG
    barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0,0,1,0) barFill.BackgroundColor3 = THEME_ACCENT
    barFill.BorderSizePixel = 0 barFill.Parent = barBG
    local bfc = Instance.new("UICorner") bfc.CornerRadius = UDim.new(0,6) bfc.Parent = barFill
    local foot = Instance.new("TextLabel")
    foot.Size = UDim2.new(1,-20,0,20) foot.Position = UDim2.new(0,10,0,138)
    foot.BackgroundTransparency = 1 foot.Text = "FULL = everything unlocked."
    foot.Font = Enum.Font.Gotham foot.TextSize = 11
    foot.TextColor3 = THEME_DIM foot.TextWrapped = true foot.Parent = frame
    btnLaunch.MouseButton1Click:Connect(function()
        setMode("full")
        pcall(function() launchRow.Visible = false end)
        startRun("full")
    end)
end

local started = false
local function setStage(text, frac)
    print("[NOVA] loader | " .. text)
    pcall(function()
        statusLbl.Text = text
        barFill.Size = UDim2.new(math.clamp(frac,0,1),0,1,0)
    end)
end

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

local function fail(msg)
    warn("[NOVA] loader failed: " .. msg .. " Run the game file directly instead.")
    started = false -- allow retry via the LAUNCH button
    pcall(function()
        statusLbl.Text = "failed: " .. msg .. " (tap LAUNCH to retry)"
        statusLbl.TextColor3 = Color3.fromRGB(255,120,120)
    end)
    pcall(function() if launchRow then launchRow.Visible = true end end)
end

local function route()
    local uni, place = 0, 0
    pcall(function() uni = game.GameId end)
    pcall(function() place = game.PlaceId end)
    if uni == SB_UNIVERSE or SB_PLACES[place] == true then return SB_URL, "southbronx" end
    if uni == ARSENAL_UNIVERSE or ARSENAL_PLACES[place] == true then return ARS_URL, "arsenal" end
    return UNI_URL, "nova"
end

-- mode handoff: getgenv when available, _G as fallback (scripts check both)
function setMode(m)
    pcall(function()
        local g = getgenv and getgenv()
        if type(g) == "table" then g.NOVA_MODE = m end
    end)
    pcall(function() _G.NOVA_MODE = m end)
end

function startRun(mode)
    if started then return end
    started = true
    local url, fname = route()
    setStage("mode: " .. mode .. " • thinking...", 0.1)
    task.wait(3)
    setStage("fetching " .. fname .. "...", 0.45)
    local src = fetch(url)
    if not src then
        fail("no working HTTP API in this executor and/or bad URL.")
        return
    end
    setStage("compiling " .. fname .. "...", 0.75)
    local fn, err = loadstring(src)
    if not fn then
        fail("compile error: " .. tostring(err))
        return
    end
    setStage("running " .. fname .. " (" .. mode .. ")...", 1)
    task.wait(0.4)
    pcall(function() if loadGui then loadGui:Destroy() end end)
    fn()
end
