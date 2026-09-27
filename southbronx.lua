-- NOVA v8.0 | South Bronx: The Trenches (game-specific farm + teleport)
-- Menu: RightShift (drag via header) - Panic: Delete

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

print("[NOVA] v8.0 boot (generic)")

-- KEY SYSTEM: key gates the menu (loader hands it via getgenv when present)
local KeySystemEnabled = true
local VALID_KEYS = { ["1234"] = true }
local KEY_FILE = "nova_key.txt"
local MAX_KEY_TRIES = 5

-- GAME DETECTION: standard-Roblox games (R6/R15 with Head + HRP)
local SOUTH_BRONX_UNIVERSE = 3734304510
local detectedUniverse, detectedPlace = 0, 0
pcall(function() detectedUniverse = game.GameId end)
pcall(function() detectedPlace = game.PlaceId end)
local GAME_VERSION = "South Bronx"
local FILE_TAG = "southbronx"

-- STANDARD-ROBLOX CHARACTER MODEL: Head, HumanoidRootPart, Humanoid, Backpack
-- (Games with custom rigs should use their own script instead.)
local function getCharParts(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not head or not hum then return nil end
    return { hrp=hrp, head=head, hum=hum,
        torso=char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") }
end
local function isKnocked(char, hum)
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
local function getTools(player)
    local tools={}
    local bp=player:FindFirstChildOfClass("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then table.insert(tools,t) end end end
    local ch=player.Character
    if ch then for _,t in ipairs(ch:GetChildren()) do if t:IsA("Tool") then table.insert(tools,t) end end end
    return tools
end

local THEME = {
    BG = Color3.fromRGB(16,16,22), Panel = Color3.fromRGB(24,24,34),
    Item = Color3.fromRGB(34,34,50), Stroke = Color3.fromRGB(58,58,80),
    Accent = Color3.fromRGB(124,92,255), Hover = Color3.fromRGB(46,46,66),
    TextDim = Color3.fromRGB(175,175,190),
}

local Settings = {
    ESPEnabled = true, Boxes = true, Names = true, Distance = true,
    TeamCheck = false, MaxESP = 2000, OverlayY = 0,
    Tracers = false, Inventory = false, Chams = false, HealthBar = false,
    Color = Color3.fromRGB(255,0,0),
    AimEnabled = false, AimMethod = "Camera", AimMode = "Hold",
    AimKey = {Type="Mouse", Button=Enum.UserInputType.MouseButton2, Name="RMB"},
    FOV = 120, ShowFOV = true, Smoothing = 6,
    Target = "Head", Priority = "Closest", AimLock = false, Prediction = 0,
    AimTeamCheck = true, WallCheck = true, NoKnock = true,
    TrigEnabled = false, TrigMode = "Always", TrigTarget = "Any",
    TrigTeamCheck = true, TrigNoKnock = true, TrigDelay = 120,
    MaxDistance = 1000, AFKProtect = true, FPSCap = 60,
    PanicKey = {Type="Key", Key=Enum.KeyCode.Delete, Name="Delete"},
    MenuKey = {Type="Key", Key=Enum.KeyCode.RightShift, Name="RightShift"},
}

-- STATE
local Unloaded = false
local LoadingDone = false
local keyPassed = not KeySystemEnabled
local Conns = {}
local ESPData = {}
local UIHandles = {}
local lastAttempt = {}
local creating = {}
local function track(c) table.insert(Conns,c) return c end
local hasMouseMove = typeof(mousemoverel) == "function"
local canFile = typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
local frameCount = 0
local lastFOV = -1
local lastMX, lastMY = -1, -1
local lastCX, lastCY = -1, -1
local aimingOn = false
local trigAcquireT = 0
local lockedPlayer = nil
local menuOpen = false
local menuBusy = false
local openDropClose = nil
local activeDragFn = nil
local fpsAcc, fpsShown, fpsClock = 0, 60, os.clock()
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
    -- loader already validated the key
    local g = getgenv and getgenv()
    if type(g)=="table" and g.NOVA_KEY=="1234" then return true end
    if _G.NOVA_KEY=="1234" then return true end
    return (not KeySystemEnabled) or keyPassed
end

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

-- HELPERS
local function keyMatches(k, inp)
    if not k then return false end
    if k.Type=="Mouse" then return inp.UserInputType==k.Button end
    return inp.KeyCode==k.Key
end
local function isAimHeld()
    local k=Settings.AimKey if not k then return false end
    if k.Type=="Mouse" then
        local ok,down=pcall(function() return UserInputService:IsMouseButtonPressed(k.Button) end) return ok and down
    else
        local ok,down=pcall(function() return UserInputService:IsKeyDown(k.Key) end) return ok and down
    end
end
local function isDownCached(char, hum)
    local nowC=os.clock()
    local e=downCache[char]
    if e and nowC-e.t < DOWN_TTL then return e.v end
    local v=isKnocked(char, hum)
    downCache[char]={t=nowC, v=v}
    return v
end
local vimSvc = nil
pcall(function() vimSvc = game:GetService("VirtualInputManager") end)
local function fireClick(x, y)
    if typeof(mouse1click)=="function" then
        if pcall(mouse1click) then return "mouse" end
    end
    if vimSvc then
        local okDown=pcall(function() vimSvc:SendMouseButtonEvent(x, y, 0, true, game, 1) end)
        pcall(function() vimSvc:SendMouseButtonEvent(x, y, 0, false, game, 1) end)
        if okDown then return "vim" end
    end
    local tool=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if tool then
        if pcall(function() tool:Activate() end) then return "tool" end
    end
    return nil
end
local function keyDataToName(k)
    if not k then return "?" end
    return k.Name or "?"
end

-- BOOT CLEANUP
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
pcall(function() killOwnGuis(LocalPlayer.PlayerGui) end)
if gethui then
    pcall(function() gethui():FindFirstChild("NovaHub"):Destroy() end)
    pcall(function() gethui():FindFirstChild("NovaFx"):Destroy() end)
    pcall(function() gethui():FindFirstChild("NovaRing"):Destroy() end)
    pcall(function() killOwnGuis(gethui()) end)
end
for _,p in ipairs(Players:GetPlayers()) do if p.Character then deepCleanCharacter(p.Character) end end

local parentGui = LocalPlayer:WaitForChild("PlayerGui")
pcall(function() if gethui then parentGui = gethui() end end)

-- GUI SHELL
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
loadVer.BackgroundTransparency=1 loadVer.Text="v8.0 ("..FILE_TAG..")"
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

-- MAIN MENU 700x500
local main=Instance.new("Frame")
main.AnchorPoint=Vector2.new(0.5,0.5) main.Position=UDim2.new(0.5,0,0.5,0)
main.Size=UDim2.new(0,700,0,500)
main.BackgroundColor3=THEME.BG main.BorderSizePixel=0
main.Active=false main.Draggable=false main.ClipsDescendants=true
main.Visible=false main.Parent=gui
local mc=Instance.new("UICorner") mc.CornerRadius=UDim.new(0,14) mc.Parent=main
local ms=Instance.new("UIStroke") ms.Color=THEME.Stroke ms.Thickness=1 ms.Parent=main

local side=Instance.new("Frame")
side.Size=UDim2.new(0,190,1,0) side.BackgroundColor3=THEME.Panel
side.BorderSizePixel=0 side.Parent=main

local head=Instance.new("Frame")
head.Size=UDim2.new(1,0,0,100) head.BackgroundTransparency=1 head.Active=true head.Parent=side
local w1=Instance.new("TextLabel")
w1.Size=UDim2.new(1,-14,0,14) w1.Position=UDim2.new(0,7,0,10)
w1.BackgroundTransparency=1 w1.Text="welcome to" w1.Font=Enum.Font.Gotham
w1.TextSize=12 w1.TextColor3=THEME.TextDim w1.TextXAlignment=Enum.TextXAlignment.Left w1.Parent=head
local w2=Instance.new("TextLabel")
w2.Size=UDim2.new(1,-14,0,30) w2.Position=UDim2.new(0,7,0,24)
w2.BackgroundTransparency=1 w2.Text="NOVA" w2.Font=Enum.Font.GothamBold
w2.TextSize=24 w2.TextColor3=Color3.new(1,1,1) w2.TextXAlignment=Enum.TextXAlignment.Left w2.Parent=head
local w3=Instance.new("TextLabel")
w3.Size=UDim2.new(1,-14,0,16) w3.Position=UDim2.new(0,7,0,66)
w3.BackgroundTransparency=1 w3.Text="V 8.0 • "..GAME_VERSION w3.Font=Enum.Font.Gotham
w3.TextSize=12 w3.TextColor3=THEME.TextDim w3.TextXAlignment=Enum.TextXAlignment.Left w3.Parent=head
local headLine=Instance.new("Frame")
headLine.Size=UDim2.new(1,-14,0,2) headLine.Position=UDim2.new(0,7,0,92)
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
nav.Size=UDim2.new(1,-14,1,-100-110) nav.Position=UDim2.new(0,7,0,106)
nav.BackgroundTransparency=1 nav.Parent=side
local navList=Instance.new("UIListLayout")
navList.Padding=UDim.new(0,8) navList.SortOrder=Enum.SortOrder.LayoutOrder navList.Parent=nav
local navBtns={}
local function mkNavBtn(name, order)
    local b=Instance.new("TextButton")
    b.LayoutOrder=order b.Size=UDim2.new(1,0,0,40)
    b.Text=name b.Font=Enum.Font.GothamBold b.TextSize=15
    b.AutoButtonColor=false b.Active=true b.Parent=nav
    b.BackgroundColor3=THEME.Item b.TextColor3=THEME.TextDim
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,10) c.Parent=b
    local s=Instance.new("UIStroke") s.Color=THEME.Stroke s.Thickness=1 s.Transparency=0.6 s.Parent=b
    local ind=Instance.new("Frame")
    ind.Name="navInd" ind.Size=UDim2.new(0,3,0,18) ind.Position=UDim2.new(0,8,0.5,-9)
    ind.BackgroundColor3=THEME.Accent ind.BorderSizePixel=0 ind.Visible=false ind.Active=false ind.Parent=b
    local ic=Instance.new("UICorner") ic.CornerRadius=UDim.new(1,0) ic.Parent=ind
    b.MouseEnter:Connect(function()
        if not b:GetAttribute("navOn") then
            TweenService:Create(b,TweenInfo.new(0.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=THEME.Hover}):Play()
        end
    end)
    b.MouseLeave:Connect(function()
        if not b:GetAttribute("navOn") then
            TweenService:Create(b,TweenInfo.new(0.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=THEME.Item}):Play()
        end
    end)
    navBtns[name]=b
    return b
end
local navESP=mkNavBtn("ESP",1) local navAim=mkNavBtn("Aimbot",2) local navMisc=mkNavBtn("Misc",3) local navFarm=mkNavBtn("Farm",4) local navUtil=mkNavBtn("Utility",5)

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
content.Position=UDim2.new(0,204,0,14) content.Size=UDim2.new(1,-218,1,-28)
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
local espPage=mkPage() local aimPage=mkPage() local miscPage=mkPage() local farmPage=mkPage() local utilPage=mkPage()
aimPage.Visible=false miscPage.Visible=false farmPage.Visible=false utilPage.Visible=false

local curPage=espPage
local function slidePage(pg, x0, x1, dur, after)
    pg.Position=UDim2.new(0,x0,0,0)
    pg.Visible=true
    TweenService:Create(pg,TweenInfo.new(dur,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(0,x1,0,0)}):Play()
    if after then task.delay(dur, after) end
end
local function paintNav(which)
    local function st(b,on)
        b:SetAttribute("navOn",on)
        local ind=b:FindFirstChild("navInd")
        if ind then ind.Visible=on end
        TweenService:Create(b,TweenInfo.new(0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
            BackgroundColor3=on and THEME.Accent or THEME.Item,
            TextColor3=on and Color3.new(1,1,1) or THEME.TextDim
        }):Play()
    end
    st(navESP,which=="ESP") st(navAim,which=="Aim") st(navMisc,which=="Misc") st(navFarm,which=="Farm") st(navUtil,which=="Util")
end
local function setTab(w)
    local target=({ESP=espPage,Aim=aimPage,Misc=miscPage,Farm=farmPage,Util=utilPage})[w]
    if target==curPage then return end
    local old=curPage curPage=target
    for _,pg in ipairs({espPage,aimPage,miscPage,farmPage,utilPage}) do pg.CanvasPosition=Vector2.new(0,0) end
    if old then slidePage(old, 0, -24, 0.15, function() old.Visible=false end) end
    slidePage(target, 24, 0, 0.17)
    paintNav(w)
end
navESP.MouseButton1Click:Connect(function() setTab("ESP") end)
navAim.MouseButton1Click:Connect(function() setTab("Aim") end)
navMisc.MouseButton1Click:Connect(function() setTab("Misc") end)
navFarm.MouseButton1Click:Connect(function() setTab("Farm") end)
navUtil.MouseButton1Click:Connect(function() setTab("Util") end)
setTab("ESP")

local function setMenu(open)
    if menuBusy or open==menuOpen then return end
    menuBusy=true
    if open then
        menuOpen=true
        main.Visible=true
        main.Size=UDim2.new(0,700*0.94,0,500*0.92)
        TweenService:Create(main,TweenInfo.new(0.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(0,700,0,500)}):Play()
        task.delay(0.26,function() menuBusy=false end)
    else
        menuOpen=false
        TweenService:Create(main,TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Size=UDim2.new(0,700*0.94,0,500*0.92)}):Play()
        task.delay(0.14,function() main.Visible=false menuBusy=false end)
    end
end

-- WIDGETS
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
    local f=Instance.new("Frame")
    f.LayoutOrder=order f.Size=UDim2.new(scale or 1,off or -4,0,28)
    f.BackgroundColor3=THEME.Panel f.BorderSizePixel=0 f.Parent=parent
    f.Active=true
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=f
    local s=Instance.new("UIStroke") s.Color=THEME.Stroke s.Thickness=1 s.Transparency=0.5 s.Parent=f
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-58,1,0) lbl.Position=UDim2.new(0,11,0,0)
    lbl.BackgroundTransparency=1 lbl.Font=Enum.Font.GothamBold lbl.TextSize=12
    lbl.TextColor3=Color3.new(1,1,1) lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.Text=name lbl.Parent=f
    local track=Instance.new("Frame")
    track.Size=UDim2.new(0,34,0,18) track.Position=UDim2.new(1,-46,0.5,-9)
    track.BackgroundColor3=THEME.Item track.BorderSizePixel=0 track.Active=false track.Parent=f
    local tc=Instance.new("UICorner") tc.CornerRadius=UDim.new(0,9) tc.Parent=track
    local knob=Instance.new("Frame")
    knob.Size=UDim2.new(0,12,0,12) knob.Position=UDim2.new(0,3,0.5,-6)
    knob.BackgroundColor3=THEME.TextDim knob.BorderSizePixel=0 knob.Active=false knob.Parent=track
    local kc=Instance.new("UICorner") kc.CornerRadius=UDim.new(1,0) kc.Parent=knob
    local on=default
    local function paint(anim)
        local ti=TweenInfo.new(anim and 0.16 or 0,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
        if on then
            TweenService:Create(track,ti,{BackgroundColor3=THEME.Accent}):Play()
            TweenService:Create(knob,ti,{Position=UDim2.new(0,19,0.5,-6),BackgroundColor3=Color3.new(1,1,1)}):Play()
        else
            TweenService:Create(track,ti,{BackgroundColor3=THEME.Item}):Play()
            TweenService:Create(knob,ti,{Position=UDim2.new(0,3,0.5,-6),BackgroundColor3=THEME.TextDim}):Play()
        end
    end
    local function set(v)
        on=(v==true) paint(true) cb(on)
    end
    local function hoverT(en)
        TweenService:Create(f,TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=en and THEME.Hover or THEME.Panel}):Play()
        TweenService:Create(s,TweenInfo.new(0.12),{Transparency=en and 0.2 or 0.5}):Play()
    end
    f.MouseEnter:Connect(function() hoverT(true) end)
    f.MouseLeave:Connect(function() hoverT(false) end)
    f.MouseButton1Click:Connect(function() set(not on) end)
    paint(false)
    if id then regHandle(id,set) end
    return f
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
    local knob=Instance.new("Frame")
    knob.Size=UDim2.new(0,10,0,10) knob.Position=UDim2.new(0,-5,0.5,-5)
    knob.BackgroundColor3=Color3.new(1,1,1) knob.BorderSizePixel=0 knob.Active=false knob.Parent=bar
    local kc2=Instance.new("UICorner") kc2.CornerRadius=UDim.new(1,0) kc2.Parent=knob
    local function upd(v)
        v=math.clamp(math.floor(v),min,max)
        lbl.Text=name..":  "..tostring(v)
        local frac=(v-min)/span
        fill.Size=UDim2.new(frac,0,1,0)
        knob.Position=UDim2.new(frac,-5,0.5,-5)
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
            local data=nil
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then data={Type="Mouse",Button=Enum.UserInputType.MouseButton1,Name="LMB"}
            elseif inp.UserInputType==Enum.UserInputType.MouseButton2 then data={Type="Mouse",Button=Enum.UserInputType.MouseButton2,Name="RMB"}
            elseif inp.UserInputType==Enum.UserInputType.MouseButton3 then data={Type="Mouse",Button=Enum.UserInputType.MouseButton3,Name="MMB"}
            elseif inp.KeyCode~=Enum.KeyCode.Unknown then data={Type="Key",Key=inp.KeyCode,Name=inp.KeyCode.Name} end
            if data then listening=false conn:Disconnect() set(data) end
        end)
        track(conn)
    end)
    if id then regHandle(id,set) end
    return btn
end

-- ESP TAB
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
    createToggle(r,1,"Inventory","Inventory",false,function(v) Settings.Inventory=v end,0.5,-3)
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

-- AIMBOT + TRIGGERBOT TAB
local ab=1
pageHeader(aimPage,ab,"Aimbot") ab=ab+1
do local r=newRow(aimPage,ab); ab=ab+1
    createToggle(r,1,"AimEnabled","Aimbot",false,function(v) Settings.AimEnabled=v aimingOn=false end,0.5,-3)
    createToggle(r,2,"ShowFOV","Show FOV",true,function(v) Settings.ShowFOV=v end,0.5,-3)
end
createDropdown(aimPage,ab,"AimMethod","Method",{"Camera","Mouse"},Settings.AimMethod,function(v) Settings.AimMethod=v end) ab=ab+1
createDropdown(aimPage,ab,"AimMode","Mode",{"Hold","Toggle"},Settings.AimMode,function(v) Settings.AimMode=v aimingOn=false end) ab=ab+1
createKeyPicker(aimPage,ab,"AimKey","Hold Key","RMB",function(d) Settings.AimKey=d aimingOn=false kb.refresh() end) ab=ab+1
createSlider(aimPage,ab,"FOV","FOV",20,500,Settings.FOV,function(v) Settings.FOV=v end) ab=ab+1
createSlider(aimPage,ab,"Smoothing","Smoothing",1,20,Settings.Smoothing,function(v) Settings.Smoothing=v end) ab=ab+1
createSlider(aimPage,ab,"Prediction","Prediction",0,20,Settings.Prediction,function(v) Settings.Prediction=v end) ab=ab+1
createDropdown(aimPage,ab,"Target","Target",{"Head","HRP","Closest"},Settings.Target,function(v) Settings.Target=v end) ab=ab+1
createDropdown(aimPage,ab,"Priority","Priority",{"Closest","Low HP"},Settings.Priority,function(v) Settings.Priority=v end) ab=ab+1
do local r=newRow(aimPage,ab); ab=ab+1
    createToggle(r,1,"AimTeamCheck","Team Check",true,function(v) Settings.AimTeamCheck=v end,0.5,-3)
    createToggle(r,2,"WallCheck","Wall Check",true,function(v) Settings.WallCheck=v end,0.5,-3)
end
createToggle(aimPage,ab,"AimLock","Target Lock",false,function(v) Settings.AimLock=v lockedPlayer=nil end) ab=ab+1
createToggle(aimPage,ab,"NoKnock","No Knocked",true,function(v) Settings.NoKnock=v end) ab=ab+1
createSlider(aimPage,ab,"MaxDistance","Max Distance",100,5000,Settings.MaxDistance,function(v) Settings.MaxDistance=v end) ab=ab+1

local tc=1
pageHeader(aimPage,tc,"Triggerbot") tc=tc+1
createToggle(aimPage,tc,"TrigEnabled","Triggerbot",false,function(v) Settings.TrigEnabled=v trigAcquireT=0 kb.refresh() end) tc=tc+1
createDropdown(aimPage,tc,"TrigMode","Mode",{"Always","Hold Key"},Settings.TrigMode,function(v) Settings.TrigMode=v trigAcquireT=0 end) tc=tc+1
createDropdown(aimPage,tc,"TrigTarget","Hit Part",{"Any","Head","HRP"},Settings.TrigTarget,function(v) Settings.TrigTarget=v trigAcquireT=0 end) tc=tc+1
do local r=newRow(aimPage,tc); tc=tc+1
    createToggle(r,1,"TrigTeamCheck","Team Check",true,function(v) Settings.TrigTeamCheck=v end,0.5,-3)
    createToggle(r,2,"TrigNoKnock","No Knocked",true,function(v) Settings.TrigNoKnock=v end,0.5,-3)
end
createSlider(aimPage,tc,"TrigDelay","Reaction Delay (ms)",0,500,Settings.TrigDelay,function(v) Settings.TrigDelay=v trigAcquireT=0 end) tc=tc+1
do
    local info=Instance.new("TextLabel")
    info.LayoutOrder=tc tc=tc+1 info.Size=UDim2.new(1,-4,0,30)
    info.BackgroundTransparency=1 info.Text="Fires when the crosshair is on a valid target."
    info.Font=Enum.Font.Gotham info.TextSize=11 info.TextColor3=THEME.TextDim
    info.TextWrapped=true info.Parent=aimPage
end
local trigMsgLbl=Instance.new("TextLabel")
trigMsgLbl.LayoutOrder=tc tc=tc+1 trigMsgLbl.Size=UDim2.new(1,-4,0,16) trigMsgLbl.BackgroundTransparency=1
trigMsgLbl.Text="status: off" trigMsgLbl.Font=Enum.Font.Gotham
trigMsgLbl.TextSize=11 trigMsgLbl.TextColor3=THEME.TextDim trigMsgLbl.TextXAlignment=Enum.TextXAlignment.Left trigMsgLbl.Parent=aimPage

-- UTILITY TAB
local Util = {WalkSpeed=16, JumpPower=50, InfJump=false, Fly=false, FlySpeed=60,
    Noclip=false, Fullbright=false, CamFOV=70, ClickTP=false, Crosshair=false}
local origLight = nil
local lastUtilSync = 0

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

-- MISC TAB
local kb = {win=nil, lines={}, on=true}
local mo=1
pageHeader(miscPage,mo,"Misc") mo=mo+1
local statLbl=Instance.new("TextLabel")
statLbl.LayoutOrder=mo mo=mo+1 statLbl.Size=UDim2.new(1,-4,0,20) statLbl.BackgroundTransparency=1
statLbl.Text="NOVA v8.0 • "..GAME_VERSION statLbl.Font=Enum.Font.GothamBold
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
cfgNameBox.BackgroundColor3=THEME.Item cfgNameBox.Text="" cfgNameBox.PlaceholderText="e.g. main"
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

-- FARM SYSTEMS (South Bronx map: ATM prompts, marsh field, teleport)
local SB = {SafeTP=true, AutoATM=false, ATMCooldown=10, MarshFarm=false}
local sbATMs = {}
local sbSpots = {}
local SB_POIS = {
    {"Bank", -52.00, -3.42, -333.68},
    {"Hospital", 1065.49, -3.80, 529.20},
    {"Dealership", 730.46, -3.45, 446.10},
    {"Marshmallow", 509.78, -3.57, 599.79},
    {"Illegal Guns", 753.72, -3.67, 41.51},
    {"Gun Shop 1", 219.32, -3.43, -177.49},
    {"Gun Shop 2", -466.83, -3.30, 350.52},
    {"Boxes", -534.31, -3.42, -84.77},
    {"Buy Potato", -797.78, -3.50, -170.59},
    {"Casino", 1176.07, -3.40, -20.96},
}
local farmMsgLbl, atmCountLbl, atmMsgLbl, tpMsgLbl, tpBox
local function farmMsg(t) pcall(function() if farmMsgLbl then farmMsgLbl.Text=t end end) end
local function atmMsg(t) pcall(function() if atmMsgLbl then atmMsgLbl.Text=t end end) end
local function tpMsg(t) pcall(function() if tpMsgLbl then tpMsgLbl.Text=t end end) end

local function groundY(x, z)
    local char=LocalPlayer.Character
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.IgnoreWater=true
    params.FilterDescendantsInstances=char and {char} or {}
    local res=Workspace:Raycast(Vector3.new(x,120,z), Vector3.new(0,-300,0), params)
    if res then return res.Position.Y+3 end
    return nil
end

local function teleportTo(cf)
    local char=LocalPlayer.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then farmMsg("no character") return false end
    local dest=cf
    local gy=groundY(cf.Position.X, cf.Position.Z)
    if gy then
        local flat=hrp.CFrame-hrp.CFrame.Position
        dest=CFrame.new(cf.Position.X, gy, cf.Position.Z)*flat
    end
    local ok=false
    pcall(function()
        if SB.SafeTP then
            local dist=(hrp.Position-dest.Position).Magnitude
            local tw=TweenService:Create(hrp, TweenInfo.new(math.clamp(dist/120,0.4,2), Enum.EasingStyle.Linear), {CFrame=dest})
            tw:Play()
        else
            hrp.CFrame=dest
        end
        ok=true
    end)
    return ok
end

local function fireNearbyPrompts(radius)
    if typeof(fireproximityprompt)~="function" then return -1 end
    local char=LocalPlayer.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end
    local n=0
    for _,d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local okp, part = pcall(function()
                local a=d.Parent
                if a and a:IsA("BasePart") then return a end
                if a and a:IsA("Attachment") then return a.Parent end
                local m=d:FindFirstAncestorOfClass("Model")
                if m then return m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true) end
                return nil
            end)
            if okp and part and typeof(part.Position)=="Vector3" and (part.Position-hrp.Position).Magnitude<=radius then
                pcall(fireproximityprompt, d)
                n=n+1
            end
        end
    end
    return n
end

local function scanATMs()
    sbATMs={}
    for _,d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local okp, info = pcall(function()
                local m=d:FindFirstAncestorOfClass("Model")
                local nm=((m and m.Name) or (d.Parent and d.Parent.Name) or ""):lower()
                if not nm:find("atm") then return nil end
                local part=nil
                local a=d.Parent
                if a and a:IsA("BasePart") then part=a
                elseif m then part=m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true) end
                if part then return {prompt=d, pos=part.Position} end
                return nil
            end)
            if okp and info then table.insert(sbATMs, info) end
        end
    end
    return #sbATMs
end

local function atmLoop()
    task.spawn(function()
        if typeof(fireproximityprompt)~="function" then atmMsg("need fireproximityprompt") end
        while SB.AutoATM and not Unloaded and not runStale() do
            if #sbATMs==0 then
                atmMsg("no ATMs — press Scan")
                task.wait(1)
            else
                for i,atm in ipairs(sbATMs) do
                    if not SB.AutoATM or Unloaded then break end
                    local char=LocalPlayer.Character
                    local hrp=char and char:FindFirstChild("HumanoidRootPart")
                    if not hrp then break end
                    if atm.prompt and atm.prompt.Parent then
                        atmMsg("ATM "..i.."/"..#sbATMs)
                        teleportTo(CFrame.new(atm.pos+Vector3.new(0,3,0)))
                        task.wait(1.2)
                        pcall(fireproximityprompt, atm.prompt)
                    end
                    local waited=0
                    while waited<SB.ATMCooldown and SB.AutoATM and not Unloaded do task.wait(0.5) waited=waited+0.5 end
                end
            end
        end
    end)
end

local function marshLoop()
    task.spawn(function()
        local field=findMarshField()
        while SB.MarshFarm and not Unloaded and not runStale() do
            if field then
                teleportTo(CFrame.new(field[2], field[3], field[4]))
                task.wait(1.5)
            end
            local t=0
            while t<45 and SB.MarshFarm and not Unloaded do
                local n=fireNearbyPrompts(18)
                if n<0 then farmMsg("need fireproximityprompt") task.wait(2)
                else farmMsg("marsh: "..n.." prompts fired") task.wait(2) end
                t=t+2
            end
        end
    end)
end

local function findMarshField()
    for _,e in ipairs(SB_POIS) do if e[1]=="Marshmallow" then return e end end
    return nil
end

local function findPlayerPartial(s)
    s=(s or ""):lower()
    if s=="" then return nil end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and (p.Name:lower():find(s,1,true) or p.DisplayName:lower():find(s,1,true)) then
            return p
        end
    end
    return nil
end

local function findPOI(s)
    s=(s or ""):lower()
    if s=="" then return nil end
    for _,e in ipairs(SB_POIS) do
        if e[1]:lower():find(s,1,true) then return e end
    end
    return nil
end

-- FARM TAB (southbronx only)
do
    local fz=1
    pageHeader(farmPage,fz,"Farm — South Bronx") fz=fz+1
    createToggle(farmPage,fz,nil,"Safe Tween TP",true,function(v) SB.SafeTP=v end) fz=fz+1
    local scanBtn=Instance.new("TextButton")
    scanBtn.LayoutOrder=fz fz=fz+1 scanBtn.Size=UDim2.new(1,-4,0,28) scanBtn.Text="Scan ATMs"
    scanBtn.Font=Enum.Font.GothamBold scanBtn.TextSize=13 scanBtn.BackgroundColor3=THEME.Item
    scanBtn.TextColor3=Color3.new(1,1,1) scanBtn.AutoButtonColor=false scanBtn.Active=true scanBtn.Parent=farmPage
    local scanBtnC=Instance.new("UICorner") scanBtnC.CornerRadius=UDim.new(0,8) scanBtnC.Parent=scanBtn
    atmCountLbl=Instance.new("TextLabel")
    atmCountLbl.LayoutOrder=fz fz=fz+1 atmCountLbl.Size=UDim2.new(1,-4,0,16) atmCountLbl.BackgroundTransparency=1
    atmCountLbl.Text="ATMs found: --" atmCountLbl.Font=Enum.Font.Gotham
    atmCountLbl.TextSize=12 atmCountLbl.TextColor3=THEME.TextDim atmCountLbl.TextXAlignment=Enum.TextXAlignment.Left atmCountLbl.Parent=farmPage
    scanBtn.MouseButton1Click:Connect(function()
        local n=0
        pcall(function() n=scanATMs() end)
        atmCountLbl.Text="ATMs found: "..n
        notify("Farm", n.." ATMs found")
    end)
    createToggle(farmPage,fz,nil,"Auto ATM Farm",false,function(v) SB.AutoATM=v if v then atmLoop() end end) fz=fz+1
    createSlider(farmPage,fz,nil,"ATM Cooldown",4,30,SB.ATMCooldown,function(v) SB.ATMCooldown=v end) fz=fz+1
    createToggle(farmPage,fz,nil,"Marshmallow Farm",false,function(v) SB.MarshFarm=v if v then marshLoop() end end) fz=fz+1
    atmMsgLbl=Instance.new("TextLabel")
    atmMsgLbl.LayoutOrder=fz fz=fz+1 atmMsgLbl.Size=UDim2.new(1,-4,0,16) atmMsgLbl.BackgroundTransparency=1
    atmMsgLbl.Text="" atmMsgLbl.Font=Enum.Font.Gotham
    atmMsgLbl.TextSize=11 atmMsgLbl.TextColor3=THEME.TextDim atmMsgLbl.TextXAlignment=Enum.TextXAlignment.Left atmMsgLbl.Parent=farmPage
    farmMsgLbl=atmMsgLbl
    tpBox=Instance.new("TextBox")
    tpBox.LayoutOrder=fz fz=fz+1 tpBox.Size=UDim2.new(1,-4,0,28)
    tpBox.BackgroundColor3=THEME.Item tpBox.Text="" tpBox.PlaceholderText="player, spot or place (e.g. bank)"
    tpBox.Font=Enum.Font.Gotham tpBox.TextSize=13 tpBox.TextColor3=Color3.new(1,1,1)
    tpBox.ClearTextOnFocus=false tpBox.Parent=farmPage
    local tpBoxC=Instance.new("UICorner") tpBoxC.CornerRadius=UDim.new(0,8) tpBoxC.Parent=tpBox
    do local r=newRow(farmPage,fz); fz=fz+1
        local saveBtn=Instance.new("TextButton")
        saveBtn.LayoutOrder=1 saveBtn.Size=UDim2.new(0.5,-3,0,28) saveBtn.Text="Save Spot"
        saveBtn.Font=Enum.Font.GothamBold saveBtn.TextSize=13 saveBtn.BackgroundColor3=THEME.Item
        saveBtn.TextColor3=Color3.new(1,1,1) saveBtn.AutoButtonColor=false saveBtn.Active=true saveBtn.Parent=r
        local saveBtnC=Instance.new("UICorner") saveBtnC.CornerRadius=UDim.new(0,8) saveBtnC.Parent=saveBtn
        local tpBtn=Instance.new("TextButton")
        tpBtn.LayoutOrder=2 tpBtn.Size=UDim2.new(0.5,-3,0,28) tpBtn.Text="Teleport"
        tpBtn.Font=Enum.Font.GothamBold tpBtn.TextSize=13 tpBtn.BackgroundColor3=THEME.Accent
        tpBtn.TextColor3=Color3.new(1,1,1) tpBtn.AutoButtonColor=false tpBtn.Active=true tpBtn.Parent=r
        local tpBtnC=Instance.new("UICorner") tpBtnC.CornerRadius=UDim.new(0,8) tpBtnC.Parent=tpBtn
        saveBtn.MouseButton1Click:Connect(function()
            local n=((tpBox.Text or ""):gsub("^%s+",""):gsub("%s+$",""):lower())
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if n~="" and hrp then sbSpots[n]=hrp.Position tpMsg("saved '"..n.."'") else tpMsg("type a name first") end
        end)
        tpBtn.MouseButton1Click:Connect(function()
            local q=((tpBox.Text or ""):gsub("^%s+",""):gsub("%s+$",""):lower())
            if q=="" then tpMsg("type a name first") return end
            local p=findPlayerPartial(q)
            if p and p.Character then
                local hrp=p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if teleportTo(CFrame.new(hrp.Position+Vector3.new(0,3,0))) then tpMsg("tp: "..p.DisplayName) else tpMsg("tp failed") end
                    return
                end
            end
            if sbSpots[q] then
                local v=sbSpots[q]
                if teleportTo(CFrame.new(v.X, v.Y+1, v.Z)) then tpMsg("tp: spot '"..q.."'") else tpMsg("tp failed") end
                return
            end
            local poi=findPOI(q)
            if poi then
                if teleportTo(CFrame.new(poi[2], poi[3], poi[4])) then tpMsg("tp: "..poi[1]) else tpMsg("tp failed") end
                return
            end
            tpMsg("not found: "..q)
        end)
    end
    tpMsgLbl=Instance.new("TextLabel")
    tpMsgLbl.LayoutOrder=fz fz=fz+1 tpMsgLbl.Size=UDim2.new(1,-4,0,16) tpMsgLbl.BackgroundTransparency=1
    tpMsgLbl.Text="" tpMsgLbl.Font=Enum.Font.Gotham
    tpMsgLbl.TextSize=11 tpMsgLbl.TextColor3=THEME.TextDim tpMsgLbl.TextXAlignment=Enum.TextXAlignment.Left tpMsgLbl.Parent=farmPage
end

-- ESP RUNTIME
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
        local e = invCache[player]
        local nowC=os.clock()
        if e and nowC-e.t < INV_TTL then
            txt=txt..(txt~="" and "\n" or "")..e.s
        else
            local inv={}
            for _,t in ipairs(getTools(player)) do table.insert(inv, t.Name) end
            local s=""
            if #inv>0 then
                local shown=table.concat(inv, ", ", 1, math.min(#inv, 4))
                if #inv>4 then shown=shown.." +"..(#inv-4) end
                s="["..shown.."]"
            end
            invCache[player]={t=nowC, s=s}
            txt=txt..(txt~="" and "\n" or "")..s
        end
    end
    return txt
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
    local parts=getCharParts(char)
    if not parts then creating[player]=nil return end
    local hrp,head,hum=parts.hrp,parts.head,parts.hum
    local boxGui=Instance.new("BillboardGui")
    boxGui.Name="NovaBox" boxGui.Adornee=hrp boxGui.AlwaysOnTop=true boxGui.LightInfluence=0
    boxGui.Size=UDim2.new(4,0,6.5,0) boxGui.ExtentsOffsetWorldSpace=Vector3.new(0,0.5,0) boxGui.Parent=hrp
    pcall(function() boxGui:SetAttribute("nx",1) end)
    local bf=Instance.new("Frame") bf.Size=UDim2.new(1,0,1,0) bf.BackgroundTransparency=1 bf.Active=false bf.Parent=boxGui
    local stroke=Instance.new("UIStroke") stroke.Thickness=2 stroke.Color=Settings.Color stroke.Parent=bf
    local nameGui=Instance.new("BillboardGui")
    nameGui.Name="NovaTag" nameGui.Adornee=head nameGui.AlwaysOnTop=true
    nameGui.Size=UDim2.new(0,220,0,44) nameGui.ExtentsOffsetWorldSpace=Vector3.new(0,3.2,0)
    nameGui.LightInfluence=0 nameGui.Parent=head
    pcall(function() nameGui:SetAttribute("nx",1) end)
    local label=Instance.new("TextLabel")
    label.Size=UDim2.new(1,0,1,0) label.BackgroundTransparency=1
    label.Font=Enum.Font.GothamBold label.TextSize=13 label.TextStrokeTransparency=0
    label.TextXAlignment=Enum.TextXAlignment.Center
    label.Text="" label.TextColor3=Settings.Color label.Parent=nameGui
    local myHrp0=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    label.Text=buildLabelText(player, hrp, myHrp0)
    local cham=Instance.new("Highlight")
    cham.Name="ESPHL" cham.Adornee=char cham.FillTransparency=1
    cham.OutlineColor=Settings.Color cham.OutlineTransparency=0.25
    cham.Enabled=false cham.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop cham.Parent=char
    pcall(function() cham:SetAttribute("nx",1) end)
    local hpBG=Instance.new("Frame")
    hpBG.Size=UDim2.new(0,120,0,6) hpBG.Position=UDim2.new(0.5,-60,1,-8)
    hpBG.BackgroundColor3=Color3.fromRGB(20,20,25) hpBG.BorderSizePixel=0 hpBG.Visible=false hpBG.Active=false hpBG.Parent=nameGui
    local hpBGC=Instance.new("UICorner") hpBGC.CornerRadius=UDim.new(0,3) hpBGC.Parent=hpBG
    local hpFill=Instance.new("Frame")
    hpFill.Size=UDim2.new(1,0,1,0) hpFill.BackgroundColor3=Color3.fromRGB(80,255,120)
    hpFill.BorderSizePixel=0 hpFill.Active=false hpFill.Parent=hpBG
    local tracer=Instance.new("Frame")
    tracer.AnchorPoint=Vector2.new(0.5,0.5) tracer.BorderSizePixel=0 tracer.Active=false
    tracer.BackgroundColor3=Settings.Color tracer.Visible=false tracer.Parent=overlayGui
    ESPData[player]={boxGui=boxGui,stroke=stroke,nameGui=nameGui,nameLabel=label,parts={Head=head,HRP=hrp,Upper=parts.torso},hrp=hrp,hum=hum,tracer=tracer,cham=cham,hpBG=hpBG,hpFill=hpFill}
    creating[player]=nil
end

local function tryCreate(player)
    if creating[player] then return end
    local now=os.clock()
    if lastAttempt[player] and now-lastAttempt[player] < 1 then return end
    lastAttempt[player]=now
    task.spawn(createESP,player)
end

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
end

-- COMBAT
local rayParams=RaycastParams.new() rayParams.FilterType=Enum.RaycastFilterType.Exclude rayParams.IgnoreWater=true
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
local function trigPartOK(nm)
    local t = Settings.TrigTarget
    if t == "Any" then return true end
    if t == "Head" then return nm == "Head" or nm == "HeadHB" end
    if t == "HRP" then return nm == "HumanoidRootPart" or nm == "Torso" end
    return true
end
local function trigValidate(inst, myHrp)
    if not inst then return false end
    local hitModel = inst:FindFirstAncestorOfClass("Model")
    local tp = hitModel and Players:GetPlayerFromCharacter(hitModel) or nil
    if not tp or tp == LocalPlayer then return false end
    local ch = tp.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not ch or not hum or hum.Health <= 0 then return false end
    if Settings.TrigTeamCheck and tp.Team and LocalPlayer.Team and tp.Team == LocalPlayer.Team then return false end
    if Settings.TrigNoKnock and isDownCached(ch, hum) then return false end
    if not trigPartOK(inst.Name) then return false end
    local hp = ch:FindFirstChild("HumanoidRootPart")
    if hp and (myHrp.Position - hp.Position).Magnitude > Settings.MaxDistance then return false end
    return true
end
local function doTrigger(cam, myHrp, nowC)
    -- Bullets fire through the crosshair = viewport center, NOT the raw mouse
    -- cursor (in FPS games the cursor sits wherever it last was; the camera
    -- does the aiming). Raycast from the center or the bot can never lock.
    if not Settings.TrigEnabled or Unloaded or not myHrp then
        trigAcquireT = 0
        setTrigState("off", nowC)
        return
    end
    local typing = false
    pcall(function() typing = UserInputService:GetFocusedTextBox() ~= nil end)
    if typing then
        trigAcquireT = 0
        setTrigState("paused (typing)", nowC)
        return
    end
    if Settings.TrigMode=="Hold Key" and not isAimHeld() then
        trigAcquireT = 0
        setTrigState("hold key...", nowC)
        return
    end
    local vpsz=cam.ViewportSize
    local ray = nil
    pcall(function() ray = cam:ScreenPointToRay(vpsz.X*0.5, vpsz.Y*0.5) end)
    if not ray then
        trigAcquireT = 0
        setTrigState("scanning", nowC)
        return
    end
    local excl = {}
    if LocalPlayer.Character then excl[#excl+1] = LocalPlayer.Character end
    excl[#excl+1] = cam
    rayParams.FilterDescendantsInstances = excl
    local res = nil
    pcall(function() res = Workspace:Raycast(ray.Origin, ray.Direction*1000, rayParams) end)
    local valid = trigValidate(res and res.Instance, myHrp)
    if not valid and res and res.Instance then
        local okNC, nc = pcall(function() return res.Instance.CanCollide end)
        local d0 = (res.Position - ray.Origin).Magnitude
        if okNC and nc == false and d0 <= 15 then
            local hm0 = res.Instance:FindFirstAncestorOfClass("Model")
            local pl0 = hm0 and Players:GetPlayerFromCharacter(hm0) or nil
            if pl0 == nil then
                excl[#excl+1] = hm0 or res.Instance
                rayParams.FilterDescendantsInstances = excl
                local res2 = nil
                pcall(function() res2 = Workspace:Raycast(ray.Origin, ray.Direction*1000, rayParams) end)
                valid = trigValidate(res2 and res2.Instance, myHrp)
            end
        end
    end
    if valid then
        if trigAcquireT==0 then trigAcquireT=nowC setTrigState("locked", nowC) end
        if nowC-trigAcquireT >= Settings.TrigDelay/1000 then
            trigAcquireT=nowC
            local mx, my = vpsz.X*0.5, vpsz.Y*0.5
            local how=fireClick(mx, my)
            if how then setTrigState("firing ("..how..")", nowC)
            else
                setTrigState("NO CLICK API", nowC)
                warn("[NOVA] triggerbot: no click method (mouse1click/VIM/tool)")
            end
        end
    else
        trigAcquireT=0
        setTrigState("scanning", nowC)
    end
end

-- UTILITY RUNTIME
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

-- CONFIGS
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
        Chams=Settings.Chams, HealthBar=Settings.HealthBar,
        Color={math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5)},
        AimEnabled=Settings.AimEnabled, AimMethod=Settings.AimMethod, AimMode=Settings.AimMode,
        FOV=Settings.FOV, ShowFOV=Settings.ShowFOV, Smoothing=Settings.Smoothing,
        Target=Settings.Target, Priority=Settings.Priority, AimLock=Settings.AimLock,
        Prediction=Settings.Prediction,
        AimTeamCheck=Settings.AimTeamCheck, WallCheck=Settings.WallCheck, NoKnock=Settings.NoKnock,
        TrigEnabled=Settings.TrigEnabled, TrigMode=Settings.TrigMode, TrigTarget=Settings.TrigTarget,
        TrigTeamCheck=Settings.TrigTeamCheck, TrigNoKnock=Settings.TrigNoKnock, TrigDelay=Settings.TrigDelay,
        MaxDistance=Settings.MaxDistance, AFKProtect=Settings.AFKProtect,
        Keybinds=kb.on, FPSCap=Settings.FPSCap,
        WalkSpeed=Util.WalkSpeed, JumpPower=Util.JumpPower, InfJump=Util.InfJump,
        Fly=Util.Fly, FlySpeed=Util.FlySpeed, Noclip=Util.Noclip,
        Fullbright=Util.Fullbright, CamFOV=Util.CamFOV, ClickTP=Util.ClickTP, Crosshair=Util.Crosshair,
        SafeTP=SB.SafeTP, AutoATM=SB.AutoATM, ATMCooldown=SB.ATMCooldown, MarshFarm=SB.MarshFarm,
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
    for _, id in ipairs({"ESPEnabled","Boxes","Names","Distance","TeamCheck","MaxESP","OverlayY","Tracers","Inventory","Chams",
        "HealthBar","AimEnabled","AimMethod","AimMode","FOV","ShowFOV","Smoothing","Target","Priority",
        "AimLock","Prediction","AimTeamCheck","WallCheck","NoKnock",
        "TrigEnabled","TrigMode","TrigTarget","TrigTeamCheck","TrigNoKnock","TrigDelay",
        "MaxDistance","AFKProtect","Keybinds","FPSCap",
        "WalkSpeed","JumpPower","InfJump","Fly","FlySpeed","Noclip","Fullbright","CamFOV","ClickTP","Crosshair",
        "SafeTP","AutoATM","ATMCooldown","MarshFarm"}) do
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

-- CONNECTIONS
for _,p in ipairs(Players:GetPlayers()) do
    if p~=LocalPlayer then
        track(p.CharacterAdded:Connect(function()
            if runStale() then return end
            if not LoadingDone or Unloaded then return end
            clearESP(p) task.wait(1) if LoadingDone and not Unloaded and not runStale() then createESP(p) end
        end))
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

-- RENDER LOOP
local renderConn=nil
renderConn=track(RunService.RenderStepped:Connect(function()
    if runStale() then pcall(function() renderConn:Disconnect() end) return end
    if Unloaded or not LoadingDone then fovCircle.Visible=false return end
    frameCount = frameCount + 1
    local doLabels=(frameCount%12==0)
    local doTracers=(frameCount%3==0)
    local doTrig=(frameCount%2==0)
    local cam=Workspace.CurrentCamera if not cam then return end
    local mouseRaw=UserInputService:GetMouseLocation()
    local vpsz=cam.ViewportSize
    local asz=overlayGui.AbsoluteSize
    local offX=asz.X-vpsz.X local offY=asz.Y-vpsz.Y
    local mousePos=Vector2.new(mouseRaw.X-offX, mouseRaw.Y-offY)
    local col=Settings.Color
    local espOn=Settings.ESPEnabled
    local boxesOn=Settings.Boxes
    local namesOn=Settings.Names or Settings.Distance or Settings.HealthBar
    local hpOn=Settings.HealthBar
    local chamOn=Settings.Chams
    local tracersOn=Settings.Tracers
    local maxESP2=Settings.MaxESP*Settings.MaxESP
    if Settings.AimEnabled and Settings.ShowFOV then
        fovCircle.Visible=true
        if lastFOV~=Settings.FOV then
            lastFOV=Settings.FOV
            fovCircle.Size=UDim2.new(0,Settings.FOV*2,0,Settings.FOV*2)
        end
        if mouseRaw.X~=lastMX or mouseRaw.Y~=lastMY then
            lastMX,lastMY=mouseRaw.X,mouseRaw.Y
            fovCircle.Position=UDim2.new(0,mouseRaw.X,0,mouseRaw.Y)
        end
    else fovCircle.Visible=false end
    if Util.Crosshair then
        cross.H.Visible=true cross.V.Visible=true
        if mouseRaw.X~=lastCX or mouseRaw.Y~=lastCY then
            lastCX,lastCY=mouseRaw.X,mouseRaw.Y
            cross.H.Position=UDim2.new(0,mouseRaw.X,0,mouseRaw.Y)
            cross.V.Position=UDim2.new(0,mouseRaw.X,0,mouseRaw.Y)
        end
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
                local flags=(boxesOn and 1 or 0)+(namesOn and 2 or 0)+(chamOn and 4 or 0)+(hpOn and 8 or 0)
                if d.lastShow==show and d.lastFlags==flags and d.lastColOK then
                    if show then
                        if doLabels then
                            local nt=buildLabelText(player, hrp, myHrp)
                            if d.nameLabel.Text~=nt then d.nameLabel.Text=nt end
                            if d.nameLabel.TextColor3~=col then d.nameLabel.TextColor3=col end
                            if hpOn and d.hpFill then
                                local frac=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
                                local qf=math.floor(frac*20+0.5)
                                if qf~=d.lastHpQ then
                                    d.lastHpQ=qf
                                    d.hpFill.Size=UDim2.new(qf/20,0,1,0)
                                    d.hpFill.BackgroundColor3=Color3.fromRGB(math.floor(255*(1-qf/20)),math.floor(255*(qf/20)),60)
                                end
                            end
                        end
                        if doTracers and tracersOn and scrW>0 then
                            local sp,ok=cam:WorldToViewportPoint(hrp.Position)
                            if ok then
                                d.lastTracer=true
                                drawLine(d.tracer, scrW*0.5, scrH, sp.X+offX, sp.Y+offY+Settings.OverlayY, col)
                            elseif d.lastTracer then
                                d.lastTracer=false
                                d.tracer.Visible=false
                            end
                        elseif d.lastTracer or d.lastTracer==nil then
                            d.lastTracer=false
                            d.tracer.Visible=false
                        end
                    end
                else
                    d.lastShow=show d.lastFlags=flags d.lastHpQ=nil d.lastTracer=nil
                    d.boxGui.Enabled=show and boxesOn
                    d.nameGui.Enabled=show and namesOn
                    if d.stroke.Color~=col then d.stroke.Color=col end
                    d.lastColOK=(d.stroke.Color==col)
                    if d.hpBG then d.hpBG.Visible=show and hpOn end
                    if d.cham then
                        if d.cham.FillColor~=col then d.cham.FillColor=col end
                        if d.cham.OutlineColor~=col then d.cham.OutlineColor=col end
                        d.cham.Enabled=show and chamOn
                    end
                    if show then
                        if doLabels then
                            local nt=buildLabelText(player, hrp, myHrp)
                            if d.nameLabel.Text~=nt then d.nameLabel.Text=nt end
                            if d.nameLabel.TextColor3~=col then d.nameLabel.TextColor3=col end
                        elseif d.nameLabel.TextColor3~=col then
                            d.nameLabel.TextColor3=col
                        end
                        if hpOn and d.hpFill then
                            local frac=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
                            local qf=math.floor(frac*20+0.5)
                            d.lastHpQ=qf
                            d.hpFill.Size=UDim2.new(qf/20,0,1,0)
                            d.hpFill.BackgroundColor3=Color3.fromRGB(math.floor(255*(1-qf/20)),math.floor(255*(qf/20)),60)
                        end
                        if doTracers and tracersOn and scrW>0 then
                            local sp,ok=cam:WorldToViewportPoint(hrp.Position)
                            if ok then
                                d.lastTracer=true
                                drawLine(d.tracer, scrW*0.5, scrH, sp.X+offX, sp.Y+offY+Settings.OverlayY, col)
                            end
                        else
                            d.tracer.Visible=false
                            d.lastTracer=false
                        end
                    else
                        d.tracer.Visible=false
                        d.lastTracer=false
                        hideOverlay(d)
                    end
                end
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
    if doTrig then
        doTrigger(cam, myHrp, nowC)
    end
    local wantAim=false
    if Settings.AimEnabled and not Unloaded then
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
            if Settings.AimMethod=="Mouse" and hasMouseMove then
                local sp,_=cam:WorldToViewportPoint(bestPos)
                local s=math.max(1,Settings.Smoothing)
                pcall(function() mousemoverel((sp.X-mousePos.X)/s,(sp.Y-mousePos.Y)/s) end)
            else
                local goal=CFrame.new(cam.CFrame.Position,bestPos)
                cam.CFrame=cam.CFrame:Lerp(goal,math.clamp(1/math.max(1,Settings.Smoothing),0.05,1))
            end
        end
    else
        lockedPlayer=nil
    end
end))

-- INPUT
track(UserInputService.InputBegan:Connect(function(inp,gpe)
    if Unloaded or runStale() then return end
    if keyMatches(Settings.PanicKey, inp) and not gpe then
        main.Visible=false
        Unload()
        return
    end
    if gpe then return end
    if keyMatches(Settings.MenuKey, inp) then setMenu(not menuOpen) return end
    if Settings.AimMode=="Toggle" and Settings.AimEnabled and keyMatches(Settings.AimKey, inp) then
        aimingOn=not aimingOn
    end
end))

-- UNLOAD
local function Unload()
    if Unloaded then return end Unloaded=true
    activeDragFn=nil aimingOn=false openDropClose=nil
    if Util.Fly then Util.Fly=false stopFly() end
    if Util.Fullbright then Util.Fullbright=false setFullbright(false) end
    for _,c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    for p,_ in pairs(ESPData) do clearESP(p) end
    for _,p in ipairs(Players:GetPlayers()) do if p.Character then deepCleanCharacter(p.Character) end end
    pcall(function() overlayGui:Destroy() end) pcall(function() fovGui:Destroy() end) pcall(function() gui:Destroy() end)
end
unloadBtn.MouseButton1Click:Connect(Unload)

-- BOOT
local function finishLoading()
    if Unloaded or LoadingDone or not gateOpen() then return end
    LoadingDone=true
    print("[NOVA] v8.0 loaded ("..FILE_TAG.." / "..GAME_VERSION..")")
    pcall(function() loading:Destroy() end)
    setMenu(true)
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
