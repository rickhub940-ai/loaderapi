-- 999ms HUB v8 | Fully Merged
-- Cascade UI · ESP (Generator = Completed-based color) · Pathfinder+Tween · Avoidance · Abilities · SkillCheck · Movement

local replicatedStorage   = game:GetService("ReplicatedStorage")
local runService          = game:GetService("RunService")
local lighting            = game:GetService("Lighting")
local players             = game:GetService("Players")
local userInputService    = game:GetService("UserInputService")
local PathfindingService  = game:GetService("PathfindingService")
local localPlayer         = players.LocalPlayer

-- ============================================================
-- CoreGui
-- ============================================================
local coreGui
pcall(function() coreGui = (gethui and gethui()) or game:GetService("CoreGui") end)
if not coreGui then coreGui = game:GetService("CoreGui") end

-- ============================================================
-- Cascade UI
-- ============================================================
local function importRelease(owner, repo, version, file)
    local tag = (version == "latest" and "latest/download" or "download/" .. version)
    return loadstring(game:HttpGetAsync(("https://github.com/%s/%s/releases/%s/%s"):format(owner, repo, tag, file)), file)()
end

local cascade
do
    local ok, r = pcall(function() return importRelease("cascadeui", "Cascade", "latest", "dist.luau") end)
    if not ok or not r then warn("[999ms HUB] Cascade load failed:", r); return end
    cascade = r
end

local IS_MOBILE = userInputService.TouchEnabled and not userInputService.KeyboardEnabled
local WIN_SIZE  = IS_MOBILE
    and UDim2.fromOffset(math.floor(workspace.CurrentCamera.ViewportSize.X * 0.92),
                          math.floor(workspace.CurrentCamera.ViewportSize.Y * 0.72))
    or UDim2.fromOffset(560, 460)

local app = cascade.New({ Theme = cascade.Themes.Dark, Accent = cascade.Accents.Blue, WindowPill = true })

local window = app:Window({
    Title = "999ms HUB", Subtitle = "by 09ms | v8 Full",
    Size = WIN_SIZE,
    MinSize = IS_MOBILE and Vector2.new(300, 280) or Vector2.new(480, 340),
    MaxSize = IS_MOBILE and Vector2.new(600, 550) or Vector2.new(720, 520),
    Draggable = true, Resizable = true, Dropshadow = true, UIBlur = false, Searching = true,
})

local mainSection = window:Section({ Title = "Menu", Disclosure = true, Expanded = true })
local farmTab     = mainSection:Tab({ Title = "Auto Farm",  Icon = cascade.Symbols.squareStack3dUp, Selected = true })
local abilityTab  = mainSection:Tab({ Title = "Abilities",  Icon = cascade.Symbols.sparkles })
local visualTab   = mainSection:Tab({ Title = "Visuals",    Icon = cascade.Symbols.eye })
local notifyTab   = mainSection:Tab({ Title = "Notify",     Icon = cascade.Symbols.bell })
local moveTab     = mainSection:Tab({ Title = "Movement",   Icon = cascade.Symbols.arrowUpCircle })
local settingsTab = mainSection:Tab({ Title = "Settings",   Icon = cascade.Symbols.gear })

-- ============================================================
-- Helpers
-- ============================================================
local function addSlider(form, o)
    local row = form:Row({ SearchIndex = o.SearchIndex })
    local ts = row:Left():TitleStack({ Title = o.Title, Subtitle = o.Subtitle })
    local function fmt(v)
        if o.Integer ~= false then v = math.floor(v) end
        return tostring(v) .. (o.Suffix and (" " .. o.Suffix) or "")
    end
    ts.Subtitle = (o.Subtitle and (o.Subtitle .. " • ") or "") .. fmt(o.Default)
    return row:Right():Slider({
        Minimum = o.Min, Maximum = o.Max, Value = o.Default,
        ValueChanged = function(_, v)
            ts.Subtitle = (o.Subtitle and (o.Subtitle .. " • ") or "") .. fmt(v)
            if o.OnChanged then o.OnChanged(o.Integer ~= false and math.floor(v) or v) end
        end,
    })
end

local function getChar()
    local c = localPlayer.Character
    if not c then return nil, nil, nil end
    return c, c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
end

local function getCurrentRoom()
    local room = workspace:FindFirstChild("CurrentRoom")
    if not room then return nil end
    for _, o in ipairs(room:GetChildren()) do
        if o:IsA("Model") or o:IsA("Folder") then return o end
    end
end

local BOSS_NAMES = {
    AstroMonster = true, VeeMonster = true, SproutMonster = true,
    PebbleMonster = true, ShellyMonster = true, DandyMonster = true,
}
local HEALTH_ITEMS = { HealthKit=true, Bandage=true, Bandaid=true, Medkit=true }
local RARE_ITEMS = {
    "Bandage","HealthKit","SmokeBomb","EjectButton","Valve",
    "Box chocolates","AirHorn","EnigmaCandy","JumperCable","PopBottle",
}
local MAIN_MONSTERS = { "AstroMonster","VeeMonster","SproutMonster","PebbleMonster","ShellyMonster","DandyMonster" }

-- ============================================================
-- 🎨 ESP Core (25ms Style)
-- ============================================================
local ESP_CONFIG = { MaxDistance = 2000, ShowHealth = true }
local ESP_COLOR = {
    Monster     = Color3.new(1, 0, 0),
    Item        = Color3.new(0, 0.4, 1),
    HealthItem  = Color3.new(0, 1, 0.4),
    SpecialMain = Color3.new(1, 1, 0),
    LowHealth   = Color3.fromRGB(102, 66, 33),
    Elevator    = Color3.fromRGB(200, 120, 255),
    Player      = Color3.fromRGB(255, 200, 80),
}
-- Generator colors (ตามสถานะ)
local GEN_COLOR_DONE     = Color3.fromRGB(0, 255, 100)   -- เขียว (ซ่อมแล้ว)
local GEN_COLOR_UNFINISH = Color3.fromRGB(255, 60, 60)   -- แดง  (ยังไม่ซ่อม)

local function addESPTag(target, text, color, showHealth)
    if target:FindFirstChild("ESP_Highlight") then return end

    local hl = Instance.new("Highlight")
    hl.Name = "ESP_Highlight"
    hl.Adornee = target
    hl.FillColor = color
    hl.OutlineColor = Color3.new(1, 1, 1)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = target

    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_NameTag"
    bb.Size = UDim2.new(8, 0, 2, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = ESP_CONFIG.MaxDistance
    bb.LightInfluence = 0
    bb.Parent = target

    local lbl = Instance.new("TextLabel")
    lbl.Name = "ESP_Label"
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.Font = Enum.Font.RobotoMono
    lbl.TextScaled = true
    lbl.Parent = bb

    local st = Instance.new("UIStroke")
    st.Thickness = 3
    st.Color = Color3.new(0, 0, 0)
    st.Parent = lbl

    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1,1,1), 0.55)),
        ColorSequenceKeypoint.new(1, color),
    })
    g.Parent = lbl

    local hum = target:FindFirstChildOfClass("Humanoid")
    if showHealth ~= false and ESP_CONFIG.ShowHealth and hum then
        local hpBg = Instance.new("Frame")
        hpBg.Name = "ESP_HP"
        hpBg.Size = UDim2.new(1, -6, 0, 6)
        hpBg.Position = UDim2.new(0, 3, 1, -4)
        hpBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        hpBg.BorderSizePixel = 0
        hpBg.Parent = bb
        local c1 = Instance.new("UICorner"); c1.CornerRadius = UDim.new(0, 3); c1.Parent = hpBg

        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.new(1, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 220, 90)
        fill.BorderSizePixel = 0
        fill.Parent = hpBg
        local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0, 3); c2.Parent = fill

        local function upd()
            if not hum.Parent then return end
            local p = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
            fill.Size = UDim2.new(p, 0, 1, 0)
            if p > 0.6 then fill.BackgroundColor3 = Color3.fromRGB(0, 220, 90)
            elseif p > 0.3 then fill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
            else fill.BackgroundColor3 = Color3.fromRGB(240, 50, 50) end
        end
        upd()
        hum.HealthChanged:Connect(upd)
    end
end

local function removeESPTag(target)
    local hl = target:FindFirstChild("ESP_Highlight"); if hl then hl:Destroy() end
    local bb = target:FindFirstChild("ESP_NameTag"); if bb then bb:Destroy() end
end

-- helper: อัปเดตสี ESP ที่มีอยู่แล้ว
local function updateESPTagColor(target, color)
    local hl = target:FindFirstChild("ESP_Highlight")
    if hl then
        hl.FillColor    = color
        hl.OutlineColor = color
    end
    local bb = target:FindFirstChild("ESP_NameTag")
    if bb then
        local lbl = bb:FindFirstChild("ESP_Label")
        if lbl then
            lbl.TextColor3 = color
            local g = lbl:FindFirstChildOfClass("UIGradient")
            if g then
                g.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1,1,1), 0.55)),
                    ColorSequenceKeypoint.new(1, color),
                })
            end
        end
    end
end

-- Generic ESP factory
local function makeESP(folder, color, filter, showHealth)
    local s = { Enabled = false, Conn = nil, Folder = folder }
    function s:Scan()
        local map = getCurrentRoom()
        if not map then return end
        local f = map:FindFirstChild(self.Folder)
        if not f then return end
        for _, o in ipairs(f:GetChildren()) do
            if o:IsA("Model") or o:IsA("BasePart") then
                local allowed = (not filter) or (o.Name and filter[o.Name])
                if self.Enabled and allowed then
                    addESPTag(o, o.Name, color, showHealth)
                elseif not self.Enabled or (filter and not allowed) then
                    removeESPTag(o)
                end
            end
        end
    end
    function s:Start()
        self.Enabled = true
        if self.Conn then self.Conn:Disconnect() end
        self.Conn = runService.Heartbeat:Connect(function() self:Scan() end)
    end
    function s:Stop()
        self.Enabled = false
        if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
        local map = getCurrentRoom()
        if map then
            local f = map:FindFirstChild(self.Folder)
            if f then for _, o in ipairs(f:GetChildren()) do
                if o:IsA("Model") or o:IsA("BasePart") then removeESPTag(o) end
            end end
        end
    end
    return s
end

local monsterESP     = makeESP("Monsters",   ESP_COLOR.Monster,     nil, true)
local itemESP        = makeESP("Items",      ESP_COLOR.Item,        nil, false)
local specialMainESP = makeESP("Monsters",   ESP_COLOR.SpecialMain, BOSS_NAMES, true)

-- Item ESP override (สีแยกตามยา)
itemESP.Scan = function(self)
    local map = getCurrentRoom(); if not map then return end
    local f = map:FindFirstChild("Items"); if not f then return end
    for _, o in ipairs(f:GetChildren()) do
        if o:IsA("Model") or o:IsA("BasePart") then
            if self.Enabled then
                local c = HEALTH_ITEMS[o.Name] and ESP_COLOR.HealthItem or ESP_COLOR.Item
                if o:FindFirstChild("ESP_Highlight") then
                    updateESPTagColor(o, c)
                else
                    addESPTag(o, o.Name, c, false)
                end
            else removeESPTag(o) end
        end
    end
end

-- ============================================================
-- 🎨 GENERATOR ESP (Completed = เขียว / ไม่เสร็จ = แดง)
-- ============================================================
local generatorESP = { Enabled = false, Conn = nil }

local function isGeneratorCompleted(gen)
    local stats = gen:FindFirstChild("Stats")
    if not stats then return false end
    local comp = stats:FindFirstChild("Completed")
    if comp and comp:IsA("BoolValue") then
        return comp.Value
    end
    return false
end

function generatorESP:Scan()
    local map = getCurrentRoom()
    if not map then return end
    local folder = map:FindFirstChild("Generators")
    if not folder then return end

    for _, g in ipairs(folder:GetChildren()) do
        if g:IsA("Model") then
            if self.Enabled then
                local completed = isGeneratorCompleted(g)
                local color = completed and GEN_COLOR_DONE or GEN_COLOR_UNFINISH

                if not g:FindFirstChild("ESP_Highlight") then
                    addESPTag(g, g.Name, color, false)
                else
                    updateESPTagColor(g, color)
                end
            else
                removeESPTag(g)
            end
        end
    end
end
function generatorESP:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function() self:Scan() end)
end
function generatorESP:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
    local map = getCurrentRoom()
    if map then
        local folder = map:FindFirstChild("Generators")
        if folder then for _, g in ipairs(folder:GetChildren()) do
            if g:IsA("Model") then removeESPTag(g) end
        end end
    end
end

-- Elevator ESP
local elevatorESP = { Enabled = false, Conn = nil }
function elevatorESP:Scan()
    local e = workspace:FindFirstChild("Elevators")
    local el = e and e:FindFirstChild("Elevator")
    if not el then return end
    if self.Enabled then addESPTag(el, "Elevator", ESP_COLOR.Elevator, false)
    else removeESPTag(el) end
end
function elevatorESP:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function() self:Scan() end)
end
function elevatorESP:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
    local e = workspace:FindFirstChild("Elevators")
    local el = e and e:FindFirstChild("Elevator"); if el then removeESPTag(el) end
end

-- Low Health ESP
local lowHealthESP = { Enabled = false, Conn = nil }
function lowHealthESP:Scan()
    local igp = workspace:FindFirstChild("InGamePlayers"); if not igp then return end
    for _, m in ipairs(igp:GetChildren()) do
        if m:IsA("Model") and m.Name ~= localPlayer.Name then
            local hum = m:FindFirstChildOfClass("Humanoid")
            if hum then
                if self.Enabled and hum.Health == 1 then
                    addESPTag(m, m.Name .. " (HP:1)", ESP_COLOR.LowHealth, false)
                else removeESPTag(m) end
            end
        end
    end
end
function lowHealthESP:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function() self:Scan() end)
end
function lowHealthESP:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
    local igp = workspace:FindFirstChild("InGamePlayers")
    if igp then for _, m in ipairs(igp:GetChildren()) do
        if m:IsA("Model") then removeESPTag(m) end
    end end
end

-- Player ESP
local playerESP = { Enabled = false, Conn = nil }
function playerESP:Scan()
    local igp = workspace:FindFirstChild("InGamePlayers"); if not igp then return end
    for _, m in ipairs(igp:GetChildren()) do
        if m:IsA("Model") and m.Name ~= localPlayer.Name then
            if self.Enabled then
                local hum = m:FindFirstChildOfClass("Humanoid")
                local txt = m.Name
                if hum then txt = txt .. " [" .. math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth) .. "]" end
                addESPTag(m, txt, ESP_COLOR.Player, true)
            else removeESPTag(m) end
        end
    end
end
function playerESP:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function() self:Scan() end)
end
function playerESP:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
end

-- ============================================================
-- 🚶 PATHFINDER + TWEEN (ไม่ทะลุกำแพง, ใช้ waypoint หลบ)
-- ============================================================
local pathfinder = {
    Active             = false,
    TargetPos          = nil,
    CurrentPath        = nil,
    WaypointIndex      = 0,
    LastCompute        = 0,
    RecomputeCooldown  = 1.2,
    MaxRetries         = 3,
    _retries           = 0,
    OnReached          = nil,
    BlockedConn        = nil,

    SpeedBonus         = 5,
    WaypointReachDist  = 4,
    TargetReachDist    = 6,
    JumpCooldown       = 0.4,
    _lastJump          = 0,
    _bodyVel           = nil,
}

function pathfinder:_clearBodyVel()
    local _, hrp = getChar()
    if self._bodyVel and self._bodyVel.Parent then self._bodyVel:Destroy() end
    if hrp then
        local old = hrp:FindFirstChild("PathfinderBodyVelocity")
        if old then old:Destroy() end
    end
    self._bodyVel = nil
end

function pathfinder:_ensureBodyVel()
    local _, hrp = getChar()
    if not hrp then return nil end
    if self._bodyVel and self._bodyVel.Parent then return self._bodyVel end

    local old = hrp:FindFirstChild("PathfinderBodyVelocity")
    if old then old:Destroy() end

    local bv = Instance.new("BodyVelocity")
    bv.Name     = "PathfinderBodyVelocity"
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.P         = 10000
    bv.Velocity = Vector3.zero
    bv.Parent   = hrp
    self._bodyVel = bv
    return bv
end

function pathfinder:_glideToWaypoint(wpPos)
    local _, hrp, hum = getChar()
    if not hrp or not hum then return end
    local bv = self:_ensureBodyVel()
    if not bv then return end

    local offset = wpPos - hrp.Position
    local distance = offset.Magnitude
    if distance < 0.1 then bv.Velocity = Vector3.zero; return end

    local speed = hum.WalkSpeed + self.SpeedBonus
    local flat = Vector3.new(offset.X, 0, offset.Z).Unit
    local yBoost = offset.Y > 2 and offset.Unit.Y or 0
    local dir = (flat + Vector3.new(0, yBoost, 0)).Unit

    bv.Velocity = dir * math.min(speed, distance * 10)
end

function pathfinder:_stopGlide()
    if self._bodyVel and self._bodyVel.Parent then
        self._bodyVel.Velocity = Vector3.zero
    end
end

function pathfinder:_compute(fromPos, toPos)
    local path = PathfindingService:CreatePath({
        AgentRadius     = 2.5,
        AgentHeight     = 5,
        AgentCanJump    = true,
        AgentCanClimb   = false,
        WaypointSpacing = 4,
    })
    local ok = pcall(function() path:ComputeAsync(fromPos, toPos) end)
    if not ok or path.Status ~= Enum.PathStatus.Success then return nil end
    return path
end

function pathfinder:_bindBlocked(path)
    if self.BlockedConn then self.BlockedConn:Disconnect() end
    self.BlockedConn = path.Blocked:Connect(function(wpIdx)
        if wpIdx <= self.WaypointIndex then self.LastCompute = 0 end
    end)
end

function pathfinder:GoTo(targetPos, onReached)
    self.Active = true
    self.TargetPos = targetPos
    self.OnReached = onReached
    self.CurrentPath = nil
    self.WaypointIndex = 0
    self.LastCompute = 0
    self._retries = 0
    self._lastJump = 0
end

function pathfinder:Stop()
    self.Active = false
    self.TargetPos = nil
    self.CurrentPath = nil
    if self.BlockedConn then self.BlockedConn:Disconnect(); self.BlockedConn = nil end
    self:_stopGlide()
    self:_clearBodyVel()
end

function pathfinder:Step()
    if not self.Active or not self.TargetPos then return end
    local _, hrp, hum = getChar()
    if not hrp or not hum or hum.Health <= 0 then self:Stop(); return end

    if (hrp.Position - self.TargetPos).Magnitude < self.TargetReachDist then
        self:_stopGlide()
        self:_clearBodyVel()
        local cb = self.OnReached
        self.Active = false
        self.TargetPos = nil
        if self.BlockedConn then self.BlockedConn:Disconnect(); self.BlockedConn = nil end
        if cb then cb() end
        return
    end

    local now = os.clock()
    if not self.CurrentPath or (now - self.LastCompute) > self.RecomputeCooldown then
        local newPath = self:_compute(hrp.Position, self.TargetPos)
        if newPath then
            self.CurrentPath = newPath
            self.LastCompute = now
            self.WaypointIndex = 0
            self:_bindBlocked(newPath)

            for i, wp in ipairs(newPath:GetWaypoints()) do
                if (hrp.Position - wp.Position).Magnitude > 3 then
                    self.WaypointIndex = i
                    break
                end
            end
        else
            self._retries += 1
            if self._retries >= self.MaxRetries then
                warn("[pathfinder] No path, abort")
                self:_stopGlide()
                self:Stop()
            end
            return
        end
    end

    if not self.CurrentPath then return end
    local wps = self.CurrentPath:GetWaypoints()
    if #wps == 0 then return end
    if self.WaypointIndex > #wps then self.LastCompute = 0; return end

    local wp = wps[self.WaypointIndex]

    if (hrp.Position - wp.Position).Magnitude < self.WaypointReachDist then
        self.WaypointIndex += 1
        if self.WaypointIndex > #wps then self.LastCompute = 0; return end
        wp = wps[self.WaypointIndex]
    end

    if wp.Action == Enum.PathWaypointAction.Jump then
        local state = hum:GetState()
        if state ~= Enum.HumanoidStateType.Jumping
           and state ~= Enum.HumanoidStateType.Freefall
           and (now - self._lastJump) > self.JumpCooldown then
            hum.Jump = true
            self._lastJump = now
        end
    end

    self:_glideToWaypoint(wp.Position)
end

-- ============================================================
-- 🛡️ AVOIDANCE
-- ============================================================
local avoid = {
    Enabled       = true,
    DangerRadius  = 22,
    BossRadius    = 40,
    EvadeDuration = 1.5,
    _evadeUntil   = 0,
}

function avoid:_scan(pos)
    local map = getCurrentRoom(); if not map then return nil, math.huge end
    local mons = map:FindFirstChild("Monsters"); if not mons then return nil, math.huge end

    local closest, closestD = nil, math.huge
    for _, m in ipairs(mons:GetChildren()) do
        if m:IsA("Model") then
            local bp = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
            if bp then
                local r = BOSS_NAMES[m.Name] and self.BossRadius or self.DangerRadius
                local d = (bp.Position - pos).Magnitude - r
                if d < closestD then
                    closest, closestD = { pos = bp.Position, radius = r, model = m }, d
                end
            end
        end
    end
    return closest, closestD
end

function avoid:_escapePoint(hrp, threat)
    local away = hrp.Position - threat.pos
    if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
    return threat.pos + away.Unit * (threat.radius + 14)
end

function avoid:Step()
    if not self.Enabled then return end
    local _, hrp, hum = getChar(); if not hrp or not hum then return end

    if os.clock() < self._evadeUntil then return end

    local threat, d = self:_scan(hrp.Position)
    if threat and d < 0 then
        if pathfinder.Active then pathfinder:Stop() end
        hum.WalkSpeed = 30
        hum:MoveTo(self:_escapePoint(hrp, threat))
        self._evadeUntil = os.clock() + self.EvadeDuration
    end
end

-- ============================================================
-- 🌾 AUTO FARM
-- ============================================================
local autoFarm = {
    Enabled = false,
    AutoInteract = true,
    AutoMove = true,
    AutoElevator = true,
    WalkSpeedPath = 22,
    TickRate = 20,
    _accum = 0, _conn = nil,
    CachedGens = setmetatable({}, { __mode = "k" }),
    _pendingInteract = nil,
}

local function genPos(g)
    if g.PrimaryPart then return g.PrimaryPart.Position end
    local ok, p = pcall(function() return g:GetPivot() end)
    return ok and p.Position or Vector3.zero
end

function autoFarm:_getGenTarget(g)
    local g1 = g:FindFirstChild("TeleportPositions") or g:FindFirstChild("TreadmillTeleportPositions")
    if g1 and #g1:GetChildren() > 0 then return g1:GetChildren()[1].CFrame end
    local s = g:FindFirstChild("TeleportPosition") or g:FindFirstChild("TreadmillTeleportPosition")
    if s then return s.CFrame end
    return CFrame.new(genPos(g)) * CFrame.new(0, 0, 4)
end

function autoFarm:Init()
    local ev = replicatedStorage:WaitForChild("Events", 8)
    if ev and ev:FindFirstChild("SkillcheckUpdate") then
        ev.SkillcheckUpdate.OnClientInvoke = function(mg, ...)
            local mt = mg and mg:GetAttribute("MinigameType")
            if mt == "Circle" then return { hit = true, circle = "great" } end
            if mt == "Bar" or mt == "Line" then return { hit = true, bar = "great" } end
            return "supercomplete"
        end
    end

    local function cache(o)
        if o:IsA("Model") and o:GetAttribute("MinigameType") then
            self.CachedGens[o] = true
        end
    end
    for _, o in ipairs(workspace:GetDescendants()) do cache(o) end
    workspace.DescendantAdded:Connect(cache)

    self._conn = runService.Stepped:Connect(function(_, dt)
        if not self.Enabled then return end
        self._accum += dt
        if self._accum < (1 / self.TickRate) then return end
        self._accum = 0
        pcall(self.Step, self)
    end)

    runService.Heartbeat:Connect(function()
        if pathfinder.Active then pathfinder:Step() end
    end)

    runService.Heartbeat:Connect(function()
        if self.Enabled then avoid:Step() end
    end)
end

function autoFarm:Step()
    local char, hrp, hum = getChar()
    if not char or not hrp or not hum or hum.Health <= 0 then
        if pathfinder.Active then pathfinder:Stop() end
        return
    end

    hum.WalkSpeed = self.WalkSpeedPath

    local total, unfinished = 0, 0
    local interactingStats = nil
    local bestGen, bestDist = nil, math.huge

    for g in pairs(self.CachedGens) do
        if g.Parent then
            local stats = g:FindFirstChild("Stats")
            if stats then
                total += 1
                local comp = stats:FindFirstChild("Completed")
                local ap   = stats:FindFirstChild("ActivePlayer")
                local isMine = ap and ap.Value == char
                if isMine then interactingStats = stats end
                if comp and not comp.Value then
                    unfinished += 1
                    local taken = ap and ap.Value ~= nil and not isMine
                    if not taken then
                        local gp = genPos(g)
                        local _, dangerDist = avoid:_scan(gp)
                        if dangerDist > 0 then
                            local d = (gp - hrp.Position).Magnitude
                            if d < bestDist then bestGen, bestDist = g, d end
                        end
                    end
                end
            end
        end
    end

    if total == 0 then return end

    -- Elevator
    if self.AutoElevator and unfinished == 0 then
        local e = workspace:FindFirstChild("Elevators")
        local el = e and e:FindFirstChild("Elevator")
        if el then
            local piv = el.PrimaryPart and el.PrimaryPart.CFrame or el:GetPivot()
            if (hrp.Position - piv.Position).Magnitude > 6 and not pathfinder.Active then
                if self.AutoMove then pathfinder:GoTo(piv.Position) end
            end
        end
        return
    end

    -- Path to best gen
    if not interactingStats and self.AutoMove and bestGen and not pathfinder.Active then
        local tgt = self:_getGenTarget(bestGen)
        pathfinder:GoTo(tgt.Position, function()
            self._pendingInteract = bestGen
        end)
    end

    -- Interact when reached
    if self.AutoInteract and not interactingStats and self._pendingInteract then
        local g = self._pendingInteract
        if g and g.Parent then
            local stats = g:FindFirstChild("Stats")
            local comp  = stats and stats:FindFirstChild("Completed")
            local ap    = stats and stats:FindFirstChild("ActivePlayer")
            local free  = ap and (ap.Value == nil or ap.Value == char)
            if comp and not comp.Value and free then
                local pr = g:FindFirstChildWhichIsA("ProximityPrompt", true)
                if pr and pr.Enabled then pcall(fireproximityprompt, pr, 1) end
            end
        end
        self._pendingInteract = nil
    end
end
autoFarm:Init()

-- ============================================================
-- 🎒 PICK ALL ITEMS (via pathfinder)
-- ============================================================
local pickAll = { Running = false }
function pickAll:Run()
    if self.Running then return end
    self.Running = true
    task.spawn(function()
        local _, hrp = getChar()
        if not hrp then self.Running = false; return end
        local map = getCurrentRoom()
        if not map then self.Running = false; return end
        local items = map:FindFirstChild("Items")
        if not items then self.Running = false; return end

        for _, item in ipairs(items:GetChildren()) do
            if item:IsA("Model") then
                local ok, modelCF = pcall(function() return item:GetModelCFrame() end)
                if ok and modelCF then
                    local done = false
                    pathfinder:GoTo(modelCF.Position, function() done = true end)
                    local t0 = os.clock()
                    while not done and (os.clock() - t0) < 10 do task.wait(0.1) end
                    pathfinder:Stop()

                    local promptPart = item:FindFirstChild("Prompt")
                    if promptPart and promptPart:IsA("BasePart") then
                        local pr = promptPart:FindFirstChildOfClass("ProximityPrompt")
                        if pr then
                            for _ = 1, 3 do
                                pcall(function()
                                    pr:InputHoldBegin(); task.wait(0.1)
                                    pr:InputHoldEnd();   task.wait(0.1)
                                end)
                            end
                        end
                    end
                end
            end
        end
        self.Running = false
    end)
end

-- ============================================================
-- 🚀 NOCLIP
-- ============================================================
local noClip = { Enabled = false, Conn = nil }
function noClip:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function()
        if not self.Enabled then return end
        local map = getCurrentRoom(); if not map then return end
        local fa = map:FindFirstChild("FreeArea"); if not fa then return end
        for _, c in ipairs(fa:GetChildren()) do
            if c:IsA("BasePart") and c.Name == "InvisBorder" then c:Destroy() end
        end
    end)
end
function noClip:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
end

-- ============================================================
-- ⚡ ABILITIES
-- ============================================================
local SPROUT_HEAL_CF = CFrame.new(-179.29843139648438, 146.2311248779297, -164.61495971679688)
    * CFrame.Angles(3.1415927410125732, 0.4017193913459778, -3.141592502593994)
local ABILITY_CF     = CFrame.new(-65.78115844726562, 145.7693634033203, 86.53424072265625)
    * CFrame.Angles(4.4136689858476075e-09, 2.9576958503043716e-16, 5.338084818617972e-08)

local abilities = {
    AutoUseItems   = { Enabled = false, Interval = 0.5 },
    AutoUseAbility = { Enabled = false, Interval = 0.3 },
    SproutSelfHeal = { Enabled = false, Interval = 1 },
    ShellyBoost    = { Enabled = false, Interval = 1 },
}

local function invokeItem(slot)
    local char = localPlayer.Character; if not char then return end
    local inv = char:FindFirstChild("Inventory"); if not inv then return end
    local it = inv:FindFirstChild(slot); if not it then return end
    local ev = replicatedStorage:FindFirstChild("Events")
    local ie = ev and ev:FindFirstChild("ItemEvent")
    if ie then pcall(function() ie:InvokeServer(char, it) end) end
end

local function invokeAbility(cf, extra)
    local char = localPlayer.Character; if not char then return end
    local ev = replicatedStorage:FindFirstChild("Events")
    local ab = ev and ev:FindFirstChild("AbilityEvent")
    if ab then pcall(function() ab:InvokeServer(char, cf, extra or false) end) end
end

function abilities.AutoUseItems:Start()
    self.Enabled = true
    task.spawn(function()
        while self.Enabled do
            invokeItem("Slot1"); invokeItem("Slot2"); invokeItem("Slot3")
            task.wait(self.Interval)
        end
    end)
end
function abilities.AutoUseItems:Stop() self.Enabled = false end

function abilities.AutoUseAbility:Start()
    self.Enabled = true
    task.spawn(function()
        while self.Enabled do
            invokeAbility(ABILITY_CF, false); task.wait(self.Interval)
        end
    end)
end
function abilities.AutoUseAbility:Stop() self.Enabled = false end

function abilities.SproutSelfHeal:Start()
    self.Enabled = true
    task.spawn(function()
        while self.Enabled do
            invokeAbility(SPROUT_HEAL_CF, localPlayer.Character)
            task.wait(self.Interval)
        end
    end)
end
function abilities.SproutSelfHeal:Stop() self.Enabled = false end

function abilities.ShellyBoost:Start()
    self.Enabled = true
    task.spawn(function()
        while self.Enabled do
            local char = localPlayer.Character
            local igp = workspace:FindFirstChild("InGamePlayers")
            local model = igp and igp:FindFirstChild(localPlayer.Name)
            if char and model then
                local map = getCurrentRoom()
                if map then
                    for _, mo in ipairs(map:GetChildren()) do
                        local gens = mo:FindFirstChild("Generators")
                        if gens then
                            for _, g in ipairs(gens:GetChildren()) do
                                local stats = g:FindFirstChild("Stats")
                                local ap = stats and stats:FindFirstChild("ActivePlayer")
                                if ap and ap.Value == model then
                                    invokeAbility(SPROUT_HEAL_CF, char); break
                                end
                            end
                        end
                    end
                end
            end
            task.wait(self.Interval)
        end
    end)
end
function abilities.ShellyBoost:Stop() self.Enabled = false end

-- ============================================================
-- 🎯 SKILL CHECK
-- ============================================================
local skillCheck = { AutoEnabled = false }
function skillCheck:EnableAuto()
    self.AutoEnabled = true
    local ev = replicatedStorage:FindFirstChild("Events")
    if ev and ev:FindFirstChild("SkillcheckUpdate") then
        ev.SkillcheckUpdate.OnClientInvoke = function(mg, ...)
            local mt = mg and mg:GetAttribute("MinigameType")
            if mt == "Circle" then return { hit = true, circle = "great" } end
            if mt == "Bar" or mt == "Line" then return { hit = true, bar = "great" } end
            return "supercomplete"
        end
    end
end
function skillCheck:DisableAuto()
    self.AutoEnabled = false
    local ev = replicatedStorage:FindFirstChild("Events")
    if ev and ev:FindFirstChild("SkillcheckUpdate") then ev.SkillcheckUpdate.OnClientInvoke = nil end
end
function skillCheck:DestroyFrame()
    local gui = localPlayer.PlayerGui:FindFirstChild("ScreenGui")
    if gui then
        local menu = gui:FindFirstChild("Menu")
        if menu then
            local f = menu:FindFirstChild("SkillCheckFrame"); if f then f:Destroy() end
        end
    end
end

-- ============================================================
-- 🏃 MOVEMENT
-- ============================================================
local walkSpeed = { Enabled = false, Speed = 16, Conn = nil, CharConn = nil }
local function getHum()
    local c = localPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
function walkSpeed:Start()
    self.Enabled = true
    local h = getHum(); if h then h.WalkSpeed = self.Speed end
    if self.Conn then self.Conn:Disconnect() end
    local function bind(h2)
        if not h2 then return end
        self.Conn = h2:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if self.Enabled then h2.WalkSpeed = self.Speed end
        end)
    end
    bind(h)
    if self.CharConn then self.CharConn:Disconnect() end
    self.CharConn = localPlayer.CharacterAdded:Connect(function(c)
        local h2 = c:WaitForChild("Humanoid"); h2.WalkSpeed = self.Speed; bind(h2)
    end)
end
function walkSpeed:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
    if self.CharConn then self.CharConn:Disconnect(); self.CharConn = nil end
    local h = getHum(); if h then h.WalkSpeed = 16 end
end
function walkSpeed:SetSpeed(v)
    self.Speed = v
    if self.Enabled then local h = getHum(); if h then h.WalkSpeed = v end end
end

local infinityJump = { Enabled = false, JumpForce = 50 }
function infinityJump:Jump()
    if not self.Enabled then return end
    local c = localPlayer.Character; if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hrp and hum and hum.Health > 0 then
        hrp.Velocity = Vector3.new(hrp.Velocity.X, self.JumpForce, hrp.Velocity.Z)
    end
end
userInputService.InputBegan:Connect(function(i, g)
    if g then return end
    if i.KeyCode == Enum.KeyCode.Space then infinityJump:Jump() end
end)

local fly = { Enabled = false, Speed = 60, Conn = nil, BV = nil, Gyro = nil }
function fly:Start()
    self.Enabled = true
    local _, hrp = getChar(); if not hrp then return end
    if self.BV then self.BV:Destroy() end
    if self.Gyro then self.Gyro:Destroy() end
    self.BV = Instance.new("BodyVelocity")
    self.BV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    self.BV.Velocity = Vector3.zero
    self.BV.Parent = hrp
    self.Gyro = Instance.new("BodyGyro")
    self.Gyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    self.Gyro.P = 1000
    self.Gyro.Parent = hrp
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function()
        if not self.Enabled then return end
        local _, r = getChar(); if not r then return end
        local cam = workspace.CurrentCamera
        local dir = Vector3.zero
        if userInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if userInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if userInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if userInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if userInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        if userInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0,1,0) end
        self.BV.Velocity = dir.Magnitude > 0 and (dir.Unit * self.Speed) or Vector3.zero
        self.Gyro.CFrame = cam.CFrame
    end)
end
function fly:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
    if self.BV then self.BV:Destroy(); self.BV = nil end
    if self.Gyro then self.Gyro:Destroy(); self.Gyro = nil end
end

-- ============================================================
-- 🎥 CAMERA / LIGHTING
-- ============================================================
local cameraMod = {
    FOVEnabled = false, FOV = 70,
    FullbrightEnabled = false, Conns = {},
    Orig = { Brightness = lighting.Brightness, ClockTime = lighting.ClockTime,
             FogEnd = lighting.FogEnd, FogStart = lighting.FogStart,
             FogColor = lighting.FogColor, GlobalShadows = lighting.GlobalShadows,
             OutdoorAmbient = lighting.OutdoorAmbient },
}
runService.RenderStepped:Connect(function()
    if cameraMod.FOVEnabled then
        local c = workspace.CurrentCamera
        if c and c.FieldOfView ~= cameraMod.FOV then c.FieldOfView = cameraMod.FOV end
    end
end)
function cameraMod:ToggleFOV(v) self.FOVEnabled = v end
function cameraMod:SetFOV(v) self.FOV = v end
function cameraMod:ToggleFullbright(v)
    self.FullbrightEnabled = v
    if v then
        local function apply()
            lighting.Brightness = 1
            lighting.ClockTime = 14
            lighting.FogEnd = 100000
            lighting.GlobalShadows = false
            lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        end
        apply()
        for _, p in ipairs({"Brightness","ClockTime","FogEnd","GlobalShadows","OutdoorAmbient"}) do
            self.Conns[p] = lighting:GetPropertyChangedSignal(p):Connect(apply)
        end
    else
        for _, c in pairs(self.Conns) do c:Disconnect() end
        self.Conns = {}
        local o = self.Orig
        lighting.Brightness = o.Brightness; lighting.ClockTime = o.ClockTime
        lighting.FogEnd = o.FogEnd; lighting.GlobalShadows = o.GlobalShadows
        lighting.OutdoorAmbient = o.OutdoorAmbient
    end
end

local noFog = { Enabled = false, Orig = nil }
function noFog:Start()
    self.Enabled = true
    self.Orig = { FogEnd = lighting.FogEnd, FogStart = lighting.FogStart, FogColor = lighting.FogColor }
    lighting.FogEnd = math.huge; lighting.FogStart = math.huge
    lighting.FogColor = Color3.new(1,1,1)
end
function noFog:Stop()
    self.Enabled = false
    if self.Orig then
        lighting.FogEnd = self.Orig.FogEnd
        lighting.FogStart = self.Orig.FogStart
        lighting.FogColor = self.Orig.FogColor
    end
end

-- ============================================================
-- 🔔 NOTIFY
-- ============================================================
local notifySystem = {
    RareItems   = { Enabled = false, Seen = {} },
    MainTwisted = { Enabled = false, Seen = {} },
    LowHealth   = { Enabled = false, Seen = {} },
}

function notifySystem.RareItems:Start()
    self.Enabled = true; self.Seen = {}
    task.spawn(function()
        while self.Enabled do
            local map = getCurrentRoom()
            if map then
                local items = map:FindFirstChild("Items")
                if items then
                    for _, it in ipairs(items:GetChildren()) do
                        if table.find(RARE_ITEMS, it.Name) and not self.Seen[it.Name] then
                            self.Seen[it.Name] = true
                            app:Notification({ Title = "Rare Item", Subtitle = it.Name, Duration = 6 })
                        end
                    end
                end
            end
            task.wait(3)
        end
    end)
end
function notifySystem.RareItems:Stop() self.Enabled = false end

function notifySystem.MainTwisted:Start()
    self.Enabled = true; self.Seen = {}
    task.spawn(function()
        while self.Enabled do
            local map = getCurrentRoom()
            if map then
                local mons = map:FindFirstChild("Monsters")
                if mons then
                    for _, m in ipairs(mons:GetChildren()) do
                        if table.find(MAIN_MONSTERS, m.Name) and not self.Seen[m.Name] then
                            self.Seen[m.Name] = true
                            app:Notification({ Title = "Rare Monster", Subtitle = m.Name, Duration = 6 })
                        end
                    end
                end
            end
            task.wait(3)
        end
    end)
end
function notifySystem.MainTwisted:Stop() self.Enabled = false end

function notifySystem.LowHealth:Start()
    self.Enabled = true; self.Seen = {}
    task.spawn(function()
        while self.Enabled do
            local igp = workspace:FindFirstChild("InGamePlayers")
            if igp then
                for _, m in ipairs(igp:GetChildren()) do
                    if m:IsA("Model") and m.Name ~= localPlayer.Name and not self.Seen[m] then
                        local hum = m:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health == 1 then
                            self.Seen[m] = true
                            app:Notification({ Title = "Low Health", Subtitle = m.Name .. " (HP:1)", Duration = 5 })
                        end
                    end
                end
            end
            task.wait(1)
        end
    end)
end
function notifySystem.LowHealth:Stop() self.Enabled = false end

-- ============================================================
-- 🎨 UI BUILD
-- ============================================================

-- ─── AUTO FARM ───
local farmForm = farmTab:PageSection({ Title = "Auto Farm", Subtitle = "ปั่นเครื่อง (walk via pathfinder)" }):Form()
do local r = farmForm:Row({ SearchIndex = "AutoFarm" })
    r:Left():TitleStack({ Title = "Enable Auto Farm", Subtitle = "เดิน + interact อัตโนมัติ" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        autoFarm.Enabled = v
        if not v then pathfinder:Stop() end
        app:Notification({ Title = "Auto Farm", Subtitle = v and "Enabled" or "Disabled", Duration = 3 })
    end })
end
do local r = farmForm:Row({ SearchIndex = "AF Interact" })
    r:Left():TitleStack({ Title = "Auto Interact", Subtitle = "ยิง ProximityPrompt" })
    r:Right():Toggle({ Value = true, ValueChanged = function(_, v) autoFarm.AutoInteract = v end })
end
do local r = farmForm:Row({ SearchIndex = "AF Move" })
    r:Left():TitleStack({ Title = "Auto Move (Pathfinding)", Subtitle = "เดินตามเส้นทาง หลบกำแพง" })
    r:Right():Toggle({ Value = true, ValueChanged = function(_, v)
        autoFarm.AutoMove = v
        if not v then pathfinder:Stop() end
    end })
end
do local r = farmForm:Row({ SearchIndex = "AF Elevator" })
    r:Left():TitleStack({ Title = "Auto Elevator", Subtitle = "ไปลิฟต์เมื่อครบเครื่อง" })
    r:Right():Toggle({ Value = true, ValueChanged = function(_, v) autoFarm.AutoElevator = v end })
end
addSlider(farmForm, {
    SearchIndex = "WalkSpeed Path", Title = "Walk Speed (Path)",
    Subtitle = "WalkSpeed ฐาน (Tween +5)",
    Min = 10, Max = 100, Default = 22,
    OnChanged = function(v) autoFarm.WalkSpeedPath = v end,
})

-- ─── AVOID ───
local avoidForm = farmTab:PageSection({ Title = "Auto Avoid", Subtitle = "หลบมอน/บอส" }):Form()
do local r = avoidForm:Row({ SearchIndex = "Avoid Enable" })
    r:Left():TitleStack({ Title = "Enable Avoid", Subtitle = "หนีเมื่ออยู่ในรัศมีมอน/บอส" })
    r:Right():Toggle({ Value = true, ValueChanged = function(_, v) avoid.Enabled = v end })
end
addSlider(avoidForm, {
    SearchIndex = "Danger Radius", Title = "Danger Radius",
    Subtitle = "รัศมีรอบมอนทั่วไป",
    Min = 10, Max = 60, Default = 22, Suffix = "studs",
    OnChanged = function(v) avoid.DangerRadius = v end,
})
addSlider(avoidForm, {
    SearchIndex = "Boss Radius", Title = "Boss Radius",
    Subtitle = "รัศมีรอบบอส",
    Min = 20, Max = 100, Default = 40, Suffix = "studs",
    OnChanged = function(v) avoid.BossRadius = v end,
})
addSlider(avoidForm, {
    SearchIndex = "Evade Duration", Title = "Evade Duration",
    Subtitle = "เวลาวิ่งหนี",
    Min = 0.5, Max = 5, Default = 1.5, Suffix = "s", Integer = false,
    OnChanged = function(v) avoid.EvadeDuration = v end,
})

-- ─── PICK ALL ───
local pickForm = farmTab:PageSection({ Title = "Item Picker", Subtitle = "เก็บของ" }):Form()
do local r = pickForm:Row({ SearchIndex = "PickAll" })
    r:Left():TitleStack({ Title = "Pick All Items", Subtitle = "เดินไปเก็บไอเทมทั้งหมด" })
    r:Right():Button({
        Title = "Run",
        OnClick = function()
            pickAll:Run()
            app:Notification({ Title = "Pick All", Subtitle = "Started", Duration = 2 })
        end,
    })
end

-- ─── ABILITIES ───
local itemAbForm = abilityTab:PageSection({ Title = "Items", Subtitle = "ใช้ไอเทม" }):Form()
do local r = itemAbForm:Row({ SearchIndex = "AutoUseItems" })
    r:Left():TitleStack({ Title = "Auto Use Items", Subtitle = "Slot1-3" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then abilities.AutoUseItems:Start() else abilities.AutoUseItems:Stop() end
    end })
end

local abForm = abilityTab:PageSection({ Title = "Abilities", Subtitle = "สกิล" }):Form()
do local r = abForm:Row({ SearchIndex = "AutoAbility" })
    r:Left():TitleStack({ Title = "Auto Use Ability", Subtitle = "ใช้สกิล" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then abilities.AutoUseAbility:Start() else abilities.AutoUseAbility:Stop() end
    end })
end
do local r = abForm:Row({ SearchIndex = "SproutHeal" })
    r:Left():TitleStack({ Title = "Sprout Self Heal", Subtitle = "ใช้กับ Sprout" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then abilities.SproutSelfHeal:Start() else abilities.SproutSelfHeal:Stop() end
    end })
end
do local r = abForm:Row({ SearchIndex = "ShellyBoost" })
    r:Left():TitleStack({ Title = "Shelly Boost", Subtitle = "ใช้กับ Shelly" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then abilities.ShellyBoost:Start() else abilities.ShellyBoost:Stop() end
    end })
end

local skillForm = abilityTab:PageSection({ Title = "Skill Check", Subtitle = "" }):Form()
do local r = skillForm:Row({ SearchIndex = "AutoSC" })
    r:Left():TitleStack({ Title = "Auto Skill Check", Subtitle = "ตอบเป๊ะ" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then skillCheck:EnableAuto() else skillCheck:DisableAuto() end
    end })
end
do local r = skillForm:Row({ SearchIndex = "RemSC" })
    r:Left():TitleStack({ Title = "Remove SkillCheck Frame", Subtitle = "ลบ UI" })
    r:Right():Button({ Title = "Remove", OnClick = function() skillCheck:DestroyFrame() end })
end

-- ─── VISUALS ───
local genEForm = visualTab:PageSection({
    Title = "Generator ESP",
    Subtitle = "🟢 ซ่อมแล้ว · 🔴 ยังไม่ซ่อม"
}):Form()
do local r = genEForm:Row({ SearchIndex = "Gen ESP" })
    r:Left():TitleStack({ Title = "Generator ESP", Subtitle = "เขียว = ซ่อมแล้ว · แดง = ยัง" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then generatorESP:Start() else generatorESP:Stop() end
    end })
end

local monEForm = visualTab:PageSection({ Title = "Monster ESP", Subtitle = "" }):Form()
do local r = monEForm:Row({ SearchIndex = "Monster ESP" })
    r:Left():TitleStack({ Title = "Monster ESP", Subtitle = "Highlight + HP (แดง)" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then monsterESP:Start() else monsterESP:Stop() end
    end })
end
do local r = monEForm:Row({ SearchIndex = "Special ESP" })
    r:Left():TitleStack({ Title = "Special Main ESP", Subtitle = "บอสตัวหลัก (เหลือง)" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then specialMainESP:Start() else specialMainESP:Stop() end
    end })
end

local itemEForm = visualTab:PageSection({ Title = "Item ESP", Subtitle = "" }):Form()
do local r = itemEForm:Row({ SearchIndex = "Item ESP" })
    r:Left():TitleStack({ Title = "Item ESP", Subtitle = "ไอเทม (ฟ้า) / ยา (เขียวมิ้นต์)" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then itemESP:Start() else itemESP:Stop() end
    end })
end

local elevEForm = visualTab:PageSection({ Title = "Elevator ESP", Subtitle = "" }):Form()
do local r = elevEForm:Row({ SearchIndex = "Elev ESP" })
    r:Left():TitleStack({ Title = "Elevator ESP", Subtitle = "ลิฟต์ (ม่วง)" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then elevatorESP:Start() else elevatorESP:Stop() end
    end })
end

local plEForm = visualTab:PageSection({ Title = "Player ESP", Subtitle = "" }):Form()
do local r = plEForm:Row({ SearchIndex = "Player ESP" })
    r:Left():TitleStack({ Title = "Player ESP", Subtitle = "ผู้เล่น + HP" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then playerESP:Start() else playerESP:Stop() end
    end })
end

local hpEForm = visualTab:PageSection({ Title = "Low Health ESP", Subtitle = "" }):Form()
do local r = hpEForm:Row({ SearchIndex = "LowHP ESP" })
    r:Left():TitleStack({ Title = "Low Health ESP", Subtitle = "เลือด 1 (น้ำตาล)" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then lowHealthESP:Start() else lowHealthESP:Stop() end
    end })
end

local espCfg = visualTab:PageSection({ Title = "ESP Settings", Subtitle = "" }):Form()
do local r = espCfg:Row({ SearchIndex = "ShowHP" })
    r:Left():TitleStack({ Title = "Show Health Bar", Subtitle = "แสดงหลอดเลือด" })
    r:Right():Toggle({ Value = true, ValueChanged = function(_, v) ESP_CONFIG.ShowHealth = v end })
end
addSlider(espCfg, {
    SearchIndex = "MaxDist", Title = "Max Distance", Subtitle = "ระยะสูงสุด",
    Min = 100, Max = 5000, Default = 2000, Suffix = "studs",
    OnChanged = function(v) ESP_CONFIG.MaxDistance = v end,
})

local camF = visualTab:PageSection({ Title = "Camera & Lighting", Subtitle = "" }):Form()
do local r = camF:Row({ SearchIndex = "FOV Toggle" })
    r:Left():TitleStack({ Title = "Enable Custom FOV", Subtitle = "" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v) cameraMod:ToggleFOV(v) end })
end
addSlider(camF, {
    SearchIndex = "FOV", Title = "FOV Value", Subtitle = "",
    Min = 30, Max = 120, Default = 70, Suffix = "deg",
    OnChanged = function(v) cameraMod:SetFOV(v) end,
})
do local r = camF:Row({ SearchIndex = "Fullbright" })
    r:Left():TitleStack({ Title = "Fullbright", Subtitle = "สว่างใส" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v) cameraMod:ToggleFullbright(v) end })
end
do local r = camF:Row({ SearchIndex = "NoFog" })
    r:Left():TitleStack({ Title = "No Fog", Subtitle = "ลบหมอก" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then noFog:Start() else noFog:Stop() end
    end })
end

-- ─── NOTIFY ───
local notifF = notifyTab:PageSection({ Title = "Notifications", Subtitle = "" }):Form()
do local r = notifF:Row({ SearchIndex = "NotifyRare" })
    r:Left():TitleStack({ Title = "Notify Rare Items", Subtitle = "Bandage/SmokeBomb ฯลฯ" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then notifySystem.RareItems:Start() else notifySystem.RareItems:Stop() end
    end })
end
do local r = notifF:Row({ SearchIndex = "NotifyMain" })
    r:Left():TitleStack({ Title = "Notify Main Twisteds", Subtitle = "Astro/Vee/Sprout ฯลฯ" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then notifySystem.MainTwisted:Start() else notifySystem.MainTwisted:Stop() end
    end })
end
do local r = notifF:Row({ SearchIndex = "NotifyLow" })
    r:Left():TitleStack({ Title = "Notify Low Health", Subtitle = "ผู้เล่นเลือด 1" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then notifySystem.LowHealth:Start() else notifySystem.LowHealth:Stop() end
    end })
end

-- ─── MOVEMENT ───
local mf = moveTab:PageSection({ Title = "Movement", Subtitle = "" }):Form()
do local r = mf:Row({ SearchIndex = "Noclip" })
    r:Left():TitleStack({ Title = "No Clip", Subtitle = "ลบ InvisBorder" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then noClip:Start() else noClip:Stop() end
    end })
end
do local r = mf:Row({ SearchIndex = "InfJump" })
    r:Left():TitleStack({ Title = "Infinity Jump", Subtitle = "SPACE กลางอากาศ" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v) infinityJump.Enabled = v end })
end
addSlider(mf, {
    SearchIndex = "JumpForce", Title = "Jump Force", Subtitle = "",
    Min = 10, Max = 100, Default = 50,
    OnChanged = function(v) infinityJump.JumpForce = v end,
})
do local r = mf:Row({ SearchIndex = "WS" })
    r:Left():TitleStack({ Title = "Enable WalkSpeed", Subtitle = "ล็อกความเร็วเดิน" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then walkSpeed:Start() else walkSpeed:Stop() end
    end })
end
addSlider(mf, {
    SearchIndex = "Speed", Title = "Speed Value", Subtitle = "ปกติ 16",
    Min = 1, Max = 500, Default = 16,
    OnChanged = function(v) walkSpeed:SetSpeed(v) end,
})
do local r = mf:Row({ SearchIndex = "Fly" })
    r:Left():TitleStack({ Title = "Fly", Subtitle = "W/A/S/D + SPACE/SHIFT" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then fly:Start() else fly:Stop() end
    end })
end
addSlider(mf, {
    SearchIndex = "FlySpeed", Title = "Fly Speed", Subtitle = "",
    Min = 20, Max = 300, Default = 60,
    OnChanged = function(v) fly.Speed = v end,
})

-- ─── SETTINGS ───
local credF = settingsTab:PageSection({ Title = "Credits", Subtitle = "" }):Form()
do local r = credF:Row({ SearchIndex = "Credits" })
    r:Left():TitleStack({ Title = "999ms HUB v8", Subtitle = "by 09ms | Full Merge" })
end

-- ============================================================
-- Room change handler
-- ============================================================
local function onRoomChanged()
    if pathfinder.Active then pathfinder:Stop() end
    if generatorESP.Enabled   then generatorESP:Scan()   end
    if itemESP.Enabled        then itemESP:Scan()        end
    if monsterESP.Enabled     then monsterESP:Scan()     end
    if specialMainESP.Enabled then specialMainESP:Scan() end
    if elevatorESP.Enabled    then elevatorESP:Scan()    end
end

do
    local room = workspace:FindFirstChild("CurrentRoom")
    if room then
        room.ChildAdded:Connect(onRoomChanged)
        room.ChildRemoved:Connect(onRoomChanged)
    end
    workspace.ChildAdded:Connect(function(c)
        if c.Name == "CurrentRoom" then onRoomChanged() end
    end)
end

-- ============================================================
-- Ready
-- ============================================================
app:Notification({
    App = "999ms HUB",
    Title = "v8 Full Loaded",
    Subtitle = "Generator ESP (Status-based) · Pathfinder + Tween · Auto Farm · Abilities",
    Icon = cascade.Symbols.checkmark,
    Duration = 5,
})