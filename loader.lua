-- NOVA loader v7.0: pick a mode, it pulls the right file for the game.
-- Needs ONE of: game:HttpGet, game:HttpGetAsync, request/syn.request/http_request.
-- If none exist, run nova.lua directly instead.

local SB_UNIVERSE = 3734304510 -- South Bronx: The Trenches
local SB_PLACES = { [10179538382] = true }
local ARSENAL_UNIVERSE = 111958650 -- Arsenal by ROLVe
local ARSENAL_PLACES = { [286090429] = true }
local SB_URL = "https://raw.githubusercontent.com/loasss21/script/main/southbronx.lua"
local ARS_URL = "https://raw.githubusercontent.com/loasss21/script/main/arsenal.lua"
local UNI_URL = "https://raw.githubusercontent.com/loasss21/script/main/universal.lua"

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

-- mode handoff: getgenv when available, _G as fallback (scripts check both)
local function setMode(m)
    pcall(function()
        local g = getgenv and getgenv()
        if type(g) == "table" then g.NOVA_MODE = m end
    end)
    pcall(function() _G.NOVA_MODE = m end)
end

local statusLbl, barFill, loadGui, modeRow
if parentGui then
    loadGui = Instance.new("ScreenGui")
    loadGui.Name = "NovaLoader"
    loadGui.ResetOnSpawn = false
    loadGui.DisplayOrder = 1000
    loadGui.Parent = parentGui
    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5,0.5)
    frame.Position = UDim2.new(0.5,0,0.5,0)
    frame.Size = UDim2.new(0,300,0,196)
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
    modeRow = Instance.new("Frame")
    modeRow.Size = UDim2.new(1,-20,0,32) modeRow.Position = UDim2.new(0,10,0,42)
    modeRow.BackgroundTransparency = 1 modeRow.Parent = frame
    local btnESP = Instance.new("TextButton")
    btnESP.Size = UDim2.new(0.5,-3,0,32) btnESP.Text = "ESP ONLY"
    btnESP.Font = Enum.Font.GothamBold btnESP.TextSize = 13
    btnESP.BackgroundColor3 = THEME_ITEM btnESP.TextColor3 = Color3.new(1,1,1)
    btnESP.AutoButtonColor = false btnESP.Active = true btnESP.Parent = modeRow
    local c1 = Instance.new("UICorner") c1.CornerRadius = UDim.new(0,8) c1.Parent = btnESP
    local btnFull = Instance.new("TextButton")
    btnFull.Size = UDim2.new(0.5,-3,0,32) btnFull.Position = UDim2.new(0.5,3,0,0)
    btnFull.Text = "FULL" btnFull.Font = Enum.Font.GothamBold btnFull.TextSize = 13
    btnFull.BackgroundColor3 = THEME_ACCENT btnFull.TextColor3 = Color3.new(1,1,1)
    btnFull.AutoButtonColor = false btnFull.Active = true btnFull.Parent = modeRow
    local c2 = Instance.new("UICorner") c2.CornerRadius = UDim.new(0,8) c2.Parent = btnFull
    statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1,-20,0,20) statusLbl.Position = UDim2.new(0,10,0,82)
    statusLbl.BackgroundTransparency = 1 statusLbl.Text = "choose mode..."
    statusLbl.Font = Enum.Font.Gotham statusLbl.TextSize = 12
    statusLbl.TextColor3 = THEME_DIM statusLbl.Parent = frame
    local barBG = Instance.new("Frame")
    barBG.Size = UDim2.new(1,-20,0,12) barBG.Position = UDim2.new(0,10,0,108)
    barBG.BackgroundColor3 = THEME_PANEL barBG.BorderSizePixel = 0 barBG.Parent = frame
    local bbgc = Instance.new("UICorner") bbgc.CornerRadius = UDim.new(0,6) bbgc.Parent = barBG
    barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0,0,1,0) barFill.BackgroundColor3 = THEME_ACCENT
    barFill.BorderSizePixel = 0 barFill.Parent = barBG
    local bfc = Instance.new("UICorner") bfc.CornerRadius = UDim.new(0,6) bfc.Parent = barFill
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1,-20,0,32) hint.Position = UDim2.new(0,10,0,128)
    hint.BackgroundTransparency = 1 hint.Text = "ESP ONLY = boxes/names, no aimbot.\nFULL = everything."
    hint.Font = Enum.Font.Gotham hint.TextSize = 11
    hint.TextColor3 = THEME_DIM hint.TextWrapped = true hint.Parent = frame
    btnESP.MouseButton1Click:Connect(function()
        setMode("esp")
        pcall(function() modeRow.Visible = false end)
        startRun("esp")
    end)
    btnFull.MouseButton1Click:Connect(function()
        setMode("full")
        pcall(function() modeRow.Visible = false end)
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
    warn("[NOVA] loader failed: " .. msg .. " Run nova.lua directly instead.")
    started = false -- allow retry via the mode buttons
    pcall(function()
        statusLbl.Text = "failed: " .. msg .. " (tap a mode to retry)"
        statusLbl.TextColor3 = Color3.fromRGB(255,120,120)
    end)
    pcall(function() if modeRow then modeRow.Visible = true end end)
end

local function isSouthBronx()
    local uni, place = 0, 0
    pcall(function() uni = game.GameId end)
    pcall(function() place = game.PlaceId end)
    return uni == SB_UNIVERSE or SB_PLACES[place] == true
end

local function isArsenal()
    local uni, place = 0, 0
    pcall(function() uni = game.GameId end)
    pcall(function() place = game.PlaceId end)
    return uni == ARSENAL_UNIVERSE or ARSENAL_PLACES[place] == true
end

function startRun(mode)
    if started then return end
    started = true
    local url, fname = UNI_URL, "universal"
    if isSouthBronx() then url, fname = SB_URL, "southbronx"
    elseif isArsenal() then url, fname = ARS_URL, "arsenal" end
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

-- no GUI (blind run): default to FULL so nothing is lost
if not parentGui then
    startRun("full")
end
