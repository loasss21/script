-- NOVA v7.0 ARSENAL FILE | ESP / Aimbot / Utility (Arsenal by ROLVe)
-- Menu: RightShift (drag via welcome header) • Panic default: Delete

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

print("[NOVA] v7.0 boot (arsenal file)")

-- KEY SYSTEM: set true + put your keys in VALID_KEYS to lock the script
local KeySystemEnabled = false
local VALID_KEYS = { ["CHANGE-ME"] = true }
local KEY_FILE = "nova_key.txt"
local MAX_KEY_TRIES = 5

-- GAME FILE: Arsenal build (hardcoded, no detection needed)
local IS_SOUTH_BRONX = false
local GAME_VERSION = "Arsenal"
local FILE_TAG = "arsenal"
local detectedUniverse, detectedPlace = 0, 0
pcall(function() detectedUniverse = game.GameId end)
pcall(function() detectedPlace = game.PlaceId end)

print("[NOVA] v7.0 | game=" .. GAME_VERSION .. " place=" .. tostring(detectedPlace) .. " universe=" .. tostring(detectedUniverse))

local THEME = {
    BG = Color3.fromRGB(16,16,22),
    Panel = Color3.fromRGB(24,24,34),
    Item = Color3.fromRGB(34,34,50),
    Stroke = Color3.fromRGB(58,58,80),
    Accent = Color3.fromRGB(124,92,255),
    TextDim = Color3.fromRGB(175,175,190),
}

local Settings = {
    ESPEnabled = true, Boxes = true, Names = true, Distance = true,
    TeamCheck = true, MaxESP = 2000, OverlayY = 0,
    Tracers = false, Inventory = false, Chams = false, HealthBar = false,
    Color = Color3.fromRGB(255,0,0),
    AimEnabled = false, AimMethod = "Camera", AimMode = "Hold",
    AimKey = {Type="Mouse", Button=Enum.UserInputType.MouseButton2, Name="RMB"},
    FOV = 100, ShowFOV = true, Smoothing = 4,
    Target = "Head", Priority = "Closest", AimLock = false, Prediction = 0,
    AimTeamCheck = true, WallCheck = true, NoKnock = true,
    TrigEnabled = false, TrigMode = "Always", TrigTarget = "Any",
    TrigTeamCheck = true, TrigNoKnock = true, TrigDelay = 120,
    MaxDistance = 1000, AFKProtect = true, FPSCap = 60,
    PanicKey = {Type="Key", Key=Enum.KeyCode.Delete, Name="Delete"},
    MenuKey = {Type="Key", Key=Enum.KeyCode.RightShift, Name="RightShift"},
}

-- GAME PROFILE: Arsenal branch (team shooter defaults).
local Profile = {
    version = GAME_VERSION,
    isSouthBronx = IS_SOUTH_BRONX,
    defaultTarget = "Head",
    defaultPriority = "Closest",
    defaultMaxDistance = 1500,
    inventoryDefault = false,
}
Settings.Target = Profile.defaultTarget
Settings.Priority = Profile.defaultPriority
Settings.MaxDistance = Profile.defaultMaxDistance
Settings.Inventory = Profile.inventoryDefault

-- loader mode: ESP_ONLY hides the whole aimbot side (tab, FOV, trigger)
local ESP_ONLY = false
pcall(function()
    local g = getgenv and getgenv()
    if type(g)=="table" and g.NOVA_MODE=="esp" then ESP_ONLY=true end
    if _G.NOVA_MODE=="esp" then ESP_ONLY=true end
end)

local Unloaded = false
local LoadingDone = false
-- key gate open when the key system is off (default), set true on valid key
local keyPassed = not KeySystemEnabled
local Conns = {}
local ESPData = {}
local UIHandles = {}
local lastAttempt = {}
local creating = {}
local function track(c) table.insert(Conns,c) return c end
local hasMouseMove = typeof(mousemoverel) == "function"
-- click fallback chain: mouse1click -> VirtualInputManager -> Tool:Activate
local vimSvc = nil
pcall(function() vimSvc = game:GetService("VirtualInputManager") end)
local function fireClick(x, y)
    if typeof(mouse1click)=="function" then pcall(mouse1click) return "mouse" end
    if vimSvc then
        local ok=pcall(function() vimSvc:SendMouseButtonEvent(x, y, 0, true, game, 1) end)
        pcall(function() vimSvc:SendMouseButtonEvent(x, y, 0, false, game, 1) end)
        if ok then return "vim" end
    end
    local tool=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) return "tool" end
    return nil
end
local canFile = typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
local mouseWarned = false
local trigWarned = false
local frameCount = 0
local lastFOV = -1
local aimingOn = false
local trigAcquireT = 0
local lockedPlayer = nil
local trigMsgLbl = nil
local kb = {win=nil, lines={}, on=true}
local fpsAcc, fpsShown, fpsClock = 0, 60, os.clock()
local openDropClose = nil
-- runtime caches: avoid per-frame GetPlayers() alloc + per-label Backpack scans
local cachedPlayers = {}
local function refreshPlayers() cachedPlayers = Players:GetPlayers() end
refreshPlayers()
local downCache = {}
local invCache = {}
local DOWN_TTL, INV_TTL = 0.25, 1.0

local genv = nil
pcall(function() genv = getgenv() end)
local myRun = 0
if type(genv) == "table" then
    genv.NOVA_RUN = (tonumber(genv.NOVA_RUN) or 0) + 1
    myRun = genv.NOVA_RUN
end
local function runStale()
    return genv ~= nil and tonumber(genv.NOVA_RUN) ~= myRun
end
local function gateOpen()
    return (not KeySystemEnabled) or keyPassed
end

local activeDragFn = nil
track(UserInputService.InputChanged:Connect(function()
    local fn = activeDragFn
    if fn ~= nil then
        local m = UserInputService:GetMouseLocation()
        pcall(fn, m.X, m.Y)
    end
end))
track(UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        activeDragFn = nil
    end
end))

local function deepCleanCharacter(char)
    if not char then return end
    for _,d in ipairs(char:GetDescendants()) do
        local ok, tag = pcall(function() return d:GetAttribute("nx") end)
        if (ok and tag==1) or d.Name=="ESPHL"
            or d.Name=="NovaBox" or d.Name=="NovaTag"
            or d.Name=="ESPBox" or d.Name=="ESPName" then
            pcall(function() d:Destroy() end)
        end
    end
end
local function killOwnGuis(root)
    if not root then return end
    local ok, kids = pcall(function() return root:GetChildren() end)
    if not ok or not kids then return end
    for _,g in ipairs(kids) do
        local ok2, tag = pcall(function() return g:GetAttribute("nx") end)
        if ok2 and tag==1 then pcall(function() g:Destroy() end) end
    end
end
pcall(function() LocalPlayer.PlayerGui:FindFirstChild("NovaHub"):Destroy() end)
pcall(function() LocalPlayer.PlayerGui:FindFirstChild("NovaFx"):Destroy() end)
pcall(function() LocalPlayer.PlayerGui:FindFirstChild("NovaRing"):Destroy() end)
pcall(function() LocalPlayer.PlayerGui:FindFirstChild("ESPMenu"):Destroy() end)
pcall(function() LocalPlayer.PlayerGui:FindFirstChild("ESPSkeleton"):Destroy() end)
pcall(function() LocalPlayer.PlayerGui:FindFirstChild("NOVAOverlay"):Destroy() end)
pcall(function() LocalPlayer.PlayerGui:FindFirstChild("ESPFOV"):Destroy() end)
pcall(function() killOwnGuis(LocalPlayer.PlayerGui) end)
if gethui then
    pcall(function() gethui():FindFirstChild("NovaHub"):Destroy() end)
    pcall(function() gethui():FindFirstChild("NovaFx"):Destroy() end)
    pcall(function() gethui():FindFirstChild("NovaRing"):Destroy() end)
    pcall(function() gethui():FindFirstChild("ESPMenu"):Destroy() end)
    pcall(function() gethui():FindFirstChild("ESPSkeleton"):Destroy() end)
    pcall(function() gethui():FindFirstChild("NOVAOverlay"):Destroy() end)
    pcall(function() gethui():FindFirstChild("ESPFOV"):Destroy() end)
    pcall(function() killOwnGuis(gethui()) end)
end
for _,p in ipairs(Players:GetPlayers()) do if p.Character then deepCleanCharacter(p.Character) end end

local parentGui = LocalPlayer:WaitForChild("PlayerGui")
pcall(function() if gethui then parentGui = gethui() end end)

local overlayGui = Instance.new("ScreenGui")
overlayGui.Name="NovaFx" overlayGui.ResetOnSpawn=false overlayGui.IgnoreGuiInset=true overlayGui.DisplayOrder=998 overlayGui.Parent=parentGui
pcall(function() overlayGui:SetAttribute("nx",1) end)

local fovGui = Instance.new("ScreenGui")
fovGui.Name="NovaRing" fovGui.ResetOnSpawn=false fovGui.IgnoreGuiInset=true fovGui.DisplayOrder=997 fovGui.Parent=parentGui
pcall(function() fovGui:SetAttribute("nx",1) end)
local fovCircle = Instance.new("Frame")
fovCircle.AnchorPoint=Vector2.new(0.5,0.5) fovCircle.BackgroundTransparency=1 fovCircle.Visible=false fovCircle.Active=false fovCircle.Parent=fovGui
local fC = Instance.new("UICorner") fC.CornerRadius=UDim.new(1,0) fC.Parent=fovCircle
local fS = Instance.new("UIStroke") fS.Thickness=1.5 fS.Color=Color3.new(1,1,1) fS.Transparency=0.15 fS.Parent=fovCircle
-- (trigger indicator removed; status label in Trigger tab shows state instead)
local cross = {}
do
    local h = Instance.new("Frame")
    h.AnchorPoint=Vector2.new(0.5,0.5) h.Size=UDim2.new(0,12,0,2)
    h.BackgroundColor3=Color3.new(1,1,1) h.BorderSizePixel=0
    h.Visible=false h.Active=false h.Parent=overlayGui
    local v = Instance.new("Frame")
    v.AnchorPoint=Vector2.new(0.5,0.5) v.Size=UDim2.new(0,2,0,12)
    v.BackgroundColor3=Color3.new(1,1,1) v.BorderSizePixel=0
    v.Visible=false v.Active=false v.Parent=overlayGui
    cross.H, cross.V = h, v
end

local gui = Instance.new("ScreenGui")
gui.Name="NovaHub" gui.ResetOnSpawn=false gui.DisplayOrder=999 gui.Parent=parentGui
pcall(function() gui:SetAttribute("nx",1) end)

local notifHolder=Instance.new("Frame")
notifHolder.Name="NovaNotifs" notifHolder.BackgroundTransparency=1 notifHolder.Active=false
notifHolder.AnchorPoint=Vector2.new(1,0) notifHolder.Position=UDim2.new(1,-16,0,60)
notifHolder.Size=UDim2.new(0,260,0,400) notifHolder.Parent=gui
pcall(function() notifHolder:SetAttribute("nx",1) end)
local notifList=Instance.new("UIListLayout")
notifList.Padding=UDim.new(0,6) notifList.SortOrder=Enum.SortOrder.LayoutOrder
notifList.HorizontalAlignment=Enum.HorizontalAlignment.Right notifList.Parent=notifHolder
local function notify(title, text, ms)
    ms = ms or 2600
    pcall(function()
        local n=0 local oldest=nil
        for _,c in ipairs(notifHolder:GetChildren()) do
            if c:IsA("Frame") then n=n+1 if not oldest then oldest=c end end
        end
        if n>=4 and oldest then oldest:Destroy() end
    end)
    local ok, f = pcall(function()
        local fr=Instance.new("Frame")
        fr.Size=UDim2.new(1,0,0,52) fr.BackgroundColor3=THEME.Panel
        fr.BorderSizePixel=0 fr.Parent=notifHolder
        local fc=Instance.new("UICorner") fc.CornerRadius=UDim.new(0,8) fc.Parent=fr
        local fs=Instance.new("UIStroke") fs.Color=THEME.Stroke fs.Thickness=1 fs.Parent=fr
        local accent=Instance.new("Frame")
        accent.Size=UDim2.new(0,3,1,0) accent.BackgroundColor3=THEME.Accent
        accent.BorderSizePixel=0 accent.Active=false accent.Parent=fr
        local t1=Instance.new("TextLabel")
        t1.Size=UDim2.new(1,-16,0,18) t1.Position=UDim2.new(0,12,0,6)
        t1.BackgroundTransparency=1 t1.Text=title t1.Font=Enum.Font.GothamBold
        t1.TextSize=13 t1.TextColor3=Color3.new(1,1,1) t1.TextXAlignment=Enum.TextXAlignment.Left t1.Parent=fr
        local t2=Instance.new("TextLabel")
        t2.Size=UDim2.new(1,-16,0,20) t2.Position=UDim2.new(0,12,0,26)
        t2.BackgroundTransparency=1 t2.Text=text t2.Font=Enum.Font.Gotham
        t2.TextSize=12 t2.TextColor3=THEME.TextDim t2.TextXAlignment=Enum.TextXAlignment.Left
        t2.TextTruncate=Enum.TextTruncate.AtEnd t2.Parent=fr
        return fr
    end)
    if not ok or not f then return end
    task.delay(ms/1000, function() pcall(function() f:Destroy() end) end)
end

local keyFrame=nil local keyBox=nil local keyMsg=nil
local keyTries=0
if KeySystemEnabled and canFile then
    pcall(function()
        if isfile(KEY_FILE) then
            local saved=readfile(KEY_FILE)
            if saved and VALID_KEYS[saved:gsub("%s+","")] then keyPassed=true end
        end
    end)
end
if KeySystemEnabled and not keyPassed then
    keyFrame=Instance.new("Frame")
    keyFrame.AnchorPoint=Vector2.new(0.5,0.5) keyFrame.Position=UDim2.new(0.5,0,0.5,0)
    keyFrame.Size=UDim2.new(0,280,0,180) keyFrame.BackgroundColor3=THEME.BG
    keyFrame.BorderSizePixel=0 keyFrame.Active=true keyFrame.Draggable=true keyFrame.Parent=gui
    local kc=Instance.new("UICorner") kc.CornerRadius=UDim.new(0,12) kc.Parent=keyFrame
    local ks=Instance.new("UIStroke") ks.Color=THEME.Stroke ks.Thickness=1 ks.Parent=keyFrame
    local kt=Instance.new("TextLabel")
    kt.Size=UDim2.new(1,0,0,40) kt.BackgroundTransparency=1 kt.Text="NOVA  •  Enter Key"
    kt.Font=Enum.Font.GothamBold kt.TextSize=15 kt.TextColor3=Color3.new(1,1,1) kt.Parent=keyFrame
    keyBox=Instance.new("TextBox")
    keyBox.Size=UDim2.new(1,-24,0,34) keyBox.Position=UDim2.new(0,12,0,52)
    keyBox.BackgroundColor3=THEME.Item keyBox.Text="" keyBox.PlaceholderText="paste key here"
    keyBox.Font=Enum.Font.Gotham keyBox.TextSize=13 keyBox.TextColor3=Color3.new(1,1,1)
    keyBox.ClearTextOnFocus=false keyBox.Parent=keyFrame
    local kbc=Instance.new("UICorner") kbc.CornerRadius=UDim.new(0,8) kbc.Parent=keyBox
    local goBtn=Instance.new("TextButton")
    goBtn.Size=UDim2.new(1,-24,0,32) goBtn.Position=UDim2.new(0,12,0,94)
    goBtn.BackgroundColor3=THEME.Accent goBtn.Text="Unlock" goBtn.Font=Enum.Font.GothamBold
    goBtn.TextSize=13 goBtn.TextColor3=Color3.new(1,1,1) goBtn.AutoButtonColor=false goBtn.Active=true goBtn.Parent=keyFrame
    local gbc=Instance.new("UICorner") gbc.CornerRadius=UDim.new(0,8) gbc.Parent=goBtn
    keyMsg=Instance.new("TextLabel")
    keyMsg.Size=UDim2.new(1,-24,0,20) keyMsg.Position=UDim2.new(0,12,0,132)
    keyMsg.BackgroundTransparency=1 keyMsg.Text="" keyMsg.Font=Enum.Font.Gotham
    keyMsg.TextSize=12 keyMsg.TextColor3=Color3.fromRGB(255,120,120) keyMsg.Parent=keyFrame
    goBtn.MouseButton1Click:Connect(function()
        local k=(keyBox.Text or ""):gsub("%s+","")
        if VALID_KEYS[k] then
            keyPassed=true
            if canFile then pcall(writefile, KEY_FILE, k) end
            pcall(function() keyFrame:Destroy() end)
            keyFrame=nil
            notify("NOVA", "key accepted")
        else
            keyTries=keyTries+1
            keyMsg.Text="Wrong key ("..keyTries.."/"..MAX_KEY_TRIES..")"
            if keyTries>=MAX_KEY_TRIES then
                Unloaded=true
                pcall(function() gui:Destroy() end)
                warn("[NOVA] too many bad keys")
            end
        end
    end)
end

local gameNameShown = GAME_VERSION
local loading = Instance.new("Frame")
loading.AnchorPoint=Vector2.new(0.5,0.5) loading.Position=UDim2.new(0.5,0,0.5,0)
loading.Size=UDim2.new(0,300,0,210) loading.BackgroundColor3=THEME.BG
loading.BorderSizePixel=0 loading.Active=true loading.Draggable=true
loading.Visible=(keyFrame==nil) loading.Parent=gui
local lc=Instance.new("UICorner") lc.CornerRadius=UDim.new(0,12) lc.Parent=loading
local ls=Instance.new("UIStroke") ls.Color=THEME.Stroke ls.Thickness=1 ls.Parent=loading
local lTitle=Instance.new("TextLabel")
lTitle.Size=UDim2.new(1,0,0,30) lTitle.BackgroundTransparency=1 lTitle.Text="NOVA  •  "..GAME_VERSION
lTitle.Font=Enum.Font.GothamBold lTitle.TextSize=15 lTitle.TextColor3=Color3.new(1,1,1) lTitle.Parent=loading
local loadGame=Instance.new("TextLabel")
loadGame.Size=UDim2.new(1,-20,0,16) loadGame.Position=UDim2.new(0,10,0,30)
loadGame.BackgroundTransparency=1 loadGame.Text="Joining: "..gameNameShown
loadGame.Font=Enum.Font.Gotham loadGame.TextSize=12 loadGame.TextColor3=THEME.TextDim loadGame.Parent=loading
local spinBG=Instance.new("Frame")
spinBG.AnchorPoint=Vector2.new(0.5,0) spinBG.Position=UDim2.new(0.5,0,0,58)
spinBG.Size=UDim2.new(0,44,0,44) spinBG.BackgroundTransparency=1 spinBG.Active=false spinBG.Parent=loading
local sC=Instance.new("UICorner") sC.CornerRadius=UDim.new(1,0) sC.Parent=spinBG
local sS=Instance.new("UIStroke") sS.Thickness=2 sS.Color=Color3.fromRGB(70,70,90) sS.Parent=spinBG
local spinRot=Instance.new("Frame")
spinRot.AnchorPoint=Vector2.new(0.5,0) spinRot.Position=UDim2.new(0.5,0,0,58)
spinRot.Size=UDim2.new(0,44,0,44) spinRot.BackgroundTransparency=1 spinRot.Active=false spinRot.Parent=loading
local dot=Instance.new("Frame")
dot.AnchorPoint=Vector2.new(0.5,0.5) dot.Position=UDim2.new(0.5,0,0,0)
dot.Size=UDim2.new(0,10,0,10) dot.BackgroundColor3=THEME.Accent dot.BorderSizePixel=0 dot.Active=false dot.Parent=spinRot
local dC=Instance.new("UICorner") dC.CornerRadius=UDim.new(1,0) dC.Parent=dot
local barBG=Instance.new("Frame")
barBG.Size=UDim2.new(1,-24,0,14) barBG.Position=UDim2.new(0,12,0,118)
barBG.BackgroundColor3=THEME.Item barBG.BorderSizePixel=0 barBG.Active=false barBG.Parent=loading
local bbgc=Instance.new("UICorner") bbgc.CornerRadius=UDim.new(0,7) bbgc.Parent=barBG
local barFill=Instance.new("Frame")
barFill.Size=UDim2.new(0,0,1,0) barFill.BackgroundColor3=THEME.Accent barFill.BorderSizePixel=0 barFill.Active=false barFill.Parent=barBG
local bfc=Instance.new("UICorner") bfc.CornerRadius=UDim.new(0,7) bfc.Parent=barFill
local pct=Instance.new("TextLabel")
pct.Size=UDim2.new(1,0,0,20) pct.Position=UDim2.new(0,0,0,138)
pct.BackgroundTransparency=1 pct.Text="0%" pct.Font=Enum.Font.GothamBold
pct.TextSize=12 pct.TextColor3=Color3.new(1,1,1) pct.Parent=loading
local loadVer=Instance.new("TextLabel")
loadVer.Size=UDim2.new(1,0,0,16) loadVer.Position=UDim2.new(0,0,0,164)
loadVer.BackgroundTransparency=1 loadVer.Text="v7.0 ("..FILE_TAG..")"
loadVer.Font=Enum.Font.Gotham loadVer.TextSize=11 loadVer.TextColor3=THEME.TextDim loadVer.Parent=loading
task.spawn(function()
    local ok, info = pcall(function() return MarketplaceService:GetProductInfo(detectedPlace) end)
    if ok and info and info.Name and info.Name ~= "" then
        gameNameShown = info.Name
        pcall(function() loadGame.Text = "Joining: " .. gameNameShown end)
    else
        pcall(function() loadGame.Text = "Joining: " .. GAME_VERSION .. " (place " .. tostring(detectedPlace) .. ")" end)
    end
end)

-- SIDEBAR MENU 620x440
local main=Instance.new("Frame")
main.AnchorPoint=Vector2.new(0.5,0.5) main.Position=UDim2.new(0.5,0,0.5,0)
main.Size=UDim2.new(0,620,0,440)
main.BackgroundColor3=THEME.BG main.BorderSizePixel=0
main.Active=false main.Draggable=false main.ClipsDescendants=true
main.Visible=false main.Parent=gui
local mc=Instance.new("UICorner") mc.CornerRadius=UDim.new(0,14) mc.Parent=main
local ms=Instance.new("UIStroke") ms.Color=THEME.Stroke ms.Thickness=1 ms.Parent=main

local side=Instance.new("Frame")
side.Size=UDim2.new(0,170,1,0) side.BackgroundColor3=THEME.Panel
side.BorderSizePixel=0 side.Parent=main

local head=Instance.new("Frame")
head.Size=UDim2.new(1,0,0,86) head.BackgroundTransparency=1 head.Active=true head.Parent=side
local w1=Instance.new("TextLabel")
w1.Size=UDim2.new(1,-14,0,14) w1.Position=UDim2.new(0,7,0,10)
w1.BackgroundTransparency=1 w1.Text="welcome to" w1.Font=Enum.Font.Gotham
w1.TextSize=12 w1.TextColor3=THEME.TextDim w1.TextXAlignment=Enum.TextXAlignment.Left w1.Parent=head
local w2=Instance.new("TextLabel")
w2.Size=UDim2.new(1,-14,0,30) w2.Position=UDim2.new(0,7,0,24)
w2.BackgroundTransparency=1 w2.Text="NOVA" w2.Font=Enum.Font.GothamBold
w2.TextSize=24 w2.TextColor3=Color3.new(1,1,1) w2.TextXAlignment=Enum.TextXAlignment.Left w2.Parent=head
local w3=Instance.new("TextLabel")
w3.Size=UDim2.new(1,-14,0,16) w3.Position=UDim2.new(0,7,0,56)
w3.BackgroundTransparency=1 w3.Text="V 7.0 • "..GAME_VERSION w3.Font=Enum.Font.Gotham
w3.TextSize=12 w3.TextColor3=THEME.TextDim w3.TextXAlignment=Enum.TextXAlignment.Left w3.Parent=head
local headLine=Instance.new("Frame")
headLine.Size=UDim2.new(1,-14,0,2) headLine.Position=UDim2.new(0,7,0,78)
headLine.BackgroundColor3=THEME.Accent headLine.BorderSizePixel=0 headLine.Active=false headLine.Parent=head

do
    local dragging=false local dragStart, startPos
    track(head.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true dragStart=inp.Position startPos=main.Position
        end
    end))
    track(UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
            local delta=inp.Position-dragStart
            main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end))
end

local nav=Instance.new("Frame")
nav.Size=UDim2.new(1,-14,1,-86-106) nav.Position=UDim2.new(0,7,0,92)
nav.BackgroundTransparency=1 nav.Parent=side
local navList=Instance.new("UIListLayout")
navList.Padding=UDim.new(0,8) navList.SortOrder=Enum.SortOrder.LayoutOrder navList.Parent=nav
local function mkNavBtn(name, order)
    local b=Instance.new("TextButton")
    b.LayoutOrder=order b.Size=UDim2.new(1,0,0,36)
    b.Text=name b.Font=Enum.Font.GothamBold b.TextSize=14
    b.AutoButtonColor=false b.Active=true b.Parent=nav
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,10) c.Parent=b
    local s=Instance.new("UIStroke") s.Color=THEME.Stroke s.Thickness=1 s.Parent=b
    return b
end
local navESP=mkNavBtn("ESP",1) local navAim=mkNavBtn("Aimbot",2) local navMisc=mkNavBtn("Misc",3) local navUtil=mkNavBtn("Utility",4) local navArsenal=mkNavBtn("Arsenal",5)

local foot=Instance.new("Frame")
foot.Size=UDim2.new(1,-14,0,94) foot.Position=UDim2.new(0,7,1,-100)
foot.BackgroundTransparency=1 foot.Parent=side
local discBtn=Instance.new("TextButton")
discBtn.Size=UDim2.new(1,0,0,28) discBtn.Position=UDim2.new(0,0,0,0)
discBtn.Text="DISCORD" discBtn.Font=Enum.Font.GothamBold discBtn.TextSize=13
discBtn.BackgroundColor3=Color3.fromRGB(88,101,242) discBtn.TextColor3=Color3.new(1,1,1)
discBtn.AutoButtonColor=false discBtn.Active=true discBtn.Parent=foot
local dc=Instance.new("UICorner") dc.CornerRadius=UDim.new(0,10) dc.Parent=discBtn
discBtn.MouseButton1Click:Connect(function()
    local copied=false
    pcall(function()
        if typeof(setclipboard)=="function" then
            setclipboard("https://discord.gg/REPLACE-ME")
            copied=true
        end
    end)
    if copied then notify("Discord", "invite copied!")
    else notify("Discord", "https://discord.gg/REPLACE-ME") end
end)
local unloadBtn=Instance.new("TextButton")
unloadBtn.Size=UDim2.new(1,0,0,30) unloadBtn.Position=UDim2.new(0,0,0,32) unloadBtn.Text="UNLOAD"
unloadBtn.Font=Enum.Font.GothamBold unloadBtn.TextSize=14
unloadBtn.BackgroundColor3=Color3.fromRGB(170,40,40) unloadBtn.TextColor3=Color3.new(1,1,1)
unloadBtn.AutoButtonColor=false unloadBtn.Active=true unloadBtn.Parent=foot
local uc=Instance.new("UICorner") uc.CornerRadius=UDim.new(0,10) uc.Parent=unloadBtn
local hintLbl=Instance.new("TextLabel")
hintLbl.Size=UDim2.new(1,0,0,24) hintLbl.Position=UDim2.new(0,0,0,66)
hintLbl.BackgroundTransparency=1 hintLbl.Text="RSHIFT: menu"
hintLbl.Font=Enum.Font.Gotham hintLbl.TextSize=12 hintLbl.TextColor3=THEME.TextDim hintLbl.Parent=foot

local content=Instance.new("Frame")
content.Position=UDim2.new(0,184,0,14) content.Size=UDim2.new(1,-198,1,-28)
content.BackgroundTransparency=1 content.Parent=main

local function mkPage()
    local p=Instance.new("ScrollingFrame")
    p.Size=UDim2.new(1,0,1,0)
    p.BackgroundTransparency=1 p.BorderSizePixel=0
    p.Active=true p.Selectable=true p.ScrollingEnabled=true p.ScrollingDirection=Enum.ScrollingDirection.Y
    p.ScrollBarThickness=7
    p.ScrollBarImageColor3=THEME.Accent
    p.CanvasSize=UDim2.new(0,0,0,0) p.AutomaticCanvasSize=Enum.AutomaticSize.Y p.Parent=content
    local l=Instance.new("UIListLayout")
    l.Padding=UDim.new(0,6) l.HorizontalAlignment=Enum.HorizontalAlignment.Center
    l.SortOrder=Enum.SortOrder.LayoutOrder l.Parent=p
    local pad=Instance.new("UIPadding")
    pad.PaddingTop=UDim.new(0,2) pad.PaddingLeft=UDim.new(0,2) pad.PaddingRight=UDim.new(0,6) pad.PaddingBottom=UDim.new(0,12) pad.Parent=p
    return p
end
local espPage=mkPage() local aimPage=mkPage() local miscPage=mkPage() local utilPage=mkPage() local arsPage=mkPage()
aimPage.Visible=false miscPage.Visible=false utilPage.Visible=false arsPage.Visible=false

local function paintNav(which)
    local function st(b,on)
        if on then b.BackgroundColor3=THEME.Accent b.TextColor3=Color3.new(1,1,1)
        else b.BackgroundColor3=THEME.Item b.TextColor3=THEME.TextDim end
    end
    st(navESP,which=="ESP") st(navAim,which=="Aim") st(navMisc,which=="Misc") st(navUtil,which=="Util") st(navArsenal,which=="Ars")
end
local function setTab(w)
    espPage.Visible=(w=="ESP") aimPage.Visible=(w=="Aim") miscPage.Visible=(w=="Misc") utilPage.Visible=(w=="Util") arsPage.Visible=(w=="Ars")
    espPage.CanvasPosition=Vector2.new(0,0) aimPage.CanvasPosition=Vector2.new(0,0) miscPage.CanvasPosition=Vector2.new(0,0) utilPage.CanvasPosition=Vector2.new(0,0) arsPage.CanvasPosition=Vector2.new(0,0)
    paintNav(w)
end
navESP.MouseButton1Click:Connect(function() setTab("ESP") end)
navAim.MouseButton1Click:Connect(function() setTab("Aim") end)
navMisc.MouseButton1Click:Connect(function() setTab("Misc") end)
navUtil.MouseButton1Click:Connect(function() setTab("Util") end)
navArsenal.MouseButton1Click:Connect(function() setTab("Ars") end)
setTab("ESP")
if ESP_ONLY then navAim.Visible=false end

local function regHandle(id, setFn)
    UIHandles[id]=setFn
end
local function pageHeader(parent, order, text)
    local t=Instance.new("TextLabel")
    t.LayoutOrder=order t.Size=UDim2.new(1,-4,0,26)
    t.BackgroundTransparency=1 t.Text=text t.Font=Enum.Font.GothamBold
    t.TextSize=16 t.TextColor3=Color3.new(1,1,1)
    t.TextXAlignment=Enum.TextXAlignment.Left t.Parent=parent
    return t
end
local function newRow(parent, order, h)
    local r=Instance.new("Frame")
    r.LayoutOrder=order r.Size=UDim2.new(1,-4,0,h or 28)
    r.BackgroundTransparency=1 r.Parent=parent
    local l=Instance.new("UIListLayout")
    l.FillDirection=Enum.FillDirection.Horizontal
    l.Padding=UDim.new(0,6) l.SortOrder=Enum.SortOrder.LayoutOrder l.Parent=r
    return r
end
local function createToggle(parent,order,id,name,default,cb,scale,off)
    local btn=Instance.new("TextButton")
    btn.LayoutOrder=order btn.Size=UDim2.new(scale or 1,off or -4,0,28)
    btn.Font=Enum.Font.GothamBold btn.TextSize=13 btn.AutoButtonColor=false btn.Active=true btn.Parent=parent
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=btn
    local s=Instance.new("UIStroke") s.Color=THEME.Stroke s.Thickness=1 s.Parent=btn
    local on=default
    local function upd()
        if on then btn.Text=name..":  ON" btn.BackgroundColor3=THEME.Accent btn.TextColor3=Color3.new(1,1,1)
        else btn.Text=name..":  OFF" btn.BackgroundColor3=THEME.Item btn.TextColor3=THEME.TextDim end
    end
    local function set(v) on=(v==true) upd() cb(on) end
    btn.MouseButton1Click:Connect(function() set(not on) end)
    upd()
    if id then regHandle(id,set) end
    return btn
end

local function createSlider(parent,order,id,name,min,max,default,cb,accent)
    accent = accent or THEME.Accent
    local f=Instance.new("Frame")
    f.LayoutOrder=order f.Size=UDim2.new(1,-4,0,42)
    f.BackgroundColor3=THEME.Panel f.BorderSizePixel=0 f.Parent=parent
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=f
    local s=Instance.new("UIStroke") s.Color=THEME.Stroke s.Thickness=1 s.Parent=f
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-12,0,18) lbl.Position=UDim2.new(0,6,0,2)
    lbl.BackgroundTransparency=1 lbl.Font=Enum.Font.GothamBold lbl.TextSize=12
    lbl.TextColor3=Color3.new(1,1,1) lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Parent=f
    local bar=Instance.new("TextButton")
    bar.Size=UDim2.new(1,-12,0,12) bar.Position=UDim2.new(0,6,0,24)
    bar.BackgroundColor3=THEME.Item bar.Text="" bar.AutoButtonColor=false bar.Active=true bar.Parent=f
    local bc=Instance.new("UICorner") bc.CornerRadius=UDim.new(0,6) bc.Parent=bar
    local fill=Instance.new("Frame")
    fill.Size=UDim2.new(0,0,1,0) fill.BackgroundColor3=accent fill.BorderSizePixel=0 fill.Active=false fill.Parent=bar
    local fc=Instance.new("UICorner") fc.CornerRadius=UDim.new(0,6) fc.Parent=fill
    local span = math.max(1,(max-min))
    local function upd(v)
        v=math.clamp(math.floor(v),min,max)
        lbl.Text=name..":  "..tostring(v)
        fill.Size=UDim2.new((v-min)/span,0,1,0)
        cb(v)
    end
    upd(default)
    local function setFromX(mx)
        local p0=bar.AbsolutePosition.X local sz=bar.AbsoluteSize.X
        if sz<=0 then return end
        upd(min+(mx-p0)/sz*(max-min))
    end
    bar.MouseButton1Down:Connect(function()
        activeDragFn=setFromX
        local m=UserInputService:GetMouseLocation()
        pcall(setFromX, m.X)
    end)
    if id then regHandle(id,function(v) upd(v) end) end
    return f
end

local function createDropdown(parent,order,id,title,options,current,cb)
    local f=Instance.new("Frame")
    f.LayoutOrder=order f.Size=UDim2.new(1,-4,0,28)
    f.BackgroundTransparency=1 f.Parent=parent
    local closedH=28
    local optH=26 local gap=4
    local listH=#options*optH+(#options-1)*gap
    local main=Instance.new("TextButton")
    main.Size=UDim2.new(1,0,0,closedH)
    main.Font=Enum.Font.GothamBold main.TextSize=12
    main.BackgroundColor3=THEME.Item main.TextColor3=Color3.new(1,1,1)
    main.AutoButtonColor=false main.Active=true main.Parent=f
    local mc2=Instance.new("UICorner") mc2.CornerRadius=UDim.new(0,8) mc2.Parent=main
    local ms2=Instance.new("UIStroke") ms2.Color=THEME.Stroke ms2.Thickness=1 ms2.Parent=main
    local list=Instance.new("Frame")
    list.Size=UDim2.new(1,0,0,listH) list.Position=UDim2.new(0,0,0,closedH+gap)
    list.BackgroundTransparency=1 list.Visible=false list.Parent=f
    local optBtns={}
    local function paintOpts()
        for b,val in pairs(optBtns) do
            if val==current then b.BackgroundColor3=THEME.Accent b.TextColor3=Color3.new(1,1,1)
            else b.BackgroundColor3=THEME.Item b.TextColor3=THEME.TextDim end
        end
        main.Text=title..":  "..current.."  ▾"
    end
    local function close()
        pcall(function()
            list.Visible=false
            f.Size=UDim2.new(1,-4,0,closedH)
            main.Text=title..":  "..current.."  ▾"
        end)
        if openDropClose==close then openDropClose=nil end
    end
    local function set(v)
        for _,nm in ipairs(options) do
            if nm==v then
                current=v paintOpts() cb(v) close()
                return
            end
        end
    end
    for i,nm in ipairs(options) do
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(1,0,0,optH) b.Position=UDim2.new(0,0,0,(i-1)*(optH+gap))
        b.Text=nm b.Font=Enum.Font.GothamBold b.TextSize=12
        b.AutoButtonColor=false b.Active=true b.Parent=list
        local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=b
        local s=Instance.new("UIStroke") s.Color=THEME.Stroke s.Thickness=1 s.Parent=b
        optBtns[b]=nm
        b.MouseButton1Click:Connect(function() set(nm) end)
    end
    main.MouseButton1Click:Connect(function()
        if list.Visible then close()
        else
            if openDropClose and openDropClose~=close then pcall(openDropClose) end
            list.Visible=true
            f.Size=UDim2.new(1,-4,0,closedH+gap+listH)
            main.Text=title..":  "..current.."  ▴"
            openDropClose=close
        end
    end)
    paintOpts()
    if id then regHandle(id,set) end
    return f
end

local function keyDataToName(k)
    if not k then return "?" end
    return k.Name or "?"
end
local function createKeyPicker(parent,order,id,name,currentName,cb)
    local btn=Instance.new("TextButton")
    btn.LayoutOrder=order btn.Size=UDim2.new(1,-4,0,28)
    btn.Font=Enum.Font.GothamBold btn.TextSize=13 btn.BackgroundColor3=THEME.Item
    btn.TextColor3=Color3.new(1,1,1) btn.Text=name..":  "..currentName btn.Active=true btn.Parent=parent
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=btn
    local s=Instance.new("UIStroke") s.Color=THEME.Stroke s.Thickness=1 s.Parent=btn
    local listening=false
    local function set(d)
        btn.Text=name..":  "..keyDataToName(d)
        cb(d)
    end
    btn.MouseButton1Click:Connect(function()
        if listening then return end listening=true btn.Text=name..":  Press key..."
        local conn; conn=UserInputService.InputBegan:Connect(function(inp,gpe)
            if gpe then return end
            local data,disp=nil,""
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then data={Type="Mouse",Button=Enum.UserInputType.MouseButton1,Name="LMB"} disp="LMB"
            elseif inp.UserInputType==Enum.UserInputType.MouseButton2 then data={Type="Mouse",Button=Enum.UserInputType.MouseButton2,Name="RMB"} disp="RMB"
            elseif inp.UserInputType==Enum.UserInputType.MouseButton3 then data={Type="Mouse",Button=Enum.UserInputType.MouseButton3,Name="MMB"} disp="MMB"
            elseif inp.KeyCode~=Enum.KeyCode.Unknown then data={Type="Key",Key=inp.KeyCode,Name=inp.KeyCode.Name} disp=inp.KeyCode.Name end
            if data then listening=false conn:Disconnect() set(data) end
        end)
        track(conn)
    end)
    if id then regHandle(id,set) end
    return btn
end

-- ESP TAB (pairs side by side)
local o=1
pageHeader(espPage,o,"ESP") o=o+1
do local r=newRow(espPage,o); o=o+1
    createToggle(r,1,"ESPEnabled","ESP Enabled",true,function(v) Settings.ESPEnabled=v end,0.5,-3)
    createToggle(r,2,"Boxes","Boxes",true,function(v) Settings.Boxes=v end,0.5,-3)
end
do local r=newRow(espPage,o); o=o+1
    createToggle(r,1,"Names","Names",true,function(v) Settings.Names=v end,0.5,-3)
    createToggle(r,2,"Distance","Distance",true,function(v) Settings.Distance=v end,0.5,-3)
end
do local r=newRow(espPage,o); o=o+1
    createToggle(r,1,"TeamCheck","Team Check",false,function(v) Settings.TeamCheck=v end,0.5,-3)
    createToggle(r,2,"Tracers","Tracers",false,function(v) Settings.Tracers=v end,0.5,-3)
end
do local r=newRow(espPage,o); o=o+1
    createToggle(r,1,"Inventory","Inventory",Profile.inventoryDefault,function(v) Settings.Inventory=v end,0.5,-3)
    createToggle(r,2,"Chams","Chams",false,function(v) Settings.Chams=v end,0.5,-3)
end
createToggle(espPage,o,"HealthBar","Health Bar",false,function(v) Settings.HealthBar=v end) o=o+1
createSlider(espPage,o,"MaxESP","Max ESP Dist",100,5000,Settings.MaxESP,function(v) Settings.MaxESP=v end) o=o+1
createSlider(espPage,o,"OverlayY","Overlay Y-Shift",-100,100,Settings.OverlayY,function(v) Settings.OverlayY=v end) o=o+1

do
    local boxH=Instance.new("TextLabel")
    boxH.LayoutOrder=o o=o+1 boxH.Size=UDim2.new(1,-4,0,18) boxH.BackgroundTransparency=1
    boxH.Text="ESP Color — tap a color" boxH.Font=Enum.Font.GothamBold boxH.TextSize=12 boxH.TextColor3=Color3.new(1,1,1) boxH.Parent=espPage

    local picker=Instance.new("Frame")
    picker.LayoutOrder=o o=o+1 picker.Size=UDim2.new(1,-4,0,168)
    picker.BackgroundColor3=THEME.Panel picker.BorderSizePixel=0 picker.ClipsDescendants=false picker.Parent=espPage
    local pc=Instance.new("UICorner") pc.CornerRadius=UDim.new(0,8) pc.Parent=picker
    local ps=Instance.new("UIStroke") ps.Color=THEME.Stroke ps.Thickness=1 ps.Parent=picker

    local preview=Instance.new("Frame")
    preview.Size=UDim2.new(1,-12,0,18) preview.Position=UDim2.new(0,6,0,6)
    preview.BackgroundColor3=Settings.Color preview.BorderSizePixel=0 preview.Active=false preview.Parent=picker
    local pvc=Instance.new("UICorner") pvc.CornerRadius=UDim.new(0,6) pvc.Parent=preview
    local rgbLbl=Instance.new("TextLabel")
    rgbLbl.Size=UDim2.new(1,-12,0,14) rgbLbl.Position=UDim2.new(0,6,0,26)
    rgbLbl.BackgroundTransparency=1 rgbLbl.Text="RGB: 255, 0, 0" rgbLbl.Font=Enum.Font.Gotham
    rgbLbl.TextSize=11 rgbLbl.TextColor3=THEME.TextDim rgbLbl.Parent=picker

    local COLS, ROWS = 12, 7
    local svBox=Instance.new("Frame")
    svBox.Size=UDim2.new(1,-12,0,70) svBox.Position=UDim2.new(0,6,0,42)
    svBox.BackgroundColor3=Color3.fromRGB(40,40,55) svBox.BorderSizePixel=0 svBox.ClipsDescendants=true svBox.Parent=picker
    local svC=Instance.new("UICorner") svC.CornerRadius=UDim.new(0,6) svC.Parent=svBox

    local cells={}
    for r=0,ROWS-1 do
        for c=0,COLS-1 do
            local cell=Instance.new("Frame")
            cell.Size=UDim2.new(1/COLS,0,1/ROWS,0)
            cell.Position=UDim2.new(c/COLS,0,r/ROWS,0)
            cell.BorderSizePixel=0 cell.Active=false cell.Parent=svBox
            table.insert(cells,{f=cell, sx=c/(COLS-1), vy=1-r/(ROWS-1)})
        end
    end
    local svDot=Instance.new("Frame")
    svDot.AnchorPoint=Vector2.new(0.5,0.5) svDot.Size=UDim2.new(0,12,0,12)
    svDot.BackgroundColor3=Color3.new(1,1,1) svDot.BorderSizePixel=0 svDot.Active=false svDot.ZIndex=10 svDot.Parent=svBox
    local svDC=Instance.new("UICorner") svDC.CornerRadius=UDim.new(1,0) svDC.Parent=svDot
    local svDS=Instance.new("UIStroke") svDS.Color=Color3.new(0,0,0) svDS.Thickness=2 svDS.Parent=svDot
    local svHit=Instance.new("TextButton")
    svHit.Size=UDim2.new(1,0,1,0) svHit.BackgroundTransparency=1 svHit.Text="" svHit.Active=true svHit.ZIndex=5 svHit.Parent=svBox

    local hueBar=Instance.new("Frame")
    hueBar.Size=UDim2.new(1,-12,0,12) hueBar.Position=UDim2.new(0,6,0,118)
    hueBar.BorderSizePixel=0 hueBar.ClipsDescendants=true hueBar.Parent=picker
    local hbC=Instance.new("UICorner") hbC.CornerRadius=UDim.new(0,6) hbC.Parent=hueBar
    local SEG=30
    for i=0,SEG-1 do
        local s=Instance.new("Frame")
        s.Size=UDim2.new(1/SEG,0,1,0) s.Position=UDim2.new(i/SEG,0,0,0)
        s.BackgroundColor3=Color3.fromHSV(i/SEG,1,1) s.BorderSizePixel=0 s.Active=false s.Parent=hueBar
    end
    local hueKnob=Instance.new("Frame")
    hueKnob.AnchorPoint=Vector2.new(0.5,0.5) hueKnob.Size=UDim2.new(0,4,1,0)
    hueKnob.BackgroundColor3=Color3.new(1,1,1) hueKnob.BorderSizePixel=0 hueKnob.Active=false hueKnob.ZIndex=10 hueKnob.Parent=hueBar
    local hueHit=Instance.new("TextButton")
    hueHit.Size=UDim2.new(1,0,1,0) hueHit.BackgroundTransparency=1 hueHit.Text="" hueHit.Active=true hueHit.ZIndex=5 hueHit.Parent=hueBar

    local pal=Instance.new("Frame")
    pal.Size=UDim2.new(1,-12,0,20) pal.Position=UDim2.new(0,6,0,136)
    pal.BackgroundTransparency=1 pal.Parent=picker
    local quick={
        Color3.fromRGB(255,0,0),Color3.fromRGB(255,128,0),Color3.fromRGB(255,255,0),
        Color3.fromRGB(0,255,0),Color3.fromRGB(0,255,255),Color3.fromRGB(0,128,255),
        Color3.fromRGB(128,0,255),Color3.fromRGB(255,0,255),Color3.fromRGB(255,255,255),
        Color3.fromRGB(25,25,25),
    }
    local hue,sat,val = 0,1,1
    local function paintSV()
        for _,cell in ipairs(cells) do
            cell.f.BackgroundColor3=Color3.fromHSV(hue,cell.sx,cell.vy)
        end
    end
    local function applyAll()
        Settings.Color=Color3.fromHSV(hue,sat,val)
        preview.BackgroundColor3=Settings.Color
        rgbLbl.Text=string.format("RGB: %d, %d, %d", math.floor(Settings.Color.R*255+0.5), math.floor(Settings.Color.G*255+0.5), math.floor(Settings.Color.B*255+0.5))
        svDot.Position=UDim2.new(sat,0,1-val,0)
        hueKnob.Position=UDim2.new(hue,0,0.5,0)
    end
    local function setSV(mx,my)
        local p0=svBox.AbsolutePosition local sz=svBox.AbsoluteSize
        if sz.X<=0 or sz.Y<=0 then return end
        sat=math.clamp((mx-p0.X)/sz.X,0,1)
        val=1-math.clamp((my-p0.Y)/sz.Y,0,1)
        applyAll()
    end
    local function setHue(mx)
        local p0=hueBar.AbsolutePosition local sz=hueBar.AbsoluteSize
        if sz.X<=0 then return end
        hue=math.clamp((mx-p0.X)/sz.X,0,1)
        paintSV() applyAll()
    end
    svHit.MouseButton1Down:Connect(function()
        activeDragFn=setSV
        local m=UserInputService:GetMouseLocation()
        pcall(setSV, m.X, m.Y)
    end)
    hueHit.MouseButton1Down:Connect(function()
        activeDragFn=setHue
        pcall(setHue, UserInputService:GetMouseLocation().X)
    end)
    for i,col in ipairs(quick) do
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(0.096,0,1,0) b.Position=UDim2.new((i-1)*0.101,0,0,0)
        b.BackgroundColor3=col b.Text="" b.AutoButtonColor=false b.Active=true b.Parent=pal
        local cc=Instance.new("UICorner") cc.CornerRadius=UDim.new(0,6) cc.Parent=b
        b.MouseButton1Click:Connect(function()
            local h,s,v=col:ToHSV() hue=h sat=s val=v
            paintSV() applyAll()
        end)
    end
    paintSV() applyAll()
    regHandle("Color", function(c)
        if typeof(c)=="Color3" then
            local h,s,v=c:ToHSV() hue=h sat=s val=v
            paintSV() applyAll()
        end
    end)
end

-- AIM TAB with sub-tabs: Aimbot | Triggerbot (skipped in ESP-only mode)
if not ESP_ONLY then
local aimSub = "bot"
local aimBotBox = Instance.new("Frame")
aimBotBox.BackgroundTransparency = 1
aimBotBox.LayoutOrder = 2
aimBotBox.Size = UDim2.new(1,-4,0,0)
aimBotBox.AutomaticSize = Enum.AutomaticSize.Y
aimBotBox.Parent = aimPage
do local abbList = Instance.new("UIListLayout")
abbList.Padding = UDim.new(0,6) abbList.HorizontalAlignment = Enum.HorizontalAlignment.Center
abbList.SortOrder = Enum.SortOrder.LayoutOrder abbList.Parent = aimBotBox
end
local trigBox = Instance.new("Frame")
trigBox.BackgroundTransparency = 1
trigBox.LayoutOrder = 3
trigBox.Size = UDim2.new(1,-4,0,0)
trigBox.AutomaticSize = Enum.AutomaticSize.Y
trigBox.Visible = false
trigBox.Parent = aimPage
do local trbList = Instance.new("UIListLayout")
trbList.Padding = UDim.new(0,6) trbList.HorizontalAlignment = Enum.HorizontalAlignment.Center
trbList.SortOrder = Enum.SortOrder.LayoutOrder trbList.Parent = trigBox
end
do local r = newRow(aimPage, 1)
    local b1 = Instance.new("TextButton")
    b1.LayoutOrder = 1 b1.Size = UDim2.new(0.5,-3,0,28)
    b1.Text = "AIMBOT" b1.Font = Enum.Font.GothamBold b1.TextSize = 13
    b1.AutoButtonColor = false b1.Active = true b1.Parent = r
    local c1 = Instance.new("UICorner") c1.CornerRadius = UDim.new(0,8) c1.Parent = b1
    local b2 = Instance.new("TextButton")
    b2.LayoutOrder = 2 b2.Size = UDim2.new(0.5,-3,0,28)
    b2.Text = "TRIGGER" b2.Font = Enum.Font.GothamBold b2.TextSize = 13
    b2.AutoButtonColor = false b2.Active = true b2.Parent = r
    local c2 = Instance.new("UICorner") c2.CornerRadius = UDim.new(0,8) c2.Parent = b2
    local function paintSub()
        if aimSub == "bot" then
            b1.BackgroundColor3 = THEME.Accent b1.TextColor3 = Color3.new(1,1,1)
            b2.BackgroundColor3 = THEME.Item b2.TextColor3 = THEME.TextDim
        else
            b2.BackgroundColor3 = THEME.Accent b2.TextColor3 = Color3.new(1,1,1)
            b1.BackgroundColor3 = THEME.Item b1.TextColor3 = THEME.TextDim
        end
    end
    local function showSub(w)
        aimSub = w
        aimBotBox.Visible = (w == "bot")
        trigBox.Visible = (w == "trig")
        paintSub()
    end
    b1.MouseButton1Click:Connect(function() showSub("bot") end)
    b2.MouseButton1Click:Connect(function() showSub("trig") end)
    paintSub()
end
local ab=1
pageHeader(aimBotBox,ab,"Aimbot") ab=ab+1
do local r=newRow(aimBotBox,ab); ab=ab+1
    createToggle(r,1,"AimEnabled","Aimbot",false,function(v) Settings.AimEnabled=v aimingOn=false end,0.5,-3)
    createToggle(r,2,"ShowFOV","Show FOV",true,function(v) Settings.ShowFOV=v end,0.5,-3)
end
createDropdown(aimBotBox,ab,"AimMethod","Method",{"Camera","Mouse","Silent"},Settings.AimMethod,function(v) Settings.AimMethod=v if v=="Silent" then silentMouse.install(true) end end) ab=ab+1
createDropdown(aimBotBox,ab,"AimMode","Mode",{"Hold","Toggle"},Settings.AimMode,function(v) Settings.AimMode=v aimingOn=false end) ab=ab+1
createKeyPicker(aimBotBox,ab,"AimKey","Hold Key","RMB",function(d) Settings.AimKey=d aimingOn=false kb.refresh() end) ab=ab+1
createSlider(aimBotBox,ab,"FOV","FOV",20,500,Settings.FOV,function(v) Settings.FOV=v end) ab=ab+1
createSlider(aimBotBox,ab,"Smoothing","Smoothing",1,20,Settings.Smoothing,function(v) Settings.Smoothing=v end) ab=ab+1
createSlider(aimBotBox,ab,"Prediction","Prediction",0,20,Settings.Prediction,function(v) Settings.Prediction=v end) ab=ab+1
createDropdown(aimBotBox,ab,"Target","Target",{"Head","HRP","Closest"},Settings.Target,function(v) Settings.Target=v end) ab=ab+1
createDropdown(aimBotBox,ab,"Priority","Priority",{"Closest","Low HP"},Settings.Priority,function(v) Settings.Priority=v end) ab=ab+1
do local r=newRow(aimBotBox,ab); ab=ab+1
    createToggle(r,1,"AimTeamCheck","Team Check",true,function(v) Settings.AimTeamCheck=v end,0.5,-3)
    createToggle(r,2,"WallCheck","Wall Check",true,function(v) Settings.WallCheck=v end,0.5,-3)
end
createToggle(aimBotBox,ab,"AimLock","Target Lock",false,function(v) Settings.AimLock=v lockedPlayer=nil end) ab=ab+1
createToggle(aimBotBox,ab,"NoKnock","No Knocked",true,function(v) Settings.NoKnock=v end) ab=ab+1
createSlider(aimBotBox,ab,"MaxDistance","Max Distance",100,5000,Settings.MaxDistance,function(v) Settings.MaxDistance=v end) ab=ab+1
local tc=1
pageHeader(trigBox,tc,"Triggerbot") tc=tc+1
createToggle(trigBox,tc,"TrigEnabled","Triggerbot",false,function(v) Settings.TrigEnabled=v trigAcquireT=0 kb.refresh() end) tc=tc+1
createDropdown(trigBox,tc,"TrigMode","Mode",{"Always","Hold Key"},Settings.TrigMode,function(v) Settings.TrigMode=v trigAcquireT=0 end) tc=tc+1
createDropdown(trigBox,tc,"TrigTarget","Hit Part",{"Any","Head","HRP"},Settings.TrigTarget,function(v) Settings.TrigTarget=v trigAcquireT=0 end) tc=tc+1
do local r=newRow(trigBox,tc); tc=tc+1
    createToggle(r,1,"TrigTeamCheck","Team Check",true,function(v) Settings.TrigTeamCheck=v end,0.5,-3)
    createToggle(r,2,"TrigNoKnock","No Knocked",true,function(v) Settings.TrigNoKnock=v end,0.5,-3)
end
createSlider(trigBox,tc,"TrigDelay","Reaction Delay (ms)",0,500,Settings.TrigDelay,function(v) Settings.TrigDelay=v trigAcquireT=0 end) tc=tc+1
do
    local info=Instance.new("TextLabel")
    info.LayoutOrder=tc tc=tc+1 info.Size=UDim2.new(1,-4,0,30)
    info.BackgroundTransparency=1 info.Text="Fires when the crosshair is on a valid target."
    info.Font=Enum.Font.Gotham info.TextSize=11 info.TextColor3=THEME.TextDim
    info.TextWrapped=true info.Parent=trigBox
end
trigMsgLbl=Instance.new("TextLabel")
trigMsgLbl.LayoutOrder=tc tc=tc+1 trigMsgLbl.Size=UDim2.new(1,-4,0,16) trigMsgLbl.BackgroundTransparency=1
trigMsgLbl.Text="status: off" trigMsgLbl.Font=Enum.Font.Gotham
trigMsgLbl.TextSize=11 trigMsgLbl.TextColor3=THEME.TextDim trigMsgLbl.TextXAlignment=Enum.TextXAlignment.Left trigMsgLbl.Parent=trigBox
end -- aim tab

-- UTILITY STATE + LOOPS (movement, world)
local Util = {WalkSpeed=16, JumpPower=50, InfJump=false, Fly=false, FlySpeed=60,
    Noclip=false, Fullbright=false, CamFOV=70, ClickTP=false, Crosshair=false}
local origLight = nil
local lastUtilSync = 0

local function stopFly()
    local char=LocalPlayer.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if hrp then pcall(function() hrp.Anchored=false end) end
end

local function setFullbright(on)
    if on then
        if not origLight then
            origLight={}
            pcall(function()
                origLight.Brightness=Lighting.Brightness
                origLight.Ambient=Lighting.Ambient
                origLight.OutdoorAmbient=Lighting.OutdoorAmbient
                origLight.FogEnd=Lighting.FogEnd
                origLight.GlobalShadows=Lighting.GlobalShadows
            end)
        end
        pcall(function()
            Lighting.Brightness=2
            Lighting.Ambient=Color3.new(1,1,1)
            Lighting.OutdoorAmbient=Color3.new(1,1,1)
            Lighting.FogEnd=100000
            Lighting.GlobalShadows=false
        end)
    elseif origLight then
        pcall(function()
            Lighting.Brightness=origLight.Brightness
            Lighting.Ambient=origLight.Ambient
            Lighting.OutdoorAmbient=origLight.OutdoorAmbient
            Lighting.FogEnd=origLight.FogEnd
            Lighting.GlobalShadows=origLight.GlobalShadows
        end)
    end
end

local function fpsBoost()
    pcall(function()
        Lighting.GlobalShadows=false
        for _,d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("BasePart") then
                d.Material=Enum.Material.SmoothPlastic
                d.CastShadow=false
            elseif d:IsA("Decal") or d:IsA("Texture") then
                d.Transparency=1
            elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
                or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
                d.Enabled=false
            end
        end
    end)
    notify("Utility", "fps boost applied")
end

track(RunService.Heartbeat:Connect(function(dt)
    if Unloaded or runStale() then return end
    if not Util.Fly then return end
    local char=LocalPlayer.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    local cam=Workspace.CurrentCamera
    if not hrp or not cam then return end
    dt=dt or 0.016
    pcall(function()
        hrp.Anchored=true
        hrp.AssemblyLinearVelocity=Vector3.new()
        hrp.AssemblyAngularVelocity=Vector3.new()
        local cf=cam.CFrame
        local move=Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move=move+cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move=move-cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move=move-cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move=move+cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move=move+Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.C) then move=move-Vector3.new(0,1,0) end
        if move.Magnitude>0.01 then move=move.Unit end
        hrp.CFrame=hrp.CFrame+move*Util.FlySpeed*math.min(dt,0.1)
    end)
end))
track(RunService.Stepped:Connect(function()
    if Unloaded or runStale() then return end
    if not Util.Noclip then return end
    local char=LocalPlayer.Character
    if not char then return end
    for _,p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide=false end
    end
end))
track(RunService.Heartbeat:Connect(function()
    if Unloaded or runStale() then return end
    local nowC=os.clock()
    if nowC-lastUtilSync < 0.5 then return end
    lastUtilSync=nowC
    local hum=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            if hum.WalkSpeed~=Util.WalkSpeed then hum.WalkSpeed=Util.WalkSpeed end
            if hum.UseJumpPower and hum.JumpPower~=Util.JumpPower then hum.JumpPower=Util.JumpPower end
        end)
    end
    local cam=Workspace.CurrentCamera
    if cam and cam.FieldOfView~=Util.CamFOV then
        pcall(function() cam.FieldOfView=Util.CamFOV end)
    end
end))
track(UserInputService.JumpRequest:Connect(function()
    if Unloaded or runStale() then return end
    if not Util.InfJump then return end
    local hum=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
end))
do
    local okM, utilMouse = pcall(function() return LocalPlayer:GetMouse() end)
    if okM and utilMouse then
        track(utilMouse.Button1Down:Connect(function()
            if Unloaded or runStale() then return end
            if not Util.ClickTP then return end
            local ctrl=false
            pcall(function()
                ctrl=UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                    or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
            end)
            if not ctrl then return end
            local hrp=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and utilMouse.Hit then
                pcall(function() hrp.CFrame=CFrame.new(utilMouse.Hit.Position+Vector3.new(0,3,0)) end)
                notify("Utility", "teleported")
            end
        end))
    end
end

-- ARSENAL-ONLY (silent aim, gun mods, hitbox expander)
local ARS = {SilentEnabled=false, SilentTeam=true, SilentTarget="Head", SilentFOV=120, SilentChance=100, SilentProj=false,
    NoSpread=false, NoRecoil=false, RapidFire=false, FastReload=false, FullAuto=false,
    HitboxExpand=false, HitboxSize=3}
local silentHooked, oldSilentCall = false, nil
local canHook = typeof(hookmetamethod)=="function" and typeof(getnamecallmethod)=="function"
    and typeof(checkcaller)=="function"
local origSizes = {}
local lastGunSweep = 0
local arsMsgLbl, gunMsgLbl = nil, nil
local function arsMsg(t) pcall(function() if arsMsgLbl then arsMsgLbl.Text=t end end) end
local function gunMsg(t) pcall(function() if gunMsgLbl then gunMsgLbl.Text=t end end) end

local function silentScreenDist(sx,sy,mx,my)
    local dx=sx-mx local dy=sy-my
    return math.sqrt(dx*dx+dy*dy)
end
local function silentMousePos()
    local m=UserInputService:GetMouseLocation()
    local cam=Workspace.CurrentCamera
    if not cam then return Vector2.new(m.X,m.Y) end
    local asz=overlayGui.AbsoluteSize
    local vpsz=cam.ViewportSize
    return Vector2.new(m.X-(asz.X-vpsz.X), m.Y-(asz.Y-vpsz.Y))
end
local function getSilentTarget(cam, mousePos)
    local best, bestD = nil, ARS.SilentFOV
    local myHrp=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local maxD2=Settings.MaxDistance*Settings.MaxDistance
    for _,p in ipairs(cachedPlayers) do
        if p~=LocalPlayer then
            local ch=p.Character
            local hum=ch and ch:FindFirstChildOfClass("Humanoid")
            if ch and hum and hum.Health>0 then
                if not (ARS.SilentTeam and p.Team and LocalPlayer.Team and p.Team==LocalPlayer.Team) then
                    local part=ch:FindFirstChild(ARS.SilentTarget=="Hitbox" and "Hitbox" or "Head")
                        or ch:FindFirstChild("HumanoidRootPart")
                    if part then
                        local sp,ok=cam:WorldToViewportPoint(part.Position)
                        if ok then
                            local d=silentScreenDist(sp.X,sp.Y,mousePos.X,mousePos.Y)
                            if d<=bestD then
                                local inRange=true
                                if myHrp then
                                    local dx=myHrp.Position.X-part.Position.X
                                    local dy=myHrp.Position.Y-part.Position.Y
                                    local dz=myHrp.Position.Z-part.Position.Z
                                    if dx*dx+dy*dy+dz*dz > maxD2 then inRange=false end
                                end
                                if inRange then best,bestD=part,d end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end
local function setSilentHook(on)
    local function patchArsenalShot(remoteName, args, part)
        local ok=false
        if remoteName=="HitPart" then
            pcall(function() args[1]=part ok=true end)
        elseif remoteName=="Fire" then
            pcall(function() args[1]=part.Position ok=true end)
        elseif remoteName=="Trail" then
            pcall(function()
                if type(args[1])=="table" and type(args[1][5])=="string" then
                    args[1][6]=part
                    args[1][2]=part.Position
                    ok=true
                end
            end)
        elseif ARS.SilentProj and remoteName=="CreateProjectile" then
            pcall(function()
                args[18]=part args[19]=part.Position args[17]=part.Position
                args[4]=part.CFrame args[10]=part.Position args[3]=part.Position
                ok=true
            end)
        elseif ARS.SilentProj and remoteName=="ReplicateProjectile" then
            pcall(function()
                if type(args[1])=="table" then
                    args[1][3]=part.Position args[1][4]=part.Position args[1][10]=part.Position
                    ok=true
                end
            end)
        end
        return ok
    end
    arsMsg(on and "silent aim: on" or "silent aim: off")
    if on and not silentHooked then
        if not canHook then arsMsg("needs hookmetamethod executor") return end
        if typeof(newcclosure)~="function" then arsMsg("no newcclosure: hook may fail") end
        local ok=pcall(function()
            local nc=(typeof(newcclosure)=="function" and newcclosure) or function(f) return f end
            oldSilentCall=hookmetamethod(game, "__namecall", nc(function(self, ...)
                local method=nil
                pcall(function() method=getnamecallmethod() end)
                if method=="FireServer" then
                    local okc=false
                    pcall(function() okc=not checkcaller() end)
                    if okc and ARS.SilentEnabled and not Unloaded and not runStale() then
                        local rname=nil
                        pcall(function() rname=tostring(self) end)
                        if rname=="HitPart" or rname=="Fire" or rname=="Trail"
                            or rname=="CreateProjectile" or rname=="ReplicateProjectile" then
                            local cam=Workspace.CurrentCamera
                            if cam then
                                local part=getSilentTarget(cam, silentMousePos())
                                if part and math.random(100)<=ARS.SilentChance then
                                    local args={...}
                                    if patchArsenalShot(rname, args, part) then
                                        ARS.SilentHits=(ARS.SilentHits or 0)+1
                                        ARS.SilentLast=os.clock()
                                        return oldSilentCall(self, (table.unpack or unpack)(args))
                                    end
                                end
                            end
                        end
                    end
                end
                return oldSilentCall(self, ...)
            end))
            silentHooked=true
        end)
        if not ok or not silentHooked then arsMsg("hook failed") end
    end
end
local function applyGunMods()
    local weapons=nil
    pcall(function() weapons=ReplicatedStorage:FindFirstChild("Weapons") end)
    if not weapons then gunMsg("no Weapons folder") return 0 end
    local n=0
    for _,d in ipairs(weapons:GetDescendants()) do
        local okName, nm = pcall(function() return d.Name end)
        if okName and type(nm)=="string" then
            if ARS.NoSpread and (nm=="MaxSpread" or nm=="Spread") then
                if pcall(function() d.Value=0 end) then n=n+1 end
            elseif ARS.RapidFire and nm=="FireRate" then
                if pcall(function() d.Value=0.05 end) then n=n+1 end
            elseif ARS.FastReload and nm=="ReloadTime" then
                if pcall(function() d.Value=0.1 end) then n=n+1 end
            elseif ARS.FullAuto and nm=="Auto" then
                if pcall(function() d.Value=true end) then n=n+1 end
            elseif ARS.NoRecoil and nm=="RecoilControl" then
                if pcall(function() d.Value=0 end) then n=n+1 end
            end
        end
    end
    gunMsg("gun mods applied ("..n..")")
    return n
end
local function applyHitboxes()
    if not ARS.HitboxExpand then
        for part,sz in pairs(origSizes) do
            pcall(function() if part.Parent then part.Size=sz end end)
            origSizes[part]=nil
        end
        return
    end
    for _,p in ipairs(cachedPlayers) do
        if p~=LocalPlayer then
            local enemy=true
            if p.Team and LocalPlayer.Team and p.Team==LocalPlayer.Team then enemy=false end
            local ch=p.Character
            if enemy and ch then
                for _,pn in ipairs({"Head","Hitbox"}) do
                    local part=ch:FindFirstChild(pn)
                    if part and part:IsA("BasePart") then
                        if not origSizes[part] then origSizes[part]=part.Size end
                        pcall(function()
                            part.Size=Vector3.new(ARS.HitboxSize,ARS.HitboxSize,ARS.HitboxSize)
                            part.CanCollide=false
                        end)
                    end
                end
            end
        end
    end
    for part,sz in pairs(origSizes) do
        if not part.Parent then origSizes[part]=nil end
    end
end
track(RunService.Heartbeat:Connect(function()
    if Unloaded or runStale() then return end
    local nowC=os.clock()
    if nowC-lastGunSweep < 1 then return end
    lastGunSweep=nowC
    if ARS.NoSpread or ARS.NoRecoil or ARS.RapidFire or ARS.FastReload or ARS.FullAuto then
        applyGunMods()
    end
    if ARS.HitboxExpand or next(origSizes)~=nil then applyHitboxes() end
    if ARS.SilentEnabled and silentHooked then
        if (ARS.SilentHits or 0)>0 then
            arsMsg("silent: on | redirected: "..ARS.SilentHits.." | last "..math.floor(nowC-(ARS.SilentLast or nowC)).."s ago")
        else
            arsMsg("silent: on | no redirect yet")
        end
    end
end))

-- KEYBINDS WINDOW (Misc toggle; live names via kb.refresh)
do
    local w=Instance.new("Frame")
    w.Name="NovaKeys" w.Position=UDim2.new(0,16,0,120)
    w.Size=UDim2.new(0,190,0,122) w.BackgroundColor3=THEME.BG w.BorderSizePixel=0
    w.Active=true w.Draggable=true w.Visible=kb.on w.Parent=gui
    pcall(function() w:SetAttribute("nx",1) end)
    local wc=Instance.new("UICorner") wc.CornerRadius=UDim.new(0,10) wc.Parent=w
    local ws=Instance.new("UIStroke") ws.Color=THEME.Stroke ws.Thickness=1 ws.Parent=w
    local t=Instance.new("TextLabel")
    t.Size=UDim2.new(1,0,0,24) t.BackgroundTransparency=1 t.Text="KEYBINDS"
    t.Font=Enum.Font.GothamBold t.TextSize=13 t.TextColor3=Color3.new(1,1,1) t.Parent=w
    local function kbRow(y)
        local l=Instance.new("TextLabel")
        l.Size=UDim2.new(1,-16,0,18) l.Position=UDim2.new(0,8,0,y)
        l.BackgroundTransparency=1 l.Text="" l.Font=Enum.Font.Gotham l.TextSize=12
        l.TextColor3=THEME.TextDim l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=w
        return l
    end
    kb.win=w
    kb.lines.aim=kbRow(28) kb.lines.menu=kbRow(48) kb.lines.panic=kbRow(68) kb.lines.trig=kbRow(88)
end
function kb.refresh()
    pcall(function()
        if kb.lines.aim then kb.lines.aim.Text="Aim: "..keyDataToName(Settings.AimKey) end
        if kb.lines.menu then kb.lines.menu.Text="Menu: "..keyDataToName(Settings.MenuKey) end
        if kb.lines.panic then kb.lines.panic.Text="Panic: "..keyDataToName(Settings.PanicKey) end
        if kb.lines.trig then kb.lines.trig.Text="Trigger: "..(Settings.TrigEnabled and "ON" or "OFF") end
    end)
end
kb.refresh()

-- MISC TAB
local mo=1
pageHeader(miscPage,mo,"Misc") mo=mo+1
local statLbl=Instance.new("TextLabel")
statLbl.LayoutOrder=mo mo=mo+1 statLbl.Size=UDim2.new(1,-4,0,20) statLbl.BackgroundTransparency=1
statLbl.Text="NOVA v7.0 • "..GAME_VERSION statLbl.Font=Enum.Font.GothamBold
statLbl.TextSize=13 statLbl.TextColor3=Color3.new(1,1,1) statLbl.TextXAlignment=Enum.TextXAlignment.Left statLbl.Parent=miscPage
local perfLbl=Instance.new("TextLabel")
perfLbl.LayoutOrder=mo mo=mo+1 perfLbl.Size=UDim2.new(1,-4,0,18) perfLbl.BackgroundTransparency=1
perfLbl.Text="FPS: -- • Players: --" perfLbl.Font=Enum.Font.Gotham
perfLbl.TextSize=12 perfLbl.TextColor3=THEME.TextDim perfLbl.TextXAlignment=Enum.TextXAlignment.Left perfLbl.Parent=miscPage
createKeyPicker(miscPage,mo,"PanicKey","Panic Key","Delete",function(d) Settings.PanicKey=d kb.refresh() end) mo=mo+1
createKeyPicker(miscPage,mo,"MenuKey","Menu Key","RightShift",function(d) Settings.MenuKey=d kb.refresh() pcall(function() hintLbl.Text=(d.Name or "?")..": menu" end) end) mo=mo+1
createToggle(miscPage,mo,"AFKProtect","Anti-AFK",true,function(v) Settings.AFKProtect=v end) mo=mo+1
createToggle(miscPage,mo,"Keybinds","Keybinds Window",true,function(v) kb.on=v if kb.win then kb.win.Visible=v end end) mo=mo+1
createSlider(miscPage,mo,"FPSCap","FPS Cap",30,240,Settings.FPSCap,function(v) Settings.FPSCap=v pcall(function() if typeof(setfpscap)=="function" then setfpscap(v) end end) end) mo=mo+1
local cfgNameLbl=Instance.new("TextLabel")
cfgNameLbl.LayoutOrder=mo mo=mo+1 cfgNameLbl.Size=UDim2.new(1,-4,0,16) cfgNameLbl.BackgroundTransparency=1
cfgNameLbl.Text="Config name" cfgNameLbl.Font=Enum.Font.GothamBold
cfgNameLbl.TextSize=12 cfgNameLbl.TextColor3=Color3.new(1,1,1) cfgNameLbl.TextXAlignment=Enum.TextXAlignment.Left cfgNameLbl.Parent=miscPage
local cfgNameBox=Instance.new("TextBox")
cfgNameBox.LayoutOrder=mo mo=mo+1 cfgNameBox.Size=UDim2.new(1,-4,0,28)
cfgNameBox.BackgroundColor3=THEME.Item cfgNameBox.Text="" cfgNameBox.PlaceholderText="e.g. sb-main"
cfgNameBox.Font=Enum.Font.Gotham cfgNameBox.TextSize=13 cfgNameBox.TextColor3=Color3.new(1,1,1)
cfgNameBox.ClearTextOnFocus=false cfgNameBox.Parent=miscPage
local cfgNameBoxC=Instance.new("UICorner") cfgNameBoxC.CornerRadius=UDim.new(0,8) cfgNameBoxC.Parent=cfgNameBox
do local r=newRow(miscPage,mo); mo=mo+1
    local rj=Instance.new("TextButton")
    rj.LayoutOrder=1 rj.Size=UDim2.new(0.5,-3,0,30) rj.Text="Rejoin"
    rj.Font=Enum.Font.GothamBold rj.TextSize=13 rj.BackgroundColor3=THEME.Item
    rj.TextColor3=Color3.new(1,1,1) rj.AutoButtonColor=false rj.Active=true rj.Parent=r
    local rjc=Instance.new("UICorner") rjc.CornerRadius=UDim.new(0,8) rjc.Parent=rj
    rj.MouseButton1Click:Connect(function()
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end)
    local cfgb=Instance.new("TextButton")
    cfgb.LayoutOrder=2 cfgb.Size=UDim2.new(0.5,-3,0,30) cfgb.Text="Save Config"
    cfgb.Font=Enum.Font.GothamBold cfgb.TextSize=13 cfgb.BackgroundColor3=THEME.Item
    cfgb.TextColor3=Color3.new(1,1,1) cfgb.AutoButtonColor=false cfgb.Active=true cfgb.Parent=r
    local cfb=Instance.new("UICorner") cfb.CornerRadius=UDim.new(0,8) cfb.Parent=cfgb
    cfgb.MouseButton1Click:Connect(function() saveConfig() end)
end
do local r=newRow(miscPage,mo); mo=mo+1
    local ldb=Instance.new("TextButton")
    ldb.LayoutOrder=1 ldb.Size=UDim2.new(0.5,-3,0,30) ldb.Text="Load Config"
    ldb.Font=Enum.Font.GothamBold ldb.TextSize=13 ldb.BackgroundColor3=THEME.Item
    ldb.TextColor3=Color3.new(1,1,1) ldb.AutoButtonColor=false ldb.Active=true ldb.Parent=r
    local ldc=Instance.new("UICorner") ldc.CornerRadius=UDim.new(0,8) ldc.Parent=r
    ldb.MouseButton1Click:Connect(function() loadConfig() end)
end
local cfgMsg=Instance.new("TextLabel")
cfgMsg.LayoutOrder=mo mo=mo+1 cfgMsg.Size=UDim2.new(1,-4,0,16) cfgMsg.BackgroundTransparency=1
cfgMsg.Text=canFile and "" or "configs need file API" cfgMsg.Font=Enum.Font.Gotham
cfgMsg.TextSize=11 cfgMsg.TextColor3=THEME.TextDim cfgMsg.TextXAlignment=Enum.TextXAlignment.Left cfgMsg.Parent=miscPage
local function cfgCleanName(s)
    s=tostring(s or "")
    s=s:gsub("[^%w%-_]","_"):sub(1,24)
    if s=="" then s="default" end
    return s
end
local function cfgFileFor(name)
    return "nova_cfg_"..cfgCleanName(name)..".json"
end
local function keyToSave(k)
    if not k then return nil end
    if k.Type=="Mouse" then return {t="M", n=k.Name} end
    if k.Type=="Key" and k.Key then return {t="K", n=k.Key.Name} end
    return nil
end
local function keyFromSave(s)
    if type(s)~="table" or type(s.n)~="string" then return nil end
    if s.t=="M" then
        local ok, e = pcall(function() return Enum.UserInputType[s.n] end)
        if ok and e then return {Type="Mouse", Button=e, Name=s.n} end
    elseif s.t=="K" then
        local ok, e = pcall(function() return Enum.KeyCode[s.n] end)
        if ok and e then return {Type="Key", Key=e, Name=s.n} end
    end
    return nil
end
function saveConfig()
    if not canFile then cfgMsg.Text="no file API" return end
    local c=Settings.Color
    local data={
        ESPEnabled=Settings.ESPEnabled, Boxes=Settings.Boxes, Names=Settings.Names,
        Distance=Settings.Distance, TeamCheck=Settings.TeamCheck,
        MaxESP=Settings.MaxESP, OverlayY=Settings.OverlayY, Tracers=Settings.Tracers, Inventory=Settings.Inventory,
        Color={math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5)},
        AimEnabled=Settings.AimEnabled, AimMethod=Settings.AimMethod, AimMode=Settings.AimMode,
        FOV=Settings.FOV, ShowFOV=Settings.ShowFOV, Smoothing=Settings.Smoothing,
        Target=Settings.Target, Priority=Settings.Priority, AimTeamCheck=Settings.AimTeamCheck,
        WallCheck=Settings.WallCheck, NoKnock=Settings.NoKnock, AFKProtect=Settings.AFKProtect,
        TrigEnabled=Settings.TrigEnabled, TrigMode=Settings.TrigMode, TrigTarget=Settings.TrigTarget,
        TrigTeamCheck=Settings.TrigTeamCheck, TrigNoKnock=Settings.TrigNoKnock,
        TrigDelay=Settings.TrigDelay,
        Chams=Settings.Chams, AimLock=Settings.AimLock, Crosshair=Util.Crosshair,
        HealthBar=Settings.HealthBar, Prediction=Settings.Prediction,
        Keybinds=kb.on, FPSCap=Settings.FPSCap,
        SilentEnabled=ARS.SilentEnabled, SilentTeam=ARS.SilentTeam, SilentTarget=ARS.SilentTarget,
        SilentFOV=ARS.SilentFOV, SilentChance=ARS.SilentChance, SilentProj=ARS.SilentProj,
        NoSpread=ARS.NoSpread, NoRecoil=ARS.NoRecoil, RapidFire=ARS.RapidFire,
        FastReload=ARS.FastReload, FullAuto=ARS.FullAuto,
        HitboxExpand=ARS.HitboxExpand, HitboxSize=ARS.HitboxSize,
        MaxDistance=Settings.MaxDistance,
        WalkSpeed=Util.WalkSpeed, JumpPower=Util.JumpPower, InfJump=Util.InfJump,
        Fly=Util.Fly, FlySpeed=Util.FlySpeed, Noclip=Util.Noclip,
        Fullbright=Util.Fullbright, CamFOV=Util.CamFOV, ClickTP=Util.ClickTP,
        AimKey=keyToSave(Settings.AimKey), PanicKey=keyToSave(Settings.PanicKey), MenuKey=keyToSave(Settings.MenuKey),
    }
    local nm=cfgCleanName(cfgNameBox and cfgNameBox.Text or "")
    local ok = pcall(function() writefile(cfgFileFor(nm), HttpService:JSONEncode(data)) end)
    cfgMsg.Text = ok and ("saved '"..nm.."'") or "save failed"
    if ok then notify("Config", "saved '"..nm.."'") end
end
function loadConfig()
    if not canFile then cfgMsg.Text="no file API" return end
    local nm=cfgCleanName(cfgNameBox and cfgNameBox.Text or "")
    local ok, raw = pcall(readfile, cfgFileFor(nm))
    if not ok or not raw then cfgMsg.Text="no save '"..nm.."'" return end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 or type(data)~="table" then cfgMsg.Text="save corrupted" return end
    local function apply(id, v)
        local fn=UIHandles[id]
        if fn and v~=nil then pcall(fn, v) end
    end
    for _, id in ipairs({"ESPEnabled","Boxes","Names","Distance","TeamCheck","MaxESP","OverlayY","Inventory","Tracers",
        "AimEnabled","AimMethod","AimMode","FOV","ShowFOV","Smoothing","Target","Priority",
        "AimTeamCheck","WallCheck","NoKnock","AFKProtect","MaxDistance",
        "TrigEnabled","TrigMode","TrigTarget","TrigTeamCheck","TrigNoKnock","TrigDelay",
        "Chams","AimLock","Crosshair","HealthBar","Prediction","Keybinds","FPSCap",
        "SilentEnabled","SilentTeam","SilentTarget","SilentFOV","SilentChance","SilentProj",
        "NoSpread","NoRecoil","RapidFire","FastReload","FullAuto","HitboxExpand","HitboxSize",
        "WalkSpeed","JumpPower","InfJump","Fly","FlySpeed","Noclip","Fullbright","CamFOV","ClickTP"}) do
        apply(id, data[id])
    end
    if type(data.Color)=="table" then
        apply("Color", Color3.fromRGB(math.clamp(data.Color[1] or 255,0,255), math.clamp(data.Color[2] or 0,0,255), math.clamp(data.Color[3] or 0,0,255)))
    end
    local ak=keyFromSave(data.AimKey)
    if ak then apply("AimKey", ak) end
    local pk=keyFromSave(data.PanicKey)
    if pk then apply("PanicKey", pk) end
    local mk=keyFromSave(data.MenuKey)
    if mk then apply("MenuKey", mk) end
    aimingOn=false
    cfgMsg.Text="loaded '"..nm.."'"
    notify("Config", "loaded '"..nm.."'")
end

do
    local hop=Instance.new("TextButton")
    hop.LayoutOrder=mo mo=mo+1 hop.Size=UDim2.new(1,-4,0,30) hop.Text="Server Hop"
    hop.Font=Enum.Font.GothamBold hop.TextSize=13 hop.BackgroundColor3=THEME.Item
    hop.TextColor3=Color3.new(1,1,1) hop.AutoButtonColor=false hop.Active=true hop.Parent=miscPage
    local hopC=Instance.new("UICorner") hopC.CornerRadius=UDim.new(0,8) hopC.Parent=hop
    hop.MouseButton1Click:Connect(function()
        local function httpGetBody(url)
            local req = (typeof(request)=="function" and request)
                or (typeof(syn)=="table" and typeof(syn.request)=="function" and syn.request)
                or (typeof(http_request)=="function" and http_request)
                or (typeof(http)=="table" and typeof(http.request)=="function" and http.request)
            if typeof(game.HttpGet)=="function" then
                local ok, src = pcall(function() return game:HttpGet(url) end)
                if ok and type(src)=="string" and src~="" then return src end
            end
            if req then
                local ok, res = pcall(function() return req({Url=url, Method="GET"}) end)
                if ok and res then
                    if type(res)=="string" and res~="" then return res end
                    if type(res)=="table" and type(res.Body)=="string" and res.Body~="" then return res.Body end
                end
            end
            return nil
        end
        cfgMsg.Text="finding server..."
        local body=httpGetBody("https://games.roblox.com/v1/games/"..tostring(game.PlaceId).."/servers/Public?sortOrder=Asc&limit=100")
        if not body then cfgMsg.Text="hop failed: no http" return end
        local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
        if not ok or type(data)~="table" or type(data.data)~="table" then cfgMsg.Text="hop failed: bad response" return end
        local myJob=""
        pcall(function() myJob=game.JobId end)
        for _,s in ipairs(data.data) do
            if type(s)=="table" and s.id and s.id~=myJob and (tonumber(s.playing) or 0) < (tonumber(s.maxPlayers) or 1) then
                cfgMsg.Text="hopping..."
                notify("Misc", "server hop...")
                pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer) end)
                return
            end
        end
        cfgMsg.Text="no open server found"
    end)
end
do local r=newRow(miscPage,mo); mo=mo+1
    local cj=Instance.new("TextButton")
    cj.LayoutOrder=1 cj.Size=UDim2.new(0.5,-3,0,30) cj.Text="Copy JobId"
    cj.Font=Enum.Font.GothamBold cj.TextSize=13 cj.BackgroundColor3=THEME.Item
    cj.TextColor3=Color3.new(1,1,1) cj.AutoButtonColor=false cj.Active=true cj.Parent=r
    local cjc=Instance.new("UICorner") cjc.CornerRadius=UDim.new(0,8) cjc.Parent=cj
    cj.MouseButton1Click:Connect(function()
        local j="" pcall(function() j=game.JobId end)
        local ok=false
        pcall(function() if typeof(setclipboard)=="function" then setclipboard(j) ok=true end end)
        cfgMsg.Text=ok and "jobid copied" or ("job: "..j)
    end)
    local cp=Instance.new("TextButton")
    cp.LayoutOrder=2 cp.Size=UDim2.new(0.5,-3,0,30) cp.Text="Copy PlaceId"
    cp.Font=Enum.Font.GothamBold cp.TextSize=13 cp.BackgroundColor3=THEME.Item
    cp.TextColor3=Color3.new(1,1,1) cp.AutoButtonColor=false cp.Active=true cp.Parent=r
    local cpc=Instance.new("UICorner") cpc.CornerRadius=UDim.new(0,8) cpc.Parent=cp
    cp.MouseButton1Click:Connect(function()
        local ok=false
        pcall(function() if typeof(setclipboard)=="function" then setclipboard(tostring(game.PlaceId)) ok=true end end)
        cfgMsg.Text=ok and "placeid copied" or ("place: "..tostring(game.PlaceId))
    end)
end

-- UTILITY TAB (movement + world)
local uo=1
pageHeader(utilPage,uo,"Utility") uo=uo+1
createSlider(utilPage,uo,"WalkSpeed","Walk Speed",16,250,Util.WalkSpeed,function(v) Util.WalkSpeed=v end) uo=uo+1
createSlider(utilPage,uo,"JumpPower","Jump Power",50,500,Util.JumpPower,function(v) Util.JumpPower=v end) uo=uo+1
createToggle(utilPage,uo,"InfJump","Infinite Jump",false,function(v) Util.InfJump=v end) uo=uo+1
do local r=newRow(utilPage,uo); uo=uo+1
    createToggle(r,1,"Fly","Fly",false,function(v) Util.Fly=v if not v then stopFly() end end,0.5,-3)
    createToggle(r,2,"Noclip","Noclip",false,function(v) Util.Noclip=v end,0.5,-3)
end
createSlider(utilPage,uo,"FlySpeed","Fly Speed",16,200,Util.FlySpeed,function(v) Util.FlySpeed=v end) uo=uo+1
do local r=newRow(utilPage,uo); uo=uo+1
    createToggle(r,1,"Fullbright","Fullbright",false,function(v) Util.Fullbright=v setFullbright(v) end,0.5,-3)
    createToggle(r,2,"ClickTP","Ctrl+Click TP",false,function(v) Util.ClickTP=v end,0.5,-3)
end
createSlider(utilPage,uo,"CamFOV","Camera FOV",30,120,Util.CamFOV,function(v) Util.CamFOV=v end) uo=uo+1
createToggle(utilPage,uo,"Crosshair","Crosshair",false,function(v) Util.Crosshair=v end) uo=uo+1
do
    local fb=Instance.new("TextButton")
    fb.LayoutOrder=uo uo=uo+1 fb.Size=UDim2.new(1,-4,0,30) fb.Text="Apply FPS Boost"
    fb.Font=Enum.Font.GothamBold fb.TextSize=13 fb.BackgroundColor3=THEME.Item
    fb.TextColor3=Color3.new(1,1,1) fb.AutoButtonColor=false fb.Active=true fb.Parent=utilPage
    local fbc=Instance.new("UICorner") fbc.CornerRadius=UDim.new(0,8) fbc.Parent=fb
    fb.MouseButton1Click:Connect(function() fpsBoost() end)
end

-- ARSENAL TAB (arsenal file only: silent aim, gun mods, hitbox)
local ao=1
pageHeader(arsPage,ao,"Silent Aim") ao=ao+1
do local r=newRow(arsPage,ao); ao=ao+1
    createToggle(r,1,"SilentEnabled","Silent Aim",false,function(v) ARS.SilentEnabled=v setSilentHook(v) end,0.5,-3)
    createToggle(r,2,"SilentTeam","Team Check",true,function(v) ARS.SilentTeam=v end,0.5,-3)
end
createDropdown(arsPage,ao,"SilentTarget","Target",{"Head","Hitbox"},ARS.SilentTarget,function(v) ARS.SilentTarget=v end) ao=ao+1
createSlider(arsPage,ao,"SilentFOV","Silent FOV",40,300,ARS.SilentFOV,function(v) ARS.SilentFOV=v end) ao=ao+1
createSlider(arsPage,ao,"SilentChance","Hit Chance %",10,100,ARS.SilentChance,function(v) ARS.SilentChance=v end) ao=ao+1
createToggle(arsPage,ao,"SilentProj","Patch Explosives",false,function(v) ARS.SilentProj=v end) ao=ao+1
arsMsgLbl=Instance.new("TextLabel")
arsMsgLbl.LayoutOrder=ao ao=ao+1 arsMsgLbl.Size=UDim2.new(1,-4,0,16) arsMsgLbl.BackgroundTransparency=1
arsMsgLbl.Text=canHook and "" or "needs hookmetamethod executor" arsMsgLbl.Font=Enum.Font.Gotham
arsMsgLbl.TextSize=11 arsMsgLbl.TextColor3=THEME.TextDim arsMsgLbl.TextXAlignment=Enum.TextXAlignment.Left arsMsgLbl.Parent=arsPage
pageHeader(arsPage,ao,"Gun Mods") ao=ao+1
do local r=newRow(arsPage,ao); ao=ao+1
    createToggle(r,1,"NoSpread","No Spread",false,function(v) ARS.NoSpread=v if v then applyGunMods() end end,0.5,-3)
    createToggle(r,2,"NoRecoil","No Recoil",false,function(v) ARS.NoRecoil=v if v then applyGunMods() end end,0.5,-3)
end
do local r=newRow(arsPage,ao); ao=ao+1
    createToggle(r,1,"RapidFire","Rapid Fire",false,function(v) ARS.RapidFire=v if v then applyGunMods() end end,0.5,-3)
    createToggle(r,2,"FastReload","Fast Reload",false,function(v) ARS.FastReload=v if v then applyGunMods() end end,0.5,-3)
end
createToggle(arsPage,ao,"FullAuto","Full Auto",false,function(v) ARS.FullAuto=v if v then applyGunMods() end end) ao=ao+1
gunMsgLbl=Instance.new("TextLabel")
gunMsgLbl.LayoutOrder=ao ao=ao+1 gunMsgLbl.Size=UDim2.new(1,-4,0,16) gunMsgLbl.BackgroundTransparency=1
gunMsgLbl.Text="" gunMsgLbl.Font=Enum.Font.Gotham
gunMsgLbl.TextSize=11 gunMsgLbl.TextColor3=THEME.TextDim gunMsgLbl.TextXAlignment=Enum.TextXAlignment.Left gunMsgLbl.Parent=arsPage
pageHeader(arsPage,ao,"Hitbox Expander") ao=ao+1
createToggle(arsPage,ao,"HitboxExpand","Expander",false,function(v) ARS.HitboxExpand=v applyHitboxes() end) ao=ao+1
createSlider(arsPage,ao,"HitboxSize","Hitbox Size",2,6,ARS.HitboxSize,function(v) ARS.HitboxSize=v end) ao=ao+1

local function clearESP(player)
    local d=ESPData[player]
    if d then
        pcall(function() d.boxGui:Destroy() end) pcall(function() d.nameGui:Destroy() end)
        pcall(function() if d.tracer then d.tracer:Destroy() end end)
        pcall(function() if d.cham then d.cham:Destroy() end end)
        ESPData[player]=nil
    end
    lastAttempt[player]=nil
    creating[player]=nil
    invCache[player]=nil
    local ch=nil pcall(function() ch=player.Character end)
    if ch then downCache[ch]=nil end
end

local function Unload()
    if Unloaded then return end Unloaded=true
    activeDragFn=nil aimingOn=false openDropClose=nil
    if Util.Fly then Util.Fly=false stopFly() end
    if Util.Fullbright then Util.Fullbright=false setFullbright(false) end
    if silentHooked and oldSilentCall and canHook then
        pcall(hookmetamethod, game, "__namecall", oldSilentCall)
        silentHooked=false
    end
    ARS.SilentEnabled=false
    ARS.HitboxExpand=false
    pcall(applyHitboxes)
    if silentMouse.hooked and silentMouse.old then
        pcall(hookmetamethod, game, "__index", silentMouse.old)
        silentMouse.hooked=false
    end
    for _,c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    for p,_ in pairs(ESPData) do clearESP(p) end
    for _,p in ipairs(cachedPlayers) do if p.Character then deepCleanCharacter(p.Character) end end
    pcall(function() overlayGui:Destroy() end) pcall(function() fovGui:Destroy() end) pcall(function() gui:Destroy() end)
end
unloadBtn.MouseButton1Click:Connect(Unload)

local function getInvStr(player)
    local nowC = os.clock()
    local e = invCache[player]
    if e and nowC - e.t < INV_TTL then return e.s end
    local inv={}
    pcall(function()
        local bp=player:FindFirstChildOfClass("Backpack")
        if bp then
            for _,t in ipairs(bp:GetChildren()) do
                if t:IsA("Tool") then table.insert(inv, t.Name) end
            end
        end
        local ch=player.Character
        if ch then
            for _,t in ipairs(ch:GetChildren()) do
                if t:IsA("Tool") then table.insert(inv, "[E] "..t.Name) end
            end
        end
    end)
    local s=""
    if #inv>0 then
        local shown=table.concat(inv, ", ", 1, math.min(#inv, 4))
        if #inv>4 then shown=shown.." +"..(#inv-4) end
        s="["..shown.."]"
    end
    invCache[player]={t=nowC, s=s}
    return s
end
local function buildLabelText(player, hrp, myHrp)
    local txt=""
    if Settings.Names then txt=player.DisplayName.." (@"..player.Name..")" end
    if Settings.Distance and myHrp and hrp then
        local dx=myHrp.Position.X-hrp.Position.X
        local dy=myHrp.Position.Y-hrp.Position.Y
        local dz=myHrp.Position.Z-hrp.Position.Z
        local sub="["..math.floor(math.sqrt(dx*dx+dy*dy+dz*dz)).."m]"
        if txt~="" then txt=txt.."\n" end
        txt=txt..sub
    end
    if Settings.Inventory then
        local s=getInvStr(player)
        if s~="" then
            if txt~="" then txt=txt.."\n" end
            txt=txt..s
        end
    end
    return txt
end

local function isDown(char, hum)
    local ok, st = pcall(function() return hum:GetState() end)
    if ok and (st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Dead) then return true end
    for _, n in ipairs({"Knocked","KO","Downed","Unconscious","Ragdolled"}) do
        local v=char:FindFirstChild(n)
        if v then
            if v:IsA("BoolValue") and v.Value then return true end
            if v:IsA("ObjectValue") or v:IsA("StringValue") then return true end
        end
    end
    return false
end
local function isDownCached(char, hum)
    local nowC=os.clock()
    local e=downCache[char]
    if e and nowC-e.t < DOWN_TTL then return e.v end
    local v=isDown(char, hum)
    downCache[char]={t=nowC, v=v}
    return v
end

local function createESP(player)
    if runStale() then return end
    if not LoadingDone or Unloaded or player==LocalPlayer then return end
    if creating[player] then return end
    creating[player]=true
    clearESP(player)
    local char=player.Character
    if not char then creating[player]=nil return end
    deepCleanCharacter(char)
    local hrp=char:FindFirstChild("HumanoidRootPart")
    local head=char:FindFirstChild("Head")
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not hrp or not head or not hum then creating[player]=nil return end
    -- billboard-anchored ESP: engine positions it, always hugs the body
    local boxGui=Instance.new("BillboardGui")
    boxGui.Name="NovaBox" boxGui.Adornee=hrp boxGui.AlwaysOnTop=true boxGui.LightInfluence=0
    boxGui.Size=UDim2.new(4,0,6.5,0) boxGui.ExtentsOffsetWorldSpace=Vector3.new(0,0.5,0) boxGui.Parent=hrp
    pcall(function() boxGui:SetAttribute("nx",1) end)
    local bf=Instance.new("Frame") bf.Size=UDim2.new(1,0,1,0) bf.BackgroundTransparency=1 bf.Active=false bf.Parent=boxGui
    local stroke=Instance.new("UIStroke") stroke.Thickness=2 stroke.Color=Settings.Color stroke.Parent=bf
    local nameGui=Instance.new("BillboardGui")
    nameGui.Name="NovaTag" nameGui.Adornee=head nameGui.AlwaysOnTop=true
    nameGui.Size=UDim2.new(0,220,0,66) nameGui.ExtentsOffsetWorldSpace=Vector3.new(0,3.4,0)
    nameGui.LightInfluence=0 nameGui.Parent=head
    pcall(function() nameGui:SetAttribute("nx",1) end)
    local label=Instance.new("TextLabel")
    label.Size=UDim2.new(1,0,1,0) label.BackgroundTransparency=1
    label.Font=Enum.Font.GothamBold label.TextSize=13 label.TextStrokeTransparency=0
    label.TextXAlignment=Enum.TextXAlignment.Center
    label.Text="" label.TextColor3=Settings.Color label.Parent=nameGui
    local hpBG=Instance.new("Frame")
    hpBG.Size=UDim2.new(0,120,0,6) hpBG.Position=UDim2.new(0.5,-60,1,-8)
    hpBG.BackgroundColor3=Color3.fromRGB(20,20,25) hpBG.BorderSizePixel=0 hpBG.Active=false hpBG.Visible=false hpBG.Parent=nameGui
    do local hpBGC=Instance.new("UICorner") hpBGC.CornerRadius=UDim.new(0,3) hpBGC.Parent=hpBG end
    local hpFill=Instance.new("Frame")
    hpFill.Size=UDim2.new(1,0,1,0) hpFill.BackgroundColor3=Color3.fromRGB(80,255,120)
    hpFill.BorderSizePixel=0 hpFill.Active=false hpFill.Parent=hpBG
    local cham=Instance.new("Highlight")
    cham.Name="NovaCham" cham.Adornee=char cham.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    cham.FillColor=Settings.Color cham.OutlineColor=Settings.Color
    cham.FillTransparency=0.5 cham.OutlineTransparency=0 cham.Enabled=false cham.Parent=char
    pcall(function() cham:SetAttribute("nx",1) end)
    local myHrp0=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    label.Text=buildLabelText(player, hrp, myHrp0)
    -- (health bar removed)
    local parts={
        Head=head, HRP=hrp,
        Upper=char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"),
    }
    local tracer=Instance.new("Frame")
    tracer.AnchorPoint=Vector2.new(0.5,0.5) tracer.BorderSizePixel=0 tracer.Active=false
    tracer.BackgroundColor3=Settings.Color tracer.Visible=false tracer.Parent=overlayGui
    ESPData[player]={boxGui=boxGui,stroke=stroke,nameGui=nameGui,nameLabel=label,parts=parts,hrp=hrp,hum=hum,tracer=tracer,cham=cham,hpBG=hpBG,hpFill=hpFill}
    creating[player]=nil
end

local function tryCreate(player)
    if creating[player] then return end
    local now=os.clock()
    if lastAttempt[player] and now-lastAttempt[player] < 1 then return end
    lastAttempt[player]=now
    task.spawn(createESP,player)
end

local function drawLine(f,x1,y1,x2,y2,col)
    local dx=x2-x1 local dy=y2-y1 local len=math.sqrt(dx*dx+dy*dy)
    if len<3 then f.Visible=false return end
    f.Visible=true
    if f.BackgroundColor3~=col then f.BackgroundColor3=col end
    f.Size=UDim2.new(0,len,0,2) f.Position=UDim2.new(0,(x1+x2)*0.5,0,(y1+y2)*0.5)
    f.Rotation=math.deg(math.atan2(dy,dx))
end

local function hideOverlay(d)
    if not d then return end
    if d.tracer then d.tracer.Visible=false end
    if d.hpBG then d.hpBG.Visible=false end
end

local rayParams=RaycastParams.new() rayParams.FilterType=Enum.RaycastFilterType.Exclude rayParams.IgnoreWater=true
local function isAimHeld()
    local k=Settings.AimKey if not k then return false end
    if k.Type=="Mouse" then
        local ok,down=pcall(function() return UserInputService:IsMouseButtonPressed(k.Button) end) return ok and down
    else
        local ok,down=pcall(function() return UserInputService:IsKeyDown(k.Key) end) return ok and down
    end
end
local function keyMatches(k, inp)
    if not k then return false end
    if k.Type=="Mouse" then return inp.UserInputType==k.Button end
    return inp.KeyCode==k.Key
end
local function isVisible(cam,tc,tp)
    if not Settings.WallCheck then return true end
    if LocalPlayer.Character then rayParams.FilterDescendantsInstances={LocalPlayer.Character}
    else rayParams.FilterDescendantsInstances={} end
    local res=Workspace:Raycast(cam.CFrame.Position,tp-cam.CFrame.Position,rayParams)
    if not res then return true end return res.Instance:IsDescendantOf(tc)
end
local function screenDist(sx,sy,mx,my)
    local dx=sx-mx local dy=sy-my
    return math.sqrt(dx*dx+dy*dy)
end
local function candidateOK(player, d, char)
    if not d or not d.hrp or not d.hum then return false end
    if d.hrp.Parent==nil or d.hum.Parent==nil then return false end
    if d.hum.Health<=0 then return false end
    if not char then return false end
    if Settings.AimTeamCheck and player.Team and LocalPlayer.Team and player.Team==LocalPlayer.Team then return false end
    if Settings.NoKnock and isDownCached(char, d.hum) then return false end
    return true
end
local function getAimPos(parts,cam,mousePos)
    if Settings.Target=="Head" then return parts.Head and parts.Head.Position or nil
    elseif Settings.Target=="HRP" then return parts.HRP and parts.HRP.Position or nil
    else
        local best,bestD=nil,math.huge
        if parts.Head then
            local sp,ok=cam:WorldToViewportPoint(parts.Head.Position)
            if ok then local d=screenDist(sp.X,sp.Y,mousePos.X,mousePos.Y) if d<bestD then bestD=d best=parts.Head.Position end end
        end
        if parts.HRP then
            local sp,ok=cam:WorldToViewportPoint(parts.HRP.Position)
            if ok then local d=screenDist(sp.X,sp.Y,mousePos.X,mousePos.Y) if d<bestD then bestD=d best=parts.HRP.Position end end
        end
        if parts.Upper then
            local sp,ok=cam:WorldToViewportPoint(parts.Upper.Position)
            if ok then local d=screenDist(sp.X,sp.Y,mousePos.X,mousePos.Y) if d<bestD then bestD=d best=parts.Upper.Position end end
        end
        return best
    end
end
local function findTarget(cam,mousePos,myHrp)
    local cands={}
    local maxD2=Settings.MaxDistance*Settings.MaxDistance
    for _,player in ipairs(cachedPlayers) do
        if player~=LocalPlayer then
            local d=ESPData[player]
            local char=player.Character
            if candidateOK(player, d, char) then
                local hp=d.hrp.Position
                local mhp=myHrp.Position
                local dx=mhp.X-hp.X local dy=mhp.Y-hp.Y local dz=mhp.Z-hp.Z
                if dx*dx+dy*dy+dz*dz <= maxD2 then
                    local wp=getAimPos(d.parts,cam,mousePos)
                    if wp then
                        local sp,ok=cam:WorldToViewportPoint(wp)
                        if ok then
                            local sd=screenDist(sp.X,sp.Y,mousePos.X,mousePos.Y)
                            if sd<=Settings.FOV then
                                table.insert(cands,{sd=sd,hp=d.hum.Health,wp=wp,char=char,pl=player,vl=d.hrp.AssemblyLinearVelocity})
                            end
                        end
                    end
                end
            end
        end
    end
    if #cands==0 then return nil end
    if Settings.Priority=="Low HP" then
        table.sort(cands,function(a,b) return a.hp<b.hp end)
    else
        table.sort(cands,function(a,b) return a.sd<b.sd end)
    end
    for i=1,math.min(3,#cands) do
        if isVisible(cam,cands[i].char,cands[i].wp) then return cands[i].wp, cands[i].pl, cands[i].vl end
    end
    return nil
end

local lastTrigMsgW = 0
local function setTrigState(s, nowC)
    if trigMsgLbl and nowC - lastTrigMsgW > 0.2 then
        lastTrigMsgW = nowC
        pcall(function() trigMsgLbl.Text = "status: " .. s end)
    end
end
local function doTrigger(cam, mousePos, mouseRaw, myHrp, nowC)
    if not ESP_ONLY and Settings.TrigEnabled and not Unloaded and myHrp then
        local holdOK=true
        if Settings.TrigMode=="Hold Key" then holdOK=isAimHeld() end
        if holdOK then
            local valid=false
            local ray=cam:ViewportPointToRay(mousePos.X, mousePos.Y)
            if ray then
                rayParams.FilterDescendantsInstances={LocalPlayer.Character, cam}
                local res=Workspace:Raycast(ray.Origin, ray.Direction*1000, rayParams)
                if res and res.Instance then
                    local hitModel=res.Instance:FindFirstAncestorOfClass("Model")
                    local tp=hitModel and Players:GetPlayerFromCharacter(hitModel) or nil
                    if tp and tp~=LocalPlayer then
                        local ch=tp.Character
                        local hum=ch and ch:FindFirstChildOfClass("Humanoid")
                        if ch and hum and hum.Health>0 then
                            valid=true
                            if valid and Settings.TrigTeamCheck and tp.Team and LocalPlayer.Team and tp.Team==LocalPlayer.Team then valid=false end
                            if valid and Settings.TrigNoKnock and isDownCached(ch, hum) then valid=false end
                            if valid and Settings.TrigTarget=="Head" and res.Instance.Name~="Head" then valid=false end
                            if valid and Settings.TrigTarget=="HRP" and res.Instance.Name~="HumanoidRootPart" then valid=false end
                            if valid then
                                local hp=ch:FindFirstChild("HumanoidRootPart")
                                if hp then
                                    local dx=myHrp.Position.X-hp.Position.X
                                    local dy=myHrp.Position.Y-hp.Position.Y
                                    local dz=myHrp.Position.Z-hp.Position.Z
                                    if dx*dx+dy*dy+dz*dz > Settings.MaxDistance*Settings.MaxDistance then valid=false end
                                end
                            end
                        end
                    end
                end
            end
            if valid then
                if trigAcquireT==0 then trigAcquireT=nowC setTrigState("locked", nowC) end
                if nowC-trigAcquireT >= Settings.TrigDelay/1000 then
                    trigAcquireT=nowC
                    local how=fireClick(mouseRaw.X, mouseRaw.Y)
                    if how then setTrigState("firing ("..how..")", nowC)
                    else
                        setTrigState("NO CLICK API", nowC)
                        if not trigWarned then trigWarned=true warn("[NOVA] triggerbot: no click method (mouse1click/VIM/tool)") end
                    end
                end
            else
                trigAcquireT=0
                setTrigState("scanning", nowC)
            end
        else
            trigAcquireT=0
            setTrigState("hold key...", nowC)
        end
    else
        trigAcquireT=0
        setTrigState("off", nowC)
    end
end

for _,p in ipairs(Players:GetPlayers()) do
    if p~=LocalPlayer then
        track(p.CharacterAdded:Connect(function()
            if runStale() then return end
            if not LoadingDone or Unloaded then return end
            clearESP(p) task.wait(1) if LoadingDone and not Unloaded and not runStale() then createESP(p) end
        end))
    end
end
-- SILENT AIM via Mouse.Hit/Target hook (used by AimMethod "Silent", any game whose
-- tools read mouse.Hit; gated on AimEnabled, restored on Unload)
local silentMouse = {hooked=false, old=nil}
function silentMouse.install(on)
    if on and not silentMouse.hooked then
        if typeof(hookmetamethod)~="function" or typeof(checkcaller)~="function" then
            notify("Aim", "silent needs hookmetamethod")
            return
        end
        local ok=pcall(function()
            local nc=(typeof(newcclosure)=="function" and newcclosure) or function(f) return f end
            local function pickPart()
                local cam=Workspace.CurrentCamera
                if not cam then return nil end
                local m=UserInputService:GetMouseLocation()
                local asz=overlayGui.AbsoluteSize
                local vpsz=cam.ViewportSize
                local mousePos=Vector2.new(m.X-(asz.X-vpsz.X), m.Y-(asz.Y-vpsz.Y))
                local best,bestD=nil,Settings.FOV
                for _,p in ipairs(cachedPlayers) do
                    if p~=LocalPlayer then
                        local ch=p.Character
                        local hum=ch and ch:FindFirstChildOfClass("Humanoid")
                        if ch and hum and hum.Health>0 then
                            local okT=true
                            if Settings.AimTeamCheck and p.Team and LocalPlayer.Team and p.Team==LocalPlayer.Team then okT=false end
                            if okT and Settings.NoKnock and isDownCached(ch, hum) then okT=false end
                            if okT then
                                local t=Settings.Target
                                local p1=(t=="HRP") and ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Head")
                                local p2=(t=="Closest") and ch:FindFirstChild("HumanoidRootPart") or nil
                                local cand={p1,p2}
                                for _,part in ipairs(cand) do
                                    if part then
                                        local sp,ok=cam:WorldToViewportPoint(part.Position)
                                        if ok then
                                            local dx=sp.X-mousePos.X local dy=sp.Y-mousePos.Y
                                            local d=math.sqrt(dx*dx+dy*dy)
                                            if d<=bestD and (not Settings.WallCheck or isVisible(cam,ch,part.Position)) then
                                                best,bestD=part,d
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                return best
            end
            silentMouse.old=hookmetamethod(game, "__index", nc(function(self, k)
                if k=="Hit" or k=="Target" then
                    local okc=false
                    pcall(function() okc=not checkcaller() end)
                    if okc and typeof(self)=="Instance" then
                        local okI=false
                        pcall(function() okI=self:IsA("Mouse") end)
                        if okI and gateOpen() and not Unloaded and not runStale()
                            and Settings.AimEnabled and Settings.AimMethod=="Silent" then
                            local part=nil
                            pcall(function() part=pickPart() end)
                            if part then
                                if k=="Target" then return part end
                                return part.CFrame
                            end
                        end
                    end
                end
                return silentMouse.old(self, k)
            end))
            silentMouse.hooked=true
        end)
        if ok and silentMouse.hooked then notify("Aim", "silent hook ready") end
    end
end
track(Players.PlayerAdded:Connect(function(p)
    refreshPlayers()
    track(p.CharacterAdded:Connect(function()
        if runStale() then return end
        if not LoadingDone or Unloaded then return end
        clearESP(p) task.wait(1) if LoadingDone and not Unloaded and not runStale() then createESP(p) end
    end))
end))
track(Players.PlayerRemoving:Connect(function(p) clearESP(p) refreshPlayers() end))
track(LocalPlayer.Idled:Connect(function()
    if Settings.AFKProtect and not Unloaded and not runStale() then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end))

local renderConn=nil
renderConn=track(RunService.RenderStepped:Connect(function()
    if runStale() then pcall(function() renderConn:Disconnect() end) return end
    if Unloaded or not LoadingDone then fovCircle.Visible=false return end
    frameCount = frameCount + 1
    local doLabels=(frameCount%10==0)
    local doOverlay=(frameCount%2==0)
    local cam=Workspace.CurrentCamera if not cam then return end
    local mouseRaw=UserInputService:GetMouseLocation()
    local vpsz=cam.ViewportSize
    local asz=overlayGui.AbsoluteSize
    local offX=asz.X-vpsz.X local offY=asz.Y-vpsz.Y
    local mousePos=Vector2.new(mouseRaw.X-offX, mouseRaw.Y-offY)
    local col=Settings.Color
    local espOn=Settings.ESPEnabled
    local boxesOn=Settings.Boxes
    local maxESP2=Settings.MaxESP*Settings.MaxESP
    if not ESP_ONLY and Settings.AimEnabled and Settings.ShowFOV then
        fovCircle.Visible=true
        if lastFOV~=Settings.FOV then
            lastFOV=Settings.FOV
            fovCircle.Size=UDim2.new(0,Settings.FOV*2,0,Settings.FOV*2)
        end
        fovCircle.Position=UDim2.new(0,mouseRaw.X,0,mouseRaw.Y)
    else fovCircle.Visible=false end
    if Util.Crosshair then
        cross.H.Visible=true cross.V.Visible=true
        cross.H.Position=UDim2.new(0,mouseRaw.X,0,mouseRaw.Y)
        cross.V.Position=UDim2.new(0,mouseRaw.X,0,mouseRaw.Y)
    else
        cross.H.Visible=false cross.V.Visible=false
    end
    local myChar=LocalPlayer.Character
    local myHrp=myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myTeam=LocalPlayer.Team
    local scrW, scrH = asz.X, asz.Y
    for _,player in ipairs(cachedPlayers) do
        if player~=LocalPlayer then
            local d=ESPData[player]
            if d==nil then
                if not creating[player] and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then tryCreate(player) end
            elseif d.hrp.Parent==nil or d.hum.Parent==nil or d.boxGui.Parent==nil or d.nameGui.Parent==nil then
                tryCreate(player)
            else
                local hrp=d.hrp local hum=d.hum
                local show=espOn and hum.Health>0
                if show and myHrp then
                    local dx=myHrp.Position.X-hrp.Position.X
                    local dy=myHrp.Position.Y-hrp.Position.Y
                    local dz=myHrp.Position.Z-hrp.Position.Z
                    if dx*dx+dy*dy+dz*dz > maxESP2 then show=false end
                end
                if show and Settings.TeamCheck and player.Team~=nil and myTeam~=nil and player.Team==myTeam then show=false end
                local okP = pcall(function()
                    d.boxGui.Enabled=show and boxesOn
                    d.nameGui.Enabled=show and (Settings.Names or Settings.Distance or Settings.HealthBar)
                    if d.stroke.Color~=col then d.stroke.Color=col end
                    if d.cham then
                        if d.cham.FillColor~=col then d.cham.FillColor=col end
                        if d.cham.OutlineColor~=col then d.cham.OutlineColor=col end
                        d.cham.Enabled=show and Settings.Chams
                    end
                    if show and doLabels then
                        local nt=buildLabelText(player, hrp, myHrp)
                        if d.nameLabel.Text~=nt then d.nameLabel.Text=nt end
                        if d.nameLabel.TextColor3~=col then d.nameLabel.TextColor3=col end
                        if Settings.HealthBar and d.hpFill then
                            local frac=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
                            d.hpFill.Size=UDim2.new(frac,0,1,0)
                            d.hpFill.BackgroundColor3=Color3.fromRGB(math.floor(255*(1-frac)),math.floor(255*frac),60)
                        end
                    elseif show and d.nameLabel.TextColor3~=col then
                        d.nameLabel.TextColor3=col
                    end
                    if d.hpBG then d.hpBG.Visible=show and Settings.HealthBar end
                    if not show then
                        hideOverlay(d)
                    elseif doOverlay then
                        if show and Settings.Tracers and scrW>0 then
                            local sp,ok=cam:WorldToViewportPoint(hrp.Position)
                            if ok then drawLine(d.tracer, scrW*0.5, scrH, sp.X+offX, sp.Y+offY+Settings.OverlayY, col)
                            else d.tracer.Visible=false end
                        elseif d.tracer then d.tracer.Visible=false end
                    end
                end)
                if not okP then tryCreate(player) end
            end
        end
    end
    fpsAcc=fpsAcc+1
    local nowC=os.clock()
    if nowC-fpsClock>=1 then
        fpsShown=fpsAcc fpsAcc=0 fpsClock=nowC
        pcall(function()
            perfLbl.Text="FPS: "..fpsShown.." • Players: "..#cachedPlayers
        end)
    end
    if doOverlay then
        doTrigger(cam, mousePos, mouseRaw, myHrp, nowC)
    end
    local wantAim=false
    if not ESP_ONLY and Settings.AimEnabled and not Unloaded then
        if Settings.AimMode=="Toggle" then wantAim=aimingOn
        else wantAim=isAimHeld() end
    end
    if wantAim and myHrp then
        local bestPos, lockVel = nil, nil
        if Settings.AimLock and lockedPlayer~=nil then
            local ld=ESPData[lockedPlayer]
            local lch=lockedPlayer.Character
            if candidateOK(lockedPlayer,ld,lch) then
                local wp=getAimPos(ld.parts,cam,mousePos)
                if wp then
                    local sp,vis=cam:WorldToViewportPoint(wp)
                    if vis and screenDist(sp.X,sp.Y,mousePos.X,mousePos.Y) <= Settings.FOV*1.5 then
                        bestPos=wp
                        pcall(function() lockVel=ld.hrp.AssemblyLinearVelocity end)
                    end
                end
            end
            if bestPos==nil then lockedPlayer=nil end
        end
        if bestPos==nil then
            local wp,pl,vl=findTarget(cam,mousePos,myHrp)
            bestPos=wp lockVel=vl
            if Settings.AimLock then lockedPlayer=pl end
        end
        if bestPos and Settings.Prediction>0 and typeof(lockVel)=="Vector3" then
            bestPos=bestPos+lockVel*(Settings.Prediction*0.01)
        end
        if bestPos then
            if Settings.AimMethod=="Silent" then
                -- mouse hook redirects shots; leave the camera alone
            elseif Settings.AimMethod=="Mouse" and hasMouseMove then
                local sp,_=cam:WorldToViewportPoint(bestPos)
                local s=math.max(1,Settings.Smoothing)
                pcall(function() mousemoverel((sp.X-mousePos.X)/s,(sp.Y-mousePos.Y)/s) end)
            else
                if Settings.AimMethod=="Mouse" and not hasMouseMove and not mouseWarned then mouseWarned=true warn("[Aim] mousemoverel missing, camera fallback") end
                local goal=CFrame.new(cam.CFrame.Position,bestPos)
                cam.CFrame=cam.CFrame:Lerp(goal,math.clamp(1/math.max(1,Settings.Smoothing),0.05,1))
            end
        end
    else
        lockedPlayer=nil
    end
end))

track(UserInputService.InputBegan:Connect(function(inp,gpe)
    if Unloaded or runStale() then return end
    if keyMatches(Settings.PanicKey, inp) and not gpe then
        main.Visible=false
        Unload()
        return
    end
    if gpe then return end
    if keyMatches(Settings.MenuKey, inp) then main.Visible=not main.Visible return end
    if Settings.AimMode=="Toggle" and Settings.AimEnabled and keyMatches(Settings.AimKey, inp) then
        aimingOn=not aimingOn
    end
end))

local function finishLoading()
    if Unloaded or LoadingDone or not gateOpen() then return end
    LoadingDone=true
    print("[NOVA] v7.0 loaded ("..FILE_TAG.." / "..GAME_VERSION..")")
    pcall(function() loading:Destroy() end)
    pcall(function() main.Visible=true end)
    refreshPlayers()
    for _,p in ipairs(cachedPlayers) do
        if p~=LocalPlayer and p.Character then task.spawn(createESP,p) end
    end
end

local LOAD_TIME = 3.8
task.spawn(function()
    while not gateOpen() and not Unloaded and not runStale() do task.wait(0.1) end
    if Unloaded or runStale() then return end
    pcall(function() loading.Visible=true end)
    local t0=os.clock()
    while not Unloaded and not LoadingDone and loading.Parent and not runStale() do
        pcall(function() spinRot.Rotation=(spinRot.Rotation+12)%360 end)
        local n=math.clamp(math.floor((os.clock()-t0)/LOAD_TIME*100),0,100)
        pcall(function() barFill.Size=UDim2.new(n/100,0,1,0) pct.Text=n.."%" end)
        if n>=100 then break end
        task.wait(0.03)
    end
    task.wait(0.25)
    finishLoading()
end)

task.delay(8, function()
    if not Unloaded and not LoadingDone and gateOpen() and not runStale() then
        warn("[NOVA] fallback force-show")
        finishLoading()
    end
end)
