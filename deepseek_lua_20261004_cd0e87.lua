-- 999ms HUB | All-in-One v4
-- Full Auto Farm · Events · ESP · Movement

local replicatedStorage = game:GetService("ReplicatedStorage")
local runService        = game:GetService("RunService")
local lighting          = game:GetService("Lighting")
local players           = game:GetService("Players")
local userInputService  = game:GetService("UserInputService")
local localPlayer       = players.LocalPlayer

-- ============================================================
-- CORE GUI
-- ============================================================
local coreGui
pcall(function() coreGui = (gethui and gethui()) or game:GetService("CoreGui") end)
if not coreGui then coreGui = game:GetService("CoreGui") end

local IS_MOBILE = userInputService.TouchEnabled and not userInputService.KeyboardEnabled

local function getWindowSize()
    if IS_MOBILE then
        local vp = workspace.CurrentCamera.ViewportSize
        return UDim2.fromOffset(math.floor(vp.X * 0.92), math.floor(vp.Y * 0.72))
    end
    return UDim2.fromOffset(560, 420)
end

local WIN_SIZE     = getWindowSize()
local WIN_MIN_SIZE = IS_MOBILE and Vector2.new(300, 280) or Vector2.new(480, 320)
local WIN_MAX_SIZE = IS_MOBILE and Vector2.new(600, 550) or Vector2.new(720, 520)

-- ============================================================
-- CASCADE UI
-- ============================================================
local function importRelease(owner, repo, version, file)
    local tag = (version == "latest" and "latest/download" or "download/" .. version)
    local url = ("https://github.com/%s/%s/releases/%s/%s"):format(owner, repo, tag, file)
    return loadstring(game:HttpGetAsync(url), file)()
end

local cascade
do
    local ok, r = pcall(function() return importRelease("cascadeui", "Cascade", "latest", "dist.luau") end)
    if not ok or not r then warn("[999ms HUB] Cascade load failed:", r); return end
    cascade = r
end

local app = cascade.New({
    Theme = cascade.Themes.Dark, Accent = cascade.Accents.Blue, WindowPill = true,
})

local window = app:Window({
    Title = "999ms HUB", Subtitle = "by 09ms | Dandy World (All-in-One v4)",
    Size = WIN_SIZE, MinSize = WIN_MIN_SIZE, MaxSize = WIN_MAX_SIZE,
    Draggable = true, Resizable = true, Dropshadow = true, UIBlur = false, Searching = true,
})

-- ============================================================
-- TABS
-- ============================================================
local mainSection = window:Section({ Title = "Menu", Disclosure = true, Expanded = true })

local autoFarmTab = mainSection:Tab({ Title = "Auto Farm", Icon = cascade.Symbols.squareStack3dUp, Selected = true })
local eventTab    = mainSection:Tab({ Title = "Events",    Icon = cascade.Symbols.sparkles })
local visualsTab  = mainSection:Tab({ Title = "Visuals",   Icon = cascade.Symbols.eye })
local movementTab = mainSection:Tab({ Title = "Movement",  Icon = cascade.Symbols.arrowUpCircle })
local manualTab   = mainSection:Tab({ Title = "Manual",    Icon = cascade.Symbols.handRaised })
local settingsTab = mainSection:Tab({ Title = "Settings",  Icon = cascade.Symbols.gear })

-- ============================================================
-- HELPERS
-- ============================================================
local function addSliderWithValue(form, o)
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

local function safePivotTo(char, cf)
    if not char or not char.Parent then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    pcall(function()
        char:PivotTo(cf)
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    return true
end

local function getCurrentMap()
    local room = workspace:FindFirstChild("CurrentRoom")
    if not room then return nil end
    for _, o in ipairs(room:GetChildren()) do
        if o:IsA("Model") or o:IsA("Folder") then return o end
    end
end

-- ============================================================
-- 👻 INVISIBILITY
-- ============================================================
local invisibility = {
    Enabled = false, SpoofOffset = Vector3.new(0, 500, 0),
    Connection = nil, VisualConn = nil,
}
function invisibility:Apply(char)
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p.CanQuery = not self.Enabled
            p.CanTouch = not self.Enabled
        end
    end
end
function invisibility:_bind(char)
    if self.VisualConn then self.VisualConn:Disconnect() end
    self.VisualConn = char.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") then d.CanQuery = not self.Enabled; d.CanTouch = not self.Enabled end
    end)
end
function invisibility:Start()
    self.Enabled = true
    local c = localPlayer.Character
    if c then self:Apply(c); self:_bind(c) end
    if self.Connection then self.Connection:Disconnect() end
    self.Connection = runService.Stepped:Connect(function()
        if not self.Enabled then return end
        local cc = localPlayer.Character
        local hrp = cc and cc:FindFirstChild("HumanoidRootPart")
        if hrp then
            local real = hrp.CFrame
            hrp.CFrame = real + self.SpoofOffset
            hrp.CFrame = real
        end
    end)
end
function invisibility:Stop()
    self.Enabled = false
    if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
    if self.VisualConn  then self.VisualConn:Disconnect();  self.VisualConn  = nil end
    self:Apply(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(function(c)
    task.wait(0.5)
    if invisibility.Enabled then invisibility:Apply(c); invisibility:_bind(c) end
end)

-- ============================================================
-- 🚪 NOCLIP
-- ============================================================
local noClip = { Enabled = false, Conn = nil }
function noClip:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Stepped:Connect(function()
        if not self.Enabled then return end
        local c = localPlayer.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end)
end
function noClip:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
    local c = localPlayer.Character
    if c then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
        end
    end
end

-- ============================================================
-- 🌫️ NO FOG
-- ============================================================
local noFog = { Enabled = false, Conn = nil, Orig = nil }
function noFog:Start()
    self.Enabled = true
    self.Orig = { FogEnd = lighting.FogEnd, FogStart = lighting.FogStart }
    lighting.FogEnd = 100000
    lighting.FogStart = 100000
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
        if self.Enabled then lighting.FogEnd = 100000 end
    end)
end
function noFog:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
    if self.Orig then
        lighting.FogEnd   = self.Orig.FogEnd
        lighting.FogStart = self.Orig.FogStart
    end
end

-- ============================================================
-- 🕊️ FLY (Fly ด้านบนที่บอทตีไม่โดน)
-- ============================================================
local fly = { Enabled = false, Speed = 60, Height = 80, Conn = nil, BodyVel = nil, Gyro = nil }
function fly:Start()
    self.Enabled = true
    local char, hrp = getChar()
    if not hrp then return end

    if self.BodyVel then self.BodyVel:Destroy() end
    if self.Gyro    then self.Gyro:Destroy() end

    self.BodyVel = Instance.new("BodyVelocity")
    self.BodyVel.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    self.BodyVel.Velocity = Vector3.zero
    self.BodyVel.Parent   = hrp

    self.Gyro = Instance.new("BodyGyro")
    self.Gyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    self.Gyro.P        = 1000
    self.Gyro.Parent   = hrp

    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function()
        if not self.Enabled then return end
        local c, r = getChar()
        if not r then return end

        local cam = workspace.CurrentCamera
        local dir = Vector3.zero
        local move = localPlayer:GetMouse() -- fallback
        if userInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if userInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if userInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if userInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if userInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if userInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0, 1, 0) end

        self.BodyVel.Velocity = dir.Magnitude > 0 and (dir.Unit * self.Speed) or Vector3.zero
        self.Gyro.CFrame = cam.CFrame
    end)
end
function fly:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
    if self.BodyVel then self.BodyVel:Destroy(); self.BodyVel = nil end
    if self.Gyro    then self.Gyro:Destroy();    self.Gyro    = nil end
end

-- ============================================================
-- 🌾 AUTO FARM CORE
-- ============================================================
local autoFarm = {
    Enabled = false, AutoInteract = true, AutoTeleport = true, AutoElevator = true,
    UseSafeZone = true, SafeDistance = 45, TickRate = 20, TeleportCooldown = 0.25,
    InteractRange = 12, _lastTP = 0, _tickAccum = 0, _steppedConn = nil,
    CachedGenerators = setmetatable({}, { __mode = "k" }),
    _statsCache = setmetatable({}, { __mode = "k" }),
    SafeZone = nil,
}
function autoFarm:_ensureSafeZone()
    local sz = workspace:FindFirstChild("AutoGenSafeZone")
    if not sz then
        sz = Instance.new("Part")
        sz.Name = "AutoGenSafeZone"; sz.Size = Vector3.new(50, 1, 50)
        sz.Anchored = true; sz.Transparency = 1
        sz.CanCollide = false; sz.CanQuery = false; sz.CanTouch = false
        sz.Parent = workspace
    end
    self.SafeZone = sz
end
local function getGenPos(gen)
    if gen.PrimaryPart then return gen.PrimaryPart.Position end
    local ok, p = pcall(function() return gen:GetPivot() end)
    return ok and p.Position or Vector3.zero
end
function autoFarm:GetNearestMonsterDistance(pos)
    local map = getCurrentMap()
    if not map then return math.huge end
    local mons = map:FindFirstChild("Monsters")
    if not mons then return math.huge end
    local best = math.huge
    for _, m in ipairs(mons:GetChildren()) do
        if m:IsA("Model") then
            local bp = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
            if bp then
                local d = (bp.Position - pos).Magnitude
                if d < best then best = d end
            end
        end
    end
    return best
end
function autoFarm:GetGeneratorTargetCFrame(gen)
    local g = gen:FindFirstChild("TeleportPositions") or gen:FindFirstChild("TreadmillTeleportPositions")
    if g and #g:GetChildren() > 0 then return g:GetChildren()[1].CFrame end
    local s = gen:FindFirstChild("TeleportPosition") or gen:FindFirstChild("TreadmillTeleportPosition")
    if s then return s.CFrame end
    return CFrame.new(getGenPos(gen)) * CFrame.new(0, 0, 4)
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
    self:_ensureSafeZone()
    local function cache(o)
        if o:IsA("Model") and o:GetAttribute("MinigameType") then
            self.CachedGenerators[o] = true
        end
    end
    for _, o in ipairs(workspace:GetDescendants()) do cache(o) end
    workspace.DescendantAdded:Connect(cache)
    self._steppedConn = runService.Stepped:Connect(function(_, dt)
        if not self.Enabled then return end
        self._tickAccum += dt
        if self._tickAccum < (1 / self.TickRate) then return end
        self._tickAccum = 0
        pcall(self.Step, self)
    end)
end
function autoFarm:GoToSafeZone(char, hrp)
    if not self.UseSafeZone then return end
    self:_ensureSafeZone()
    local base = hrp.Position
    for g in pairs(self.CachedGenerators) do
        if g.Parent then base = getGenPos(g); break end
    end
    self.SafeZone.CFrame = CFrame.new(base.X, base.Y + 50, base.Z)
    if math.abs(hrp.Position.Y - self.SafeZone.Position.Y) > 10 then
        safePivotTo(char, self.SafeZone.CFrame * CFrame.new(0, 3, 0))
    end
end
function autoFarm:_tryElevator(char, hrp)
    local e = workspace:FindFirstChild("Elevators")
    local el = e and e:FindFirstChild("Elevator")
    if not el then return false end
    local piv = el.PrimaryPart and el.PrimaryPart.CFrame or el:GetPivot()
    if (hrp.Position - piv.Position).Magnitude > 8 then
        safePivotTo(char, piv * CFrame.new(0, 3, 0))
    end
    return true
end
function autoFarm:Step()
    local char, hrp, hum = getChar()
    if not char or not hrp or not hum or hum.Health <= 0 then return end

    local info = workspace:FindFirstChild("Info")
    local panic = info and info:FindFirstChild("Panic") and info.Panic.Value == true

    local total, unfinished = 0, 0
    local interactingStats = nil
    local bestGen, bestDist = nil, math.huge
    local now = os.clock()

    for gen in pairs(self.CachedGenerators) do
        if gen.Parent then
            local stats = gen:FindFirstChild("Stats")
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
                        local gp = getGenPos(gen)
                        if self:GetNearestMonsterDistance(gp) >= self.SafeDistance then
                            local d = (gp - hrp.Position).Magnitude
                            if d < bestDist then bestGen, bestDist = gen, d end
                        end
                    end
                end
            end
        end
    end
    if total == 0 then return end

    local monNear = self:GetNearestMonsterDistance(hrp.Position) < self.SafeDistance
    if interactingStats and (monNear or panic) then
        local stop = interactingStats:FindFirstChild("StopInteracting")
        if stop and stop:IsA("RemoteEvent") then pcall(function() stop:FireServer() end) end
        interactingStats = nil
    end

    if self.AutoElevator and (panic or unfinished == 0) then
        self:_tryElevator(char, hrp); return
    end

    if not interactingStats and self.AutoTeleport then
        if bestGen and now - self._lastTP >= self.TeleportCooldown then
            local tgt = self:GetGeneratorTargetCFrame(bestGen)
            if (tgt.Position - hrp.Position).Magnitude > 5 then
                if safePivotTo(char, tgt) then self._lastTP = now end
            end
        elseif not bestGen and self.UseSafeZone then
            self:GoToSafeZone(char, hrp); return
        end
    end

    local inSafe = self.SafeZone and math.abs(hrp.Position.Y - self.SafeZone.Position.Y) < 10
    if self.AutoInteract and not interactingStats and not inSafe then
        for gen in pairs(self.CachedGenerators) do
            if gen.Parent then
                local stats = gen:FindFirstChild("Stats")
                if stats then
                    local comp = stats:FindFirstChild("Completed")
                    local ap   = stats:FindFirstChild("ActivePlayer")
                    local free = ap and (ap.Value == nil or ap.Value == char)
                    if comp and not comp.Value and free then
                        local gp = getGenPos(gen)
                        if self:GetNearestMonsterDistance(gp) >= self.SafeDistance then
                            local pr = gen:FindFirstChildWhichIsA("ProximityPrompt", true)
                            if pr and pr.Enabled then
                                local d = (gp - hrp.Position).Magnitude
                                local mr = pr.MaxActivationDistance + 2
                                if d <= math.min(mr, self.InteractRange) then
                                    pcall(fireproximityprompt, pr, 1)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
autoFarm:Init()

-- ============================================================
-- 🎮 AUTO BANABY (เครื่องตู้เกม)
-- ============================================================
local autoBanaby = { Enabled = false, Conn = nil, Range = 15 }
function autoBanaby:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function()
        if not self.Enabled then return end
        local char, hrp = getChar()
        if not hrp then return end
        local map = getCurrentMap()
        if not map then return end
        -- หา Banaby / Arcade ทุกที่
        for _, obj in ipairs(map:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name:lower():find("banaby") or obj.Name:lower():find("arcade")) then
                local bp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if bp then
                    -- TP ถ้าไกล
                    if (bp.Position - hrp.Position).Magnitude > self.Range then
                        safePivotTo(char, CFrame.new(bp.Position) * CFrame.new(0, 3, 4))
                    end
                    -- ยิง prompt
                    local pr = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if pr and pr.Enabled then pcall(fireproximityprompt, pr, 1) end
                end
            end
        end
    end)
end
function autoBanaby:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
end

-- ============================================================
-- ⚔️ AUTO COUNTER (วาปหน้าบอท + หลบ + เก็บแต้ม)
-- ============================================================
local autoCounter = { Enabled = false, Conn = nil, DodgeRange = 25, DodgeSpeed = 80 }
function autoCounter:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function()
        if not self.Enabled then return end
        local char, hrp = getChar()
        if not hrp then return end
        local map = getCurrentMap()
        if not map then return end
        local mons = map:FindFirstChild("Monsters")
        if not mons then return end

        for _, mon in ipairs(mons:GetChildren()) do
            if mon:IsA("Model") then
                local mp = mon.PrimaryPart or mon:FindFirstChildWhichIsA("BasePart")
                if mp then
                    local dist = (mp.Position - hrp.Position).Magnitude
                    -- เข้าไปใกล้บอทเพื่อให้โดน
                    if dist > 8 and dist < 60 then
                        safePivotTo(char, CFrame.new(mp.Position) * CFrame.new(0, 3, -6))
                    end
                    -- ถ้าใกล้เกิน (กำลังจะตี) → หลบ
                    if dist < self.DodgeRange then
                        local dodgeDir = (hrp.Position - mp.Position).Unit
                        local newPos = hrp.Position + dodgeDir * self.DodgeSpeed * 0.1
                        hrp.CFrame = CFrame.new(newPos, newPos + dodgeDir)
                    end
                end
            end
        end
    end)
end
function autoCounter:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
end

-- ============================================================
-- 🎁 AUTO PICKUP (เก็บของตามพื้น)
-- ============================================================
local autoPickup = { Enabled = false, Conn = nil, Range = 12,
    Whitelist = {
        ["Skillcheck"] = true, ["SkillCheck"] = true, ["Extraction"] = true,
        ["Medkit"] = true, ["MedKit"] = true, ["HealthKit"] = true,
        ["Bandage"] = true, ["Bandaid"] = true, ["Research"] = true,
        ["Tape"] = true, ["Battery"] = true, ["Key"] = true,
    },
}
function autoPickup:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function()
        if not self.Enabled then return end
        local char, hrp = getChar()
        if not hrp then return end
        local map = getCurrentMap()
        if not map then return end
        local items = map:FindFirstChild("Items")
        if not items then return end
        for _, it in ipairs(items:GetChildren()) do
            if it:IsA("Model") or it:IsA("BasePart") then
                local isWanted = self.Whitelist[it.Name]
                if not isWanted then
                    -- ลองจับ prefix
                    for k in pairs(self.Whitelist) do
                        if it.Name:lower():find(k:lower()) then isWanted = true; break end
                    end
                end
                if isWanted then
                    local ip = it.PrimaryPart or it:FindFirstChildWhichIsA("BasePart") or (it:IsA("BasePart") and it)
                    if ip then
                        if (ip.Position - hrp.Position).Magnitude > 3 then
                            safePivotTo(char, CFrame.new(ip.Position) * CFrame.new(0, 3, 0))
                        end
                    end
                end
            end
        end
    end)
end
function autoPickup:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
end

-- ============================================================
-- 🎃 EVENT: TRICK OR TREAT (Knock Knock Door)
-- ============================================================
local autoTrickOrTreat = { Enabled = false, Conn = nil }
function autoTrickOrTreat:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function()
        if not self.Enabled then return end
        local char, hrp = getChar()
        if not hrp then return end
        -- หา door / knock ทุกที่ใน workspace
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") or obj:IsA("BasePart") then
                local n = obj.Name:lower()
                if n:find("door") or n:find("knock") or n:find("treat") then
                    local op = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
                    if op then
                        if (op.Position - hrp.Position).Magnitude > 5 then
                            safePivotTo(char, CFrame.new(op.Position) * CFrame.new(0, 3, 4))
                        end
                        local pr = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if pr and pr.Enabled then pcall(fireproximityprompt, pr, 1) end
                    end
                end
            end
        end
    end)
end
function autoTrickOrTreat:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
end

-- ============================================================
-- 🎃 EVENT: AUTO PUMPKIN
-- ============================================================
local autoPumpkin = { Enabled = false, Conn = nil }
function autoPumpkin:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function()
        if not self.Enabled then return end
        local char, hrp = getChar()
        if not hrp then return end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") or obj:IsA("BasePart") then
                if obj.Name:lower():find("pumpkin") then
                    local op = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
                    if op then
                        if (op.Position - hrp.Position).Magnitude > 3 then
                            safePivotTo(char, CFrame.new(op.Position) * CFrame.new(0, 3, 0))
                        end
                        local pr = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if pr and pr.Enabled then pcall(fireproximityprompt, pr, 1) end
                    end
                end
            end
        end
    end)
end
function autoPumpkin:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
end

-- ============================================================
-- 👹 EVENT: GIVE ITEM TO GOUDY (Boss)
-- ============================================================
local autoGoudy = { Enabled = false, Conn = nil, GivenCount = 0 }
function autoGoudy:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function()
        if not self.Enabled then return end
        local char, hrp = getChar()
        if not hrp then return end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if (obj:IsA("Model") or obj:IsA("BasePart")) and obj.Name:lower():find("goudy") then
                local op = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
                if op then
                    if (op.Position - hrp.Position).Magnitude > 6 then
                        safePivotTo(char, CFrame.new(op.Position) * CFrame.new(0, 3, -6))
                    end
                    local pr = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if pr and pr.Enabled then
                        pcall(fireproximityprompt, pr, 1)
                        self.GivenCount += 1
                    end
                end
            end
        end
    end)
end
function autoGoudy:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
end

-- ============================================================
-- 🖐️ MANUAL: AUTO SKILL CHECK (สีเขียว)
-- ============================================================
local manualSkillCheck = { Enabled = false }
function manualSkillCheck:Start()
    self.Enabled = true
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
function manualSkillCheck:Stop()
    self.Enabled = false
    local ev = replicatedStorage:FindFirstChild("Events")
    if ev and ev:FindFirstChild("SkillcheckUpdate") then ev.SkillcheckUpdate.OnClientInvoke = nil end
end

-- ============================================================
-- 🖐️ MANUAL: AUTO TP ELEVATOR
-- ============================================================
local manualElevator = { Enabled = false, Conn = nil }
function manualElevator:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function()
        if not self.Enabled then return end
        local char, hrp = getChar()
        if not hrp then return end
        local e = workspace:FindFirstChild("Elevators")
        local el = e and e:FindFirstChild("Elevator")
        if el then
            local piv = el.PrimaryPart and el.PrimaryPart.CFrame or el:GetPivot()
            if (hrp.Position - piv.Position).Magnitude > 6 then
                safePivotTo(char, piv * CFrame.new(0, 3, 0))
            end
        end
    end)
end
function manualElevator:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
end

-- ============================================================
-- 🎨 ESP HELPERS
-- ============================================================
local ESPConfig = {
    TracerEnabled = true, BoxEnabled = false, ShowDistance = true,
    DistanceUnit = "m", MaxRenderDist = 500,
}
local function studsToUnit(s)
    if ESPConfig.DistanceUnit == "m" then return math.floor(s / 3.28 + 0.5) end
    return math.floor(s + 0.5)
end
local function createBillboard(parent, cfg)
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_BB"; bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 180, 0, 52)
    bb.StudsOffset = Vector3.new(0, cfg.OffsetY or 3, 0)
    bb.LightInfluence = 0; bb.MaxDistance = ESPConfig.MaxRenderDist
    bb.Adornee = parent; bb.Parent = coreGui

    local bg = Instance.new("Frame")
    bg.Name = "BG"; bg.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    bg.BackgroundTransparency = 0.25; bg.BorderSizePixel = 0
    bg.Size = UDim2.new(1, 0, 1, 0); bg.Parent = bb

    local co = Instance.new("UICorner"); co.CornerRadius = UDim2.new(0, 6, 0, 6); co.Parent = bg
    local st = Instance.new("UIStroke"); st.Thickness = 1.5; st.Color = cfg.Color
    st.Transparency = 0.15; st.Parent = bg

    local name = Instance.new("TextLabel")
    name.Name = "NameLabel"; name.BackgroundTransparency = 1
    name.Size = UDim2.new(1, -8, 0, 18); name.Position = UDim2.new(0, 4, 0, 2)
    name.Font = Enum.Font.GothamBold; name.Text = cfg.Name or "?"
    name.TextColor3 = cfg.Color; name.TextSize = 14
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.TextStrokeTransparency = 0.5; name.Parent = bg

    local dist = Instance.new("TextLabel")
    dist.Name = "DistLabel"; dist.BackgroundTransparency = 1
    dist.Size = UDim2.new(0, 60, 0, 18); dist.Position = UDim2.new(1, -64, 0, 2)
    dist.Font = Enum.Font.Gotham; dist.Text = ""
    dist.TextColor3 = Color3.fromRGB(220, 220, 220); dist.TextSize = 12
    dist.TextXAlignment = Enum.TextXAlignment.Right
    dist.TextStrokeTransparency = 0.5; dist.Parent = bg

    local hpBg = Instance.new("Frame")
    hpBg.Name = "HP_BG"; hpBg.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    hpBg.BorderSizePixel = 0; hpBg.Size = UDim2.new(1, -8, 0, 8)
    hpBg.Position = UDim2.new(0, 4, 1, -12); hpBg.Visible = false; hpBg.Parent = bg
    local hc = Instance.new("UICorner"); hc.CornerRadius = UDim2.new(0, 3, 0, 3); hc.Parent = hpBg

    local hpFill = Instance.new("Frame")
    hpFill.Name = "HP_Fill"; hpFill.BackgroundColor3 = Color3.fromRGB(0, 220, 90)
    hpFill.BorderSizePixel = 0; hpFill.Size = UDim2.new(1, 0, 1, 0); hpFill.Parent = hpBg
    local hf = Instance.new("UICorner"); hf.CornerRadius = UDim2.new(0, 3, 0, 3); hf.Parent = hpFill

    return bb, bg, name, dist, hpBg, hpFill, st
end
local function setIcon(bg, txt, color)
    local ic = Instance.new("TextLabel")
    ic.Name = "Icon"; ic.BackgroundTransparency = 1
    ic.Size = UDim2.new(0, 18, 0, 18); ic.Position = UDim2.new(0, 4, 0, 2)
    ic.Font = Enum.Font.GothamBold; ic.Text = txt
    ic.TextColor3 = color; ic.TextSize = 14; ic.Parent = bg
    local n = bg:FindFirstChild("NameLabel")
    if n then n.Position = UDim2.new(0, 22, 0, 2); n.Size = UDim2.new(1, -86, 0, 18) end
    return ic
end
local function createHighlight(target, color)
    local h = Instance.new("Highlight")
    h.Name = "ESP_HL"; h.Adornee = target
    h.FillColor = color; h.FillTransparency = 0.55
    h.OutlineColor = color; h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; h.Parent = coreGui
    return h
end
local function createBox()
    local b = Drawing.new("Square"); b.Thickness = 1.5; b.Filled = false
    b.Transparency = 0.85; b.Visible = false; return b
end
local function createBoxOutline()
    local o = Drawing.new("Square"); o.Thickness = 3; o.Filled = false
    o.Color = Color3.fromRGB(0, 0, 0); o.Transparency = 0.4; o.Visible = false; return o
end
local function createTracer(color)
    local l = Drawing.new("Line"); l.Thickness = 1.5; l.Color = color
    l.Transparency = 0.9; l.Visible = false; return l
end
local function getBoxData(part, cam)
    local pos, on = cam:WorldToViewportPoint(part.Position)
    if not on then return nil end
    local sz = part.Size
    local t = cam:WorldToViewportPoint(part.Position + Vector3.new(0, sz.Y/2, 0))
    local b = cam:WorldToViewportPoint(part.Position - Vector3.new(0, sz.Y/2, 0))
    local l = cam:WorldToViewportPoint(part.Position - Vector3.new(sz.X/2, 0, 0))
    local r = cam:WorldToViewportPoint(part.Position + Vector3.new(sz.X/2, 0, 0))
    return Vector2.new(l.X, t.Y), Vector2.new(math.abs(r.X - l.X), math.abs(b.Y - t.Y))
end

-- ============================================================
-- 📦 ESP: GENERATOR
-- ============================================================
local generatorESP = { Enabled = false, Color = Color3.fromRGB(0, 255, 140),
    Objects = setmetatable({}, { __mode = "k" }), CurrentFolder = nil, Connections = {} }
function generatorESP:_getFolder()
    local m = getCurrentMap(); return m and m:FindFirstChild("Generators")
end
function generatorESP:AddESP(t)
    if not self.Enabled or self.Objects[t] then return end
    local pp = t.PrimaryPart or t:FindFirstChildWhichIsA("BasePart")
    if not pp then return end
    local hl = createHighlight(t, self.Color)
    local bb, bg, n, d, _, _, st = createBillboard(pp, { Name = t.Name, Color = self.Color, OffsetY = 3.5 })
    local ic = setIcon(bg, "⚡", self.Color)
    self.Objects[t] = { Highlight = hl, Billboard = bb, BG = bg, NameLabel = n, DistLabel = d,
        Stroke = st, Icon = ic,
        Tracer = ESPConfig.TracerEnabled and createTracer(self.Color) or nil,
        Box = ESPConfig.BoxEnabled and createBox() or nil,
        BoxOutline = ESPConfig.BoxEnabled and createBoxOutline() or nil }
end
function generatorESP:RemoveESP(t)
    local o = self.Objects[t]; if not o then return end
    if o.Highlight then o.Highlight:Destroy() end
    if o.Billboard then o.Billboard:Destroy() end
    if o.Tracer then o.Tracer:Remove() end
    if o.Box then o.Box:Remove() end
    if o.BoxOutline then o.BoxOutline:Remove() end
    self.Objects[t] = nil
end
function generatorESP:ClearAll() for o in pairs(self.Objects) do self:RemoveESP(o) end end
function generatorESP:Scan()
    if not self.Enabled then return end
    local f = self:_getFolder()
    if not f then self:ClearAll(); return end
    for _, c in ipairs(f:GetChildren()) do
        if c:IsA("Model") or c:IsA("BasePart") then self:AddESP(c) end
    end
    for o in pairs(self.Objects) do
        if not o.Parent or o.Parent ~= f then self:RemoveESP(o) end
    end
end
function generatorESP:ConnectFolder()
    local f = self:_getFolder()
    if f == self.CurrentFolder then return end
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = f
    if not f then return end
    self.Connections.ChildAdded = f.ChildAdded:Connect(function(c)
        if (c:IsA("Model") or c:IsA("BasePart")) and self.Enabled then task.wait(0.1); self:AddESP(c) end
    end)
    self.Connections.ChildRemoved = f.ChildRemoved:Connect(function(c) self:RemoveESP(c) end)
end
function generatorESP:Start() self.Enabled = true; self:ConnectFolder(); self:Scan() end
function generatorESP:Stop()
    self.Enabled = false; self:ClearAll()
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end

-- ============================================================
-- 📦 ESP: MONSTER (TWITCHED)
-- ============================================================
local monsterESP = { Enabled = false, Color = Color3.fromRGB(255, 60, 80),
    Objects = setmetatable({}, { __mode = "k" }), CurrentFolder = nil, Connections = {} }
function monsterESP:_getFolder()
    local m = getCurrentMap(); return m and m:FindFirstChild("Monsters")
end
function monsterESP:CleanName(n) if n:sub(-7) == "Monster" then return n:sub(1, -8) end; return n end
function monsterESP:_bindHealth(mon, hpBg, hpFill)
    local hum = mon:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hpBg.Visible = true
    local function up()
        if not hum.Parent then return end
        local p = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        hpFill.Size = UDim2.new(p, 0, 1, 0)
        if p > 0.6 then hpFill.BackgroundColor3 = Color3.fromRGB(0, 220, 90)
        elseif p > 0.3 then hpFill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
        else hpFill.BackgroundColor3 = Color3.fromRGB(240, 50, 50) end
    end
    up(); hum.HealthChanged:Connect(up)
end
function monsterESP:AddESP(t)
    if not self.Enabled or self.Objects[t] then return end
    local pp = t.PrimaryPart or t:FindFirstChildWhichIsA("BasePart")
    if not pp then return end
    local hl = createHighlight(t, self.Color)
    local bb, bg, n, d, hb, hf, st = createBillboard(pp, { Name = self:CleanName(t.Name), Color = self.Color, OffsetY = 3.5 })
    local ic = setIcon(bg, "☠", self.Color)
    self:_bindHealth(t, hb, hf)
    self.Objects[t] = { Highlight = hl, Billboard = bb, BG = bg, NameLabel = n, DistLabel = d,
        HPBg = hb, HPFill = hf, Stroke = st, Icon = ic,
        Tracer = ESPConfig.TracerEnabled and createTracer(self.Color) or nil,
        Box = ESPConfig.BoxEnabled and createBox() or nil,
        BoxOutline = ESPConfig.BoxEnabled and createBoxOutline() or nil }
end
function monsterESP:RemoveESP(t)
    local o = self.Objects[t]; if not o then return end
    if o.Highlight then o.Highlight:Destroy() end
    if o.Billboard then o.Billboard:Destroy() end
    if o.Tracer then o.Tracer:Remove() end
    if o.Box then o.Box:Remove() end
    if o.BoxOutline then o.BoxOutline:Remove() end
    self.Objects[t] = nil
end
function monsterESP:ClearAll() for o in pairs(self.Objects) do self:RemoveESP(o) end end
function monsterESP:Scan()
    if not self.Enabled then return end
    local f = self:_getFolder()
    if not f then self:ClearAll(); return end
    for _, c in ipairs(f:GetChildren()) do if c:IsA("Model") then self:AddESP(c) end end
    for o in pairs(self.Objects) do if not o.Parent or o.Parent ~= f then self:RemoveESP(o) end end
end
function monsterESP:ConnectFolder()
    local f = self:_getFolder()
    if f == self.CurrentFolder then return end
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = f
    if not f then return end
    self.Connections.ChildAdded = f.ChildAdded:Connect(function(c)
        if c:IsA("Model") and self.Enabled then task.wait(0.1); self:AddESP(c) end
    end)
    self.Connections.ChildRemoved = f.ChildRemoved:Connect(function(c) self:RemoveESP(c) end)
end
function monsterESP:Start() self.Enabled = true; self:ConnectFolder(); self:Scan() end
function monsterESP:Stop()
    self.Enabled = false; self:ClearAll()
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end

-- ============================================================
-- 📦 ESP: ITEM
-- ============================================================
local itemESP = { Enabled = false, Color = Color3.fromRGB(80, 180, 255),
    HealthColor = Color3.fromRGB(80, 255, 120),
    Objects = setmetatable({}, { __mode = "k" }), CurrentFolder = nil, Connections = {} }
local ITEM_ICONS = { HealthKit="✚", Bandage="✚", Bandaid="✚", Medkit="✚", Battery="🔋", Key="🔑", Coin="◉", Tape="▬", Research="◈", Extraction="⇱", Skillcheck="✓", Default="◆" }
function itemESP:_getFolder()
    local m = getCurrentMap(); return m and m:FindFirstChild("Items")
end
function itemESP:AddESP(t)
    if not self.Enabled or self.Objects[t] then return end
    local pp = t:IsA("Model") and (t.PrimaryPart or t:FindFirstChildWhichIsA("BasePart")) or t
    if not pp or not pp:IsA("BasePart") then return end
    local isHealth = t.Name == "HealthKit" or t.Name == "Bandage" or t.Name == "Bandaid" or t.Name == "Medkit"
    local color = isHealth and self.HealthColor or self.Color
    local hl = createHighlight(t:IsA("Model") and t or pp, color)
    local bb, bg, n, d, _, _, st = createBillboard(pp, { Name = t.Name:gsub("(%l)(%u)", "%1 %2"), Color = color, OffsetY = 1.6 })
    local ic = setIcon(bg, ITEM_ICONS[t.Name] or ITEM_ICONS.Default, color)
    self.Objects[t] = { Highlight = hl, Billboard = bb, BG = bg, NameLabel = n, DistLabel = d,
        Stroke = st, Icon = ic,
        Tracer = ESPConfig.TracerEnabled and createTracer(color) or nil,
        Box = ESPConfig.BoxEnabled and createBox() or nil,
        BoxOutline = ESPConfig.BoxEnabled and createBoxOutline() or nil }
end
function itemESP:RemoveESP(t)
    local o = self.Objects[t]; if not o then return end
    if o.Highlight then o.Highlight:Destroy() end
    if o.Billboard then o.Billboard:Destroy() end
    if o.Tracer then o.Tracer:Remove() end
    if o.Box then o.Box:Remove() end
    if o.BoxOutline then o.BoxOutline:Remove() end
    self.Objects[t] = nil
end
function itemESP:ClearAll() for o in pairs(self.Objects) do self:RemoveESP(o) end end
function itemESP:Scan()
    if not self.Enabled then return end
    local f = self:_getFolder()
    if not f then self:ClearAll(); return end
    for _, c in ipairs(f:GetChildren()) do if c:IsA("Model") or c:IsA("BasePart") then self:AddESP(c) end end
    for o in pairs(self.Objects) do if not o.Parent or o.Parent ~= f then self:RemoveESP(o) end end
end
function itemESP:ConnectFolder()
    local f = self:_getFolder()
    if f == self.CurrentFolder then return end
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = f
    if not f then return end
    self.Connections.ChildAdded = f.ChildAdded:Connect(function(c)
        if (c:IsA("Model") or c:IsA("BasePart")) and self.Enabled then task.wait(0.1); self:AddESP(c) end
    end)
    self.Connections.ChildRemoved = f.ChildRemoved:Connect(function(c) self:RemoveESP(c) end)
end
function itemESP:Start() self.Enabled = true; self:ConnectFolder(); self:Scan() end
function itemESP:Stop()
    self.Enabled = false; self:ClearAll()
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end

-- ============================================================
-- 📦 ESP: PLAYER (เลือด + item ในตัว)
-- ============================================================
local playerESP = { Enabled = false, Color = Color3.fromRGB(255, 255, 80),
    Objects = setmetatable({}, { __mode = "k" }), Connections = {} }
function playerESP:_getInventoryText(plr)
    local char = plr.Character
    if not char then return "" end
    local backpack = plr:FindFirstChild("Backpack")
    local names = {}
    if backpack then
        for _, it in ipairs(backpack:GetChildren()) do
            if it:IsA("Tool") then names[#names+1] = it.Name end
        end
    end
    for _, it in ipairs(char:GetChildren()) do
        if it:IsA("Tool") then names[#names+1] = it.Name end
    end
    if #names == 0 then return "🎒 ว่าง" end
    return "🎒 " .. table.concat(names, ", ")
end
function playerESP:AddESP(plr)
    if not self.Enabled or self.Objects[plr] then return end
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local hl = createHighlight(char, self.Color)
    local bb, bg, n, d, hb, hf, st = createBillboard(hrp, { Name = plr.DisplayName or plr.Name, Color = self.Color, OffsetY = 3.5 })
    -- ขยาย billboard ให้แสดง inventory
    bg.Size = UDim2.new(1, 0, 1.4, 0)
    bb.Size = UDim2.new(0, 220, 0, 72)
    local ic = setIcon(bg, "👤", self.Color)

    -- Inventory label
    local inv = Instance.new("TextLabel")
    inv.Name = "InvLabel"; inv.BackgroundTransparency = 1
    inv.Size = UDim2.new(1, -8, 0, 16); inv.Position = UDim2.new(0, 4, 1, -30)
    inv.Font = Enum.Font.Gotham; inv.Text = ""; inv.TextColor3 = Color3.fromRGB(230, 230, 230)
    inv.TextSize = 11; inv.TextXAlignment = Enum.TextXAlignment.Left
    inv.TextStrokeTransparency = 0.5; inv.Parent = bg

    -- Health bind
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hb.Visible = true
        local function up()
            if not hum.Parent then return end
            local p = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
            hf.Size = UDim2.new(p, 0, 1, 0)
            if p > 0.6 then hf.BackgroundColor3 = Color3.fromRGB(0, 220, 90)
            elseif p > 0.3 then hf.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
            else hf.BackgroundColor3 = Color3.fromRGB(240, 50, 50) end
        end
        up(); hum.HealthChanged:Connect(up)
    end

    self.Objects[plr] = { Highlight = hl, Billboard = bb, BG = bg, NameLabel = n,
        DistLabel = d, HPBg = hb, HPFill = hf, Stroke = st, Icon = ic, InvLabel = inv,
        Tracer = ESPConfig.TracerEnabled and createTracer(self.Color) or nil,
        Box = ESPConfig.BoxEnabled and createBox() or nil,
        BoxOutline = ESPConfig.BoxEnabled and createBoxOutline() or nil }
end
function playerESP:RemoveESP(plr)
    local o = self.Objects[plr]; if not o then return end
    if o.Highlight then o.Highlight:Destroy() end
    if o.Billboard then o.Billboard:Destroy() end
    if o.Tracer then o.Tracer:Remove() end
    if o.Box then o.Box:Remove() end
    if o.BoxOutline then o.BoxOutline:Remove() end
    self.Objects[plr] = nil
end
function playerESP:ClearAll() for o in pairs(self.Objects) do self:RemoveESP(o) end end
function playerESP:Start()
    self.Enabled = true
    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= localPlayer then
            if plr.Character then self:AddESP(plr)
            else plr.CharacterAdded:Wait(); self:AddESP(plr) end
        end
    end
    if self.Connections.PlayerAdded then self.Connections.PlayerAdded:Disconnect() end
    if self.Connections.PlayerRemoving then self.Connections.PlayerRemoving:Disconnect() end
    self.Connections.PlayerAdded = players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function() task.wait(0.5); if self.Enabled then self:AddESP(plr) end end)
    end)
    self.Connections.PlayerRemoving = players.PlayerRemoving:Connect(function(plr) self:RemoveESP(plr) end)
end
function playerESP:Stop()
    self.Enabled = false; self:ClearAll()
    if self.Connections.PlayerAdded then self.Connections.PlayerAdded:Disconnect() end
    if self.Connections.PlayerRemoving then self.Connections.PlayerRemoving:Disconnect() end
end

-- ============================================================
-- 📦 ESP: ELEVATOR
-- ============================================================
local elevatorESP = { Enabled = false, Color = Color3.fromRGB(200, 120, 255),
    Objects = setmetatable({}, { __mode = "k" }), Conn = nil }
function elevatorESP:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = runService.Heartbeat:Connect(function()
        if not self.Enabled then return end
        local e = workspace:FindFirstChild("Elevators")
        local el = e and e:FindFirstChild("Elevator")
        if el and not self.Objects[el] then
            local pp = el.PrimaryPart or el:FindFirstChildWhichIsA("BasePart")
            if pp then
                local hl = createHighlight(el, self.Color)
                local bb, bg, n, d, _, _, st = createBillboard(pp, { Name = "Elevator", Color = self.Color, OffsetY = 3 })
                local ic = setIcon(bg, "🛗", self.Color)
                self.Objects[el] = { Highlight = hl, Billboard = bb, BG = bg, NameLabel = n,
                    DistLabel = d, Stroke = st, Icon = ic }
            end
        end
    end)
end
function elevatorESP:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect(); self.Conn = nil end
    for o, data in pairs(self.Objects) do
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
    end
    self.Objects = setmetatable({}, { __mode = "k" })
end

-- ============================================================
-- 🎬 ESP RENDER ENGINE
-- ============================================================
local function updateESPObject(target, data, base, cam, vp, pulse)
    if not target or not target.Parent then return false end
    local pp = target:IsA("Model") and (target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")) or target
    if not pp then return true end
    if data.Billboard and data.Billboard.Adornee ~= pp then data.Billboard.Adornee = pp end
    local myC = localPlayer.Character
    local myH = myC and myC:FindFirstChild("HumanoidRootPart")
    local dist = myH and (pp.Position - myH.Position).Magnitude or 0
    local vis = dist <= ESPConfig.MaxRenderDist
    if data.Billboard then data.Billboard.Enabled = vis end
    if data.Highlight then
        data.Highlight.Enabled = vis
        if vis then
            data.Highlight.FillColor = base
            data.Highlight.OutlineColor = base
            data.Highlight.FillTransparency = 0.55 + pulse * 0.15
        end
    end
    if not vis then
        if data.Tracer then data.Tracer.Visible = false end
        if data.Box then data.Box.Visible = false end
        if data.BoxOutline then data.BoxOutline.Visible = false end
        return true
    end
    if data.DistLabel and ESPConfig.ShowDistance then data.DistLabel.Text = studsToUnit(dist) .. ESPConfig.DistanceUnit end
    if data.NameLabel then data.NameLabel.TextColor3 = base end
    if data.Icon then data.Icon.TextColor3 = base end
    if data.Stroke then data.Stroke.Color = base; data.Stroke.Transparency = 0.05 + pulse * 0.2 end
    if data.BG then data.BG.BackgroundTransparency = 0.2 + math.clamp(dist / ESPConfig.MaxRenderDist, 0, 1) * 0.4 end
    if data.Tracer then
        local sp, on = cam:WorldToViewportPoint(pp.Position)
        if on then
            data.Tracer.Visible = true
            data.Tracer.From = Vector2.new(vp.X / 2, vp.Y)
            data.Tracer.To = Vector2.new(sp.X, sp.Y)
            data.Tracer.Color = base
            data.Tracer.Transparency = math.clamp(1 - dist / ESPConfig.MaxRenderDist, 0.15, 1)
        else data.Tracer.Visible = false end
    end
    if data.Box and data.BoxOutline then
        local pos, size = getBoxData(pp, cam)
        if pos and size and size.X > 0 and size.Y > 0 then
            data.Box.Visible = true; data.BoxOutline.Visible = true
            data.Box.Color = base; data.Box.Position = pos; data.Box.Size = size
            data.BoxOutline.Position = pos; data.BoxOutline.Size = size
        else data.Box.Visible = false; data.BoxOutline.Visible = false end
    end
    return true
end

runService.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local pulse = 0.5 + 0.5 * math.sin(tick() * 3.5)

    if generatorESP.Enabled then
        for t, d in pairs(generatorESP.Objects) do
            if not updateESPObject(t, d, generatorESP.Color, cam, vp, pulse) then generatorESP:RemoveESP(t) end
        end
    end
    if monsterESP.Enabled then
        for t, d in pairs(monsterESP.Objects) do
            if not updateESPObject(t, d, monsterESP.Color, cam, vp, pulse) then monsterESP:RemoveESP(t) end
        end
    end
    if itemESP.Enabled then
        for t, d in pairs(itemESP.Objects) do
            local isH = t.Name == "HealthKit" or t.Name == "Bandage" or t.Name == "Bandaid" or t.Name == "Medkit"
            local base = isH and itemESP.HealthColor or itemESP.Color
            if not updateESPObject(t, d, base, cam, vp, pulse) then itemESP:RemoveESP(t) end
        end
    end
    if playerESP.Enabled then
        for plr, d in pairs(playerESP.Objects) do
            if not plr.Parent or not plr.Character then
                playerESP:RemoveESP(plr)
            else
                if d.InvLabel then d.InvLabel.Text = playerESP:_getInventoryText(plr) end
                if not updateESPObject(plr.Character, d, playerESP.Color, cam, vp, pulse) then
                    playerESP:RemoveESP(plr)
                end
            end
        end
    end
    if elevatorESP.Enabled then
        for t, d in pairs(elevatorESP.Objects) do
            if not updateESPObject(t, d, elevatorESP.Color, cam, vp, pulse) then
                if d.Highlight then d.Highlight:Destroy() end
                if d.Billboard then d.Billboard:Destroy() end
                elevatorESP.Objects[t] = nil
            end
        end
    end
end)

-- ============================================================
-- 🎥 CAMERA & LIGHTING
-- ============================================================
local cameraMod = {
    FOVEnabled = false, FOV = 70, FullbrightEnabled = false,
    LightingConns = {},
    Orig = { Brightness = lighting.Brightness, ClockTime = lighting.ClockTime,
        FogEnd = lighting.FogEnd, GlobalShadows = lighting.GlobalShadows,
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
        local function ap()
            lighting.Brightness = 1; lighting.ClockTime = 14
            lighting.FogEnd = 100000; lighting.GlobalShadows = false
            lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        end
        ap()
        for _, p in ipairs({"Brightness", "ClockTime", "FogEnd", "GlobalShadows", "OutdoorAmbient"}) do
            self.LightingConns[p] = lighting:GetPropertyChangedSignal(p):Connect(ap)
        end
    else
        for _, c in pairs(self.LightingConns) do c:Disconnect() end
        self.LightingConns = {}
        local o = self.Orig
        lighting.Brightness = o.Brightness; lighting.ClockTime = o.ClockTime
        lighting.FogEnd = o.FogEnd; lighting.GlobalShadows = o.GlobalShadows
        lighting.OutdoorAmbient = o.OutdoorAmbient
    end
end

-- ============================================================
-- 🏃 MOVEMENT
-- ============================================================
local infinityJump = { Enabled = false, JumpForce = 50 }
function infinityJump:Jump()
    if not self.Enabled then return end
    local c = localPlayer.Character
    if not c then return end
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

local walkSpeed = { Enabled = false, Speed = 16, LoopConn = nil, CharConn = nil }
local runSpeed  = { Enabled = false, Speed = 24, LoopConn = nil, CharConn = nil }

local function getHum()
    local c = localPlayer.Character
    return c and c:FindFirstChildWhichIsA("Humanoid")
end

local function bindSpeed(sys, prop)
    sys.Enabled = true
    local h = getHum()
    if h then
        h[prop] = sys.Speed
        if sys.LoopConn then sys.LoopConn:Disconnect() end
        sys.LoopConn = h:GetPropertyChangedSignal(prop):Connect(function()
            if sys.Enabled then h[prop] = sys.Speed end
        end)
    end
    if sys.CharConn then sys.CharConn:Disconnect() end
    sys.CharConn = localPlayer.CharacterAdded:Connect(function(c)
        if not sys.Enabled then return end
        local h2 = c:WaitForChild("Humanoid")
        h2[prop] = sys.Speed
        if sys.LoopConn then sys.LoopConn:Disconnect() end
        sys.LoopConn = h2:GetPropertyChangedSignal(prop):Connect(function()
            if sys.Enabled then h2[prop] = sys.Speed end
        end)
    end)
end
local function unbindSpeed(sys, prop, def)
    sys.Enabled = false
    if sys.LoopConn then sys.LoopConn:Disconnect(); sys.LoopConn = nil end
    if sys.CharConn then sys.CharConn:Disconnect(); sys.CharConn = nil end
    local h = getHum(); if h then h[prop] = def end
end

function walkSpeed:Start() bindSpeed(self, "WalkSpeed") end
function walkSpeed:Stop()  unbindSpeed(self, "WalkSpeed", 16) end
function walkSpeed:SetSpeed(v) self.Speed = v; local h = getHum(); if self.Enabled and h then h.WalkSpeed = v end end

function runSpeed:Start() bindSpeed(self, "WalkSpeed") end
function runSpeed:Stop()  unbindSpeed(self, "WalkSpeed", 16) end
function runSpeed:SetSpeed(v) self.Speed = v; local h = getHum(); if self.Enabled and h then h.WalkSpeed = v end end

-- ============================================================
-- 🎨 UI BUILD
-- ============================================================

-- ─── TAB: AUTO FARM ───
local farmForm = autoFarmTab:PageSection({ Title = "Auto Farm", Subtitle = "ระบบฟาร์มอัตโนมัติ" }):Form()
do local r = farmForm:Row({ SearchIndex = "Enable Auto Farm" })
    r:Left():TitleStack({ Title = "Enable Auto Farm", Subtitle = "Toggle ระบบฟาร์มหลัก" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        autoFarm.Enabled = v
        app:Notification({ Title = "Auto Farm", Subtitle = v and "Enabled" or "Disabled", Duration = 3 }) end })
end
do local r = farmForm:Row({ SearchIndex = "Auto Fix Generators" })
    r:Left():TitleStack({ Title = "Auto Fix Generators", Subtitle = "ซ่อมเครื่องปั่นไฟ" })
    r:Right():Toggle({ Value = true, ValueChanged = function(_, v) autoFarm.AutoInteract = v end })
end
do local r = farmForm:Row({ SearchIndex = "Auto TP Generators" })
    r:Left():TitleStack({ Title = "Auto TP Generators", Subtitle = "TP ไปเครื่อง" })
    r:Right():Toggle({ Value = true, ValueChanged = function(_, v) autoFarm.AutoTeleport = v end })
end
do local r = farmForm:Row({ SearchIndex = "Auto Elevator" })
    r:Left():TitleStack({ Title = "Auto Elevator", Subtitle = "TP ไปลิฟต์" })
    r:Right():Toggle({ Value = true, ValueChanged = function(_, v) autoFarm.AutoElevator = v end })
end

local extraForm = autoFarmTab:PageSection({ Title = "Extra Farm", Subtitle = "ฟาร์มเสริม" }):Form()
do local r = extraForm:Row({ SearchIndex = "Auto Banaby" })
    r:Left():TitleStack({ Title = "Auto Banaby (Arcade)", Subtitle = "ปั่นเครื่องตู้เกมอัตโนมัติ" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then autoBanaby:Start() else autoBanaby:Stop() end end })
end
do local r = extraForm:Row({ SearchIndex = "Auto Counter" })
    r:Left():TitleStack({ Title = "Auto Counter", Subtitle = "วาปหน้าบอท + หลบ + เก็บแต้ม %" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then autoCounter:Start() else autoCounter:Stop() end end })
end
do local r = extraForm:Row({ SearchIndex = "Auto Pickup" })
    r:Left():TitleStack({ Title = "Auto Pickup", Subtitle = "เก็บของจำเป็นตามพื้น (Skillcheck, Medkit, Tape ฯลฯ)" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then autoPickup:Start() else autoPickup:Stop() end end })
end

local safetyForm = autoFarmTab:PageSection({ Title = "Safety & Invisibility", Subtitle = "ระบบป้องกัน" }):Form()
do local r = safetyForm:Row({ SearchIndex = "Bot Invisibility" })
    r:Left():TitleStack({ Title = "Bot Invisibility", Subtitle = "บอทมองไม่เห็น (Spoof Hitbox)" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then invisibility:Start() else invisibility:Stop() end
        app:Notification({ Title = "Invisibility", Subtitle = v and "Active" or "Disabled", Duration = 3 }) end })
end
do local r = safetyForm:Row({ SearchIndex = "Auto Safe Zone" })
    r:Left():TitleStack({ Title = "Auto Safe Zone", Subtitle = "หลบขึ้นฟ้าเมื่อมอนใกล้" })
    r:Right():Toggle({ Value = true, ValueChanged = function(_, v) autoFarm.UseSafeZone = v end })
end
addSliderWithValue(safetyForm, {
    SearchIndex = "Safe Distance", Title = "Safe Distance",
    Subtitle = "ระยะปลอดภัยจากมอน", Min = 10, Max = 150, Default = 45,
    Suffix = "studs", OnChanged = function(v) autoFarm.SafeDistance = v end,
})

-- ─── TAB: EVENTS ───
local evForm = eventTab:PageSection({ Title = "Halloween Events", Subtitle = "อีเว้นพิเศษ" }):Form()
do local r = evForm:Row({ SearchIndex = "Trick or Treat" })
    r:Left():TitleStack({ Title = "Trick or Treat", Subtitle = "เคาะประตู Knock Knock อัตโนมัติ" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then autoTrickOrTreat:Start() else autoTrickOrTreat:Stop() end end })
end
do local r = evForm:Row({ SearchIndex = "Auto Pumpkin" })
    r:Left():TitleStack({ Title = "Auto Pumpkin", Subtitle = "เก็บฟักทองตามแมพ" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then autoPumpkin:Start() else autoPumpkin:Stop() end end })
end
do local r = evForm:Row({ SearchIndex = "Auto Goudy" })
    r:Left():TitleStack({ Title = "Give to Goudy (Boss)", Subtitle = "ให้ไอเท็มชิ้นแรกกับ Goudy" })
    r:Right():Toggle({ Value = false, ValueChanged = function(_, v)
        if v then autoGoudy:Start() else autoGoudy:Stop() end end })
end

-- ─── TAB: VISUALS ───
local function addSimpleToggle(form, idx, title, sub, cb, def)
    local r = form:Row({ SearchIndex = idx })
    r:Left():TitleStack({ Title = title, Subtitle = sub })
    r:Right():Toggle({ Value = def or false, ValueChanged = function(_, v) cb(v) end })
end

local genForm = visualsTab:PageSection({ Title = "Generator ESP", Subtitle = "เครื่องปั่นไฟ" }):Form()
addSimpleToggle(genForm, "Generator ESP", "Generator ESP", "สีเขียว ⚡", function(v)
    if v then generatorESP:Start() else generatorESP:Stop() end end)

local monForm = visualsTab:PageSection({ Title = "Twitched ESP", Subtitle = "มอนสเตอร์" }):Form()
addSimpleToggle(monForm, "Twitched ESP", "Twitched ESP", "สีแดง ☠ + หลอดเลือด", function(v)
    if v then monsterESP:Start() else monsterESP:Stop() end end)

local itemForm = visualsTab:PageSection({ Title = "Item ESP", Subtitle = "ไอเทม" }):Form()
addSimpleToggle(itemForm, "Item ESP", "Item ESP", "ฟ้า/เขียว + icon", function(v)
    if v then itemESP:Start() else itemESP:Stop() end end)

local plForm = visualsTab:PageSection({ Title = "Player ESP", Subtitle = "ผู้เล่น" }):Form()
addSimpleToggle(plForm, "Player ESP", "Player ESP", "เลือด + item ในตัว", function(v)
    if v then playerESP:Start() else playerESP:Stop() end end)

local elForm = visualsTab:PageSection({ Title = "Elevator ESP", Subtitle = "ลิฟต์" }):Form()
addSimpleToggle(elForm, "Elevator ESP", "Elevator ESP", "สีม่วง 🛗", function(v)
    if v then elevatorESP:Start() else elevatorESP:Stop() end end)

local espSt = visualsTab:PageSection({ Title = "ESP Settings", Subtitle = "ปรับแต่ง" }):Form()
addSimpleToggle(espSt, "Tracer", "Tracer Lines", "เส้นชี้", function(v)
    ESPConfig.TracerEnabled = v
    local function ap(esp)
        for _, d in pairs(esp.Objects) do
            if v and not d.Tracer then d.Tracer = createTracer(esp.Color)
            elseif not v and d.Tracer then d.Tracer:Remove(); d.Tracer = nil end
        end
    end
    ap(generatorESP); ap(monsterESP); ap(itemESP); ap(playerESP)
end, true)
addSimpleToggle(espSt, "2D Box", "2D Box", "กรอบรอบเป้า", function(v)
    ESPConfig.BoxEnabled = v
    local function ap(esp)
        for _, d in pairs(esp.Objects) do
            if v and not d.Box then d.Box = createBox(); d.BoxOutline = createBoxOutline()
            elseif not v and d.Box then d.Box:Remove(); d.Box = nil; d.BoxOutline:Remove(); d.BoxOutline = nil end
        end
    end
    ap(generatorESP); ap(monsterESP); ap(itemESP); ap(playerESP)
end, false)
addSimpleToggle(espSt, "Show Distance", "Show Distance", "แสดงระยะ", function(v)
    ESPConfig.ShowDistance = v end, true)
addSliderWithValue(espSt, {
    SearchIndex = "Max Render Dist", Title = "Max Render Distance",
    Subtitle = "ระยะสูงสุด", Min = 100, Max = 2000, Default = 500,
    Suffix = "studs", OnChanged = function(v) ESPConfig.MaxRenderDist = v end,
})

local camForm = visualsTab:PageSection({ Title = "Camera & Lighting", Subtitle = "กล้อง & แสง" }):Form()
addSimpleToggle(camForm, "FOV", "Enable Custom FOV", "มุมมอง", function(v) cameraMod:ToggleFOV(v) end)
addSliderWithValue(camForm, {
    SearchIndex = "FOV Value", Title = "FOV Value", Subtitle = "ค่า FOV",
    Min = 30, Max = 120, Default = 70, Suffix = "deg",
    OnChanged = function(v) cameraMod:SetFOV(v) end })
addSimpleToggle(camForm, "Fullbright", "Fullbright", "สว่างใส", function(v) cameraMod:ToggleFullbright(v) end)
addSimpleToggle(camForm, "No Fog", "No Fog", "ลบหมอก", function(v)
    if v then noFog:Start() else noFog:Stop() end end)

-- ─── TAB: MOVEMENT ───
local moveForm = movementTab:PageSection({ Title = "Movement", Subtitle = "การเคลื่อนที่" }):Form()
addSimpleToggle(moveForm, "NoClip", "No Clip", "ทะลุกำแพง", function(v)
    if v then noClip:Start() else noClip:Stop() end end)
addSimpleToggle(moveForm, "Infinity Jump", "Infinity Jump", "กด SPACE กระโดดกลางอากาศ", function(v)
    infinityJump.Enabled = v end)
addSliderWithValue(moveForm, {
    SearchIndex = "Jump Force", Title = "Jump Force", Subtitle = "แรงกระโดด",
    Min = 10, Max = 100, Default = 50,
    OnChanged = function(v) infinityJump.JumpForce = v end })
addSimpleToggle(moveForm, "Walk Speed", "Enable WalkSpeed", "ความเร็วเดิน", function(v)
    if v then walkSpeed:Start() else walkSpeed:Stop() end end)
addSliderWithValue(moveForm, {
    SearchIndex = "Walk Speed Value", Title = "Walk Speed Value",
    Subtitle = "ความเร็วเดิน", Min = 1, Max = 500, Default = 16,
    OnChanged = function(v) walkSpeed:SetSpeed(v) end })
addSimpleToggle(moveForm, "Run Speed", "Enable RunSpeed", "ความเร็ววิ่ง", function(v)
    if v then runSpeed:Start() else runSpeed:Stop() end end)
addSliderWithValue(moveForm, {
    SearchIndex = "Run Speed Value", Title = "Run Speed Value",
    Subtitle = "ความเร็ววิ่ง", Min = 1, Max = 500, Default = 24,
    OnChanged = function(v) runSpeed:SetSpeed(v) end })
addSimpleToggle(moveForm, "Fly", "Fly (บิน)", "บินล่อด้านบน W/A/S/D + SPACE/SHIFT", function(v)
    if v then fly:Start() else fly:Stop() end end)
addSliderWithValue(moveForm, {
    SearchIndex = "Fly Speed", Title = "Fly Speed", Subtitle = "ความเร็วบิน",
    Min = 20, Max = 300, Default = 60,
    OnChanged = function(v) fly.Speed = v end })

-- ─── TAB: MANUAL ───
local manForm = manualTab:PageSection({ Title = "Manual Mode", Subtitle = "โหมดเล่นมือ" }):Form()
addSimpleToggle(manForm, "Auto SkillCheck", "Auto Skill Check", "ตอบ Skillcheck เป๊ะ (สีเขียว)", function(v)
    if v then manualSkillCheck:Start() else manualSkillCheck:Stop() end end)
addSimpleToggle(manForm, "Auto TP Elevator", "Auto TP to Elevator", "TP ไปลิฟต์อัตโนมัติ", function(v)
    if v then manualElevator:Start() else manualElevator:Stop() end end)

-- ─── TAB: SETTINGS ───
local credForm = settingsTab:PageSection({ Title = "Credits", Subtitle = "ผู้พัฒนา" }):Form()
do local r = credForm:Row({ SearchIndex = "Credits" })
    r:Left():TitleStack({ Title = "999ms HUB v4", Subtitle = "All-in-One · by 09ms" })
end

-- ============================================================
-- ROOM CHANGE HANDLER
-- ============================================================
local function onRoomChanged()
    autoFarm._lastTP = 0
    table.clear(autoFarm._statsCache)
    if generatorESP.Enabled then generatorESP:ClearAll(); generatorESP:ConnectFolder(); generatorESP:Scan() end
    if monsterESP.Enabled   then monsterESP:ClearAll();   monsterESP:ConnectFolder();   monsterESP:Scan() end
    if itemESP.Enabled      then itemESP:ClearAll();      itemESP:ConnectFolder();      itemESP:Scan() end
end

do
    local room = workspace:FindFirstChild("CurrentRoom")
    if room then
        room.ChildAdded:Connect(onRoomChanged)
        room.ChildRemoved:Connect(onRoomChanged)
    end
end

task.spawn(function()
    while task.wait(2) do
        if generatorESP.Enabled then generatorESP:ConnectFolder(); generatorESP:Scan() end
        if monsterESP.Enabled   then monsterESP:ConnectFolder();   monsterESP:Scan() end
        if itemESP.Enabled      then itemESP:ConnectFolder();      itemESP:Scan() end
    end
end)

-- ============================================================
-- READY NOTIFICATION
-- ============================================================
app:Notification({
    App = "999ms HUB",
    Title = "All-in-One v4 Loaded",
    Subtitle = "Auto Farm · Events · ESP · Movement",
    Icon = cascade.Symbols.checkmark,
    Duration = 5,
})