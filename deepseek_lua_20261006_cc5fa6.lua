--[[
    █████╗  █████╗  █████╗ ███╗   ███╗███████╗
    ██╔══██╗██╔══██╗██╔══██╗████╗ ████║██╔════╝
    ███████║╚██████║╚██████║██╔████╔██║███████╗
    ██╔══██║ ╚═══██║ ╚═══██║██║╚██╔╝██║╚════██║
    ██║  ██║ █████╔╝ █████╔╝██║ ╚═╝ ██║███████║
    ╚═╝  ╚═╝ ╚════╝  ╚════╝ ╚═╝     ╚═╝╚══════╝
              999Ms HUB  v2.8
       BY. 009exe | Dandys World
    Parabola TP + SmoothTween + Wall Hide + Clamp UI
]]

-- ============================================================
-- [ 999MS HUB ] AC BYPASS v2
-- ============================================================
local __bypassOk, __bypassErr = pcall(function()
    local __mt       = getrawmetatable(game)
    local __old      = __mt.__namecall
    local __lastFire = 0
    local __minGap   = 0.05

    setreadonly(__mt, false)
    __mt.__namecall = newcclosure(function(__self, ...)
        local __method = getnamecallmethod()
        if __method == "FireServer" and typeof(__self) == "Instance" then
            local __name = __self.Name:lower()
            if __name:find("anticheat") or __name:find("trigger")
               or __name:find("ban") or __name:find("kick") then
                return nil
            end
            local __now = tick()
            if __now - __lastFire < __minGap then return nil end
            __lastFire = __now
        end
        return __old(__self, ...)
    end)
    setreadonly(__mt, true)
end)

if __bypassOk then
    print("[ 999ms ] AC Bypass succeed")
else
    print("[ 999ms ] AC Bypass failed: " .. tostring(__bypassErr))
end

-- ============================================================
-- SERVICES
-- ============================================================
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService        = game:GetService("RunService")
local lighting          = game:GetService("Lighting")
local players           = game:GetService("Players")
local userInputService  = game:GetService("UserInputService")
local tweenService      = game:GetService("TweenService")
local localPlayer       = players.LocalPlayer

-- ============================================================
-- 🔍 CHARACTER HELPER
-- ============================================================
local function getCharacter()
    local char = localPlayer.Character
    if char and char.Parent then return char end

    local inGame = workspace:FindFirstChild("InGamePlayers")
    if inGame then
        local found = inGame:FindFirstChild(localPlayer.Name)
        if found and found:IsA("Model") then return found end
        for _, obj in pairs(inGame:GetChildren()) do
            if obj:IsA("Model") and obj:GetAttribute("UserId") == localPlayer.UserId then
                return obj
            end
        end
    end

    local p = players:FindFirstChild(localPlayer.Name)
    if p and p.Character then return p.Character end

    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name == localPlayer.Name then
            if obj:FindFirstChildOfClass("Humanoid") then return obj end
        end
    end
    return nil
end

local function getHRP()
    local char = getCharacter()
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end

local function getHumanoid()
    local char = getCharacter()
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

-- ============================================================
-- ✅ CoreGui
-- ============================================================
local coreGui
pcall(function()
    coreGui = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not coreGui then coreGui = game:GetService("CoreGui") end

-- ============================================================
-- 📏 ขนาด UI ตามอุปกรณ์ + Clamp
-- ============================================================
local IS_MOBILE = userInputService.TouchEnabled and not userInputService.KeyboardEnabled

local function getWindowSize()
    local size
    if IS_MOBILE then
        local vp = workspace.CurrentCamera.ViewportSize
        size = Vector2.new(math.floor(vp.X * 0.92), math.floor(vp.Y * 0.72))
    else
        size = Vector2.new(560, 380)
    end

    local minS = IS_MOBILE and Vector2.new(300, 280) or Vector2.new(480, 320)
    local maxS = IS_MOBILE and Vector2.new(600, 550) or Vector2.new(720, 520)

    size = Vector2.new(
        math.clamp(size.X, minS.X, maxS.X),
        math.clamp(size.Y, minS.Y, maxS.Y)
    )
    return UDim2.fromOffset(size.X, size.Y)
end

local WIN_SIZE     = getWindowSize()
local WIN_MIN_SIZE = IS_MOBILE and Vector2.new(300, 280) or Vector2.new(480, 320)
local WIN_MAX_SIZE = IS_MOBILE and Vector2.new(600, 550) or Vector2.new(720, 520)

-- ============================================================
-- โหลด Cascade UI
-- ============================================================
local function importRelease(owner, repo, version, file)
    local tag = (version == "latest" and "latest/download" or "download/" .. version)
    local url = ("https://github.com/%s/%s/releases/%s/%s"):format(owner, repo, tag, file)
    return loadstring(game:HttpGetAsync(url), file)()
end

local cascade
do
    local ok, result = pcall(function()
        return importRelease("cascadeui", "Cascade", "latest", "dist.luau")
    end)
    if not ok or not result then
        warn("[999ms HUB] Failed to load Cascade:", result)
        return
    end
    cascade = result
end

local app = cascade.New({
    Theme      = cascade.Themes.Dark,
    Accent     = cascade.Accents.Purple,
    WindowPill = true,
})

local window = app:Window({
    Title       = "999Ms HUB",
    Subtitle    = "by 09ms | v2.8",
    Size        = WIN_SIZE,
    MinSize     = WIN_MIN_SIZE,
    MaxSize     = WIN_MAX_SIZE,
    Position    = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Draggable   = true,
    Resizable   = true,
    Dropshadow  = true,
    UIBlur      = false,
    Searching   = true,
    CanExit     = true,
    CanMinimize = true,
    CanZoom     = true,
})

-- ============================================================
-- Tabs
-- ============================================================
local mainSection = window:Section({ Title = "Menu", Disclosure = true, Expanded = true })

local autoFarmTab = mainSection:Tab({ Title = "Farm",   Icon = "cpu",       Selected = true })
local visualsTab  = mainSection:Tab({ Title = "Visual", Icon = "eye" })
local movementTab = mainSection:Tab({ Title = "Move",   Icon = "arrow-up" })
local settingsTab = mainSection:Tab({ Title = "Setup",  Icon = "settings" })

-- ============================================================
-- Helper: Slider + แสดงตัวเลข
-- ============================================================
local function addSliderWithValue(form, opts)
    local row = form:Row({ SearchIndex = opts.SearchIndex })
    local titleStack = row:Left():TitleStack({
        Title = opts.Title,
        Subtitle = opts.Subtitle,
    })

    local function formatValue(v)
        if opts.Integer ~= false then v = math.floor(v) end
        return tostring(v) .. (opts.Suffix and (" " .. opts.Suffix) or "")
    end

    titleStack.Subtitle = (opts.Subtitle and (opts.Subtitle .. " • ") or "") .. formatValue(opts.Default)

    local slider = row:Right():Slider({
        Minimum = opts.Min,
        Maximum = opts.Max,
        Value = opts.Default,
        ValueChanged = function(_, value)
            titleStack.Subtitle = (opts.Subtitle and (opts.Subtitle .. " • ") or "") .. formatValue(value)
            if opts.OnChanged then
                opts.OnChanged(opts.Integer ~= false and math.floor(value) or value)
            end
        end,
    })
    return slider
end

-- ============================================================
-- 🚀 SMOOTH TWEEN (BodyVelocity) + AUTO NOCLIP
-- ============================================================
local smoothTween = {}
smoothTween.Active          = false
smoothTween.Connection      = nil
smoothTween.BodyVelocity    = nil
smoothTween.OriginalCollide = {}

function smoothTween:GetSpeed()
    local humanoid = getHumanoid()
    if humanoid and humanoid.WalkSpeed > 0 then return humanoid.WalkSpeed end
    return 16
end

function smoothTween:Stop(restoreCollide)
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    if self.BodyVelocity then
        pcall(function() self.BodyVelocity:Destroy() end)
        self.BodyVelocity = nil
    end

    local character = getCharacter()
    if character and restoreCollide ~= false then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                local orig = self.OriginalCollide[part]
                part.CanCollide = (orig == nil) and true or orig
            end
        end
    end
    self.OriginalCollide = {}
    self.Active = false
end

function smoothTween:Go(targetPosition, speedOverride, timeout)
    local character = getCharacter()
    if not character then return false end
    local rootPart = getHRP()
    if not rootPart then return false end

    self:Stop(true)
    timeout = timeout or 20
    self.Active = true
    local speed = speedOverride or self:GetSpeed()

    self.OriginalCollide = {}
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            self.OriginalCollide[part] = part.CanCollide
            part.CanCollide = false
        end
    end

    local old = rootPart:FindFirstChild("SmoothBodyVelocity")
    if old then old:Destroy() end

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "SmoothBodyVelocity"
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.P = 10000
    bodyVelocity.Parent = rootPart
    self.BodyVelocity = bodyVelocity

    local startTime = tick()
    self.Connection = runService.Heartbeat:Connect(function()
        if not self.Active then return end
        local rp = getHRP()
        if not rp or not rp.Parent then self:Stop() return end
        if tick() - startTime > timeout then self:Stop() return end

        local offset   = targetPosition - rp.Position
        local distance = offset.Magnitude
        if distance <= 2 then
            bodyVelocity.Velocity = Vector3.zero
            self:Stop()
            return
        end
        bodyVelocity.Velocity = offset.Unit * math.min(speed, distance * 10)
    end)

    while self.Active do task.wait(0.05) end
    return true
end

localPlayer.CharacterRemoving:Connect(function() smoothTween:Stop() end)

-- ============================================================
-- 🌀 PARABOLIC TELEPORT (6 จังหวะ)
-- ============================================================
local TP = {}
TP.Stats = { Success = 0, Failed = 0 }

TP.CFG = {
    Steps     = 6,       -- จำนวนจังหวะ
    ArcHeight = 18,      -- ความสูงสูงสุด (studs)
    ArcDepth  = 12,      -- ถอยหลังไกลสุด (studs)
    Delay     = 0.15,    -- รอระหว่างจังหวะ
    FinalWait = 0.10,    -- รอหลังจังหวะสุดท้าย
}

function TP.Parabola(targetCFrame)
    if not targetCFrame then return false end

    local character = getCharacter()
    if not character or not character.PrimaryPart then return false end

    local steps     = TP.CFG.Steps
    local arcHeight = TP.CFG.ArcHeight
    local arcDepth  = TP.CFG.ArcDepth

    for i = 1, steps do
        local t = i / steps

        -- ① Y: parabola ขึ้น-ลง
        local arcT = 4 * t * (1 - t)
        local yOffset = arcT * arcHeight

        -- ② Z: sin ถอยหลังแล้วเข้าหา
        local zOffset = math.sin(math.pi * t) * arcDepth

        -- ③ รวม offset
        local offsetCFrame = CFrame.new(0, yOffset, zOffset)
        local stepCFrame   = targetCFrame * offsetCFrame

        pcall(function()
            character:PivotTo(stepCFrame)
        end)

        if i < steps then
            task.wait(TP.CFG.Delay)
        end
    end

    -- Snap ครั้งสุดท้าย
    task.wait(TP.CFG.FinalWait)
    pcall(function()
        character:PivotTo(targetCFrame)
    end)

    TP.Stats.Success += 1
    return true
end

-- Compatible
function TP.Direct(targetCFrame, tolerance)
    return TP.Parabola(targetCFrame)
end

-- NetworkOwner
local function applyNetworkOwner(character)
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    if hrp then pcall(function() hrp:SetNetworkOwner(localPlayer) end) end
end
if localPlayer.Character then applyNetworkOwner(localPlayer.Character) end
localPlayer.CharacterAdded:Connect(applyNetworkOwner)

-- ============================================================
-- 🏃 WALL-HIDE ESCAPE
-- ============================================================
local WallHide = {}
WallHide.Enabled      = false
WallHide.SearchRadius = 80
WallHide.HideDepth    = 4
WallHide.LastHide     = 0
WallHide.Cooldown     = 1.5
WallHide.CurrentSpot  = nil

function WallHide:FindWall(originPos)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local char = getCharacter()
    params.FilterDescendantsInstances = char and { char } or {}

    local best, bestDist = nil, math.huge
    local directions = {
        Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
        Vector3.new(1, 0, 1).Unit,  Vector3.new(-1, 0, 1).Unit,
        Vector3.new(1, 0, -1).Unit, Vector3.new(-1, 0, -1).Unit,
    }

    for _, dir in ipairs(directions) do
        local result = workspace:Raycast(originPos, dir * self.SearchRadius, params)
        if result and result.Instance then
            local part = result.Instance
            local size = part.Size
            local isWall = part:IsA("BasePart") and size.Y > 4 and math.min(size.X, size.Z) < size.Y
            if isWall and result.Distance < bestDist then
                bestDist = result.Distance
                best = { part = part, position = result.Position, normal = result.Normal, distance = result.Distance }
            end
        end
    end
    return best
end

function WallHide:Escape(monsterPos)
    if not self.Enabled then return false end
    if tick() - self.LastHide < self.Cooldown then return false end

    local hrp = getHRP()
    if not hrp then return false end
    local wall = self:FindWall(hrp.Position)
    if not wall then return false end

    local hidePos = wall.position - wall.normal * self.HideDepth
    self.LastHide = tick()
    self.CurrentSpot = hidePos
    smoothTween:Go(hidePos, nil, 8)
    return true
end

-- ============================================================
-- AUTO FARM
-- ============================================================
local autoFarm = {}
autoFarm.Enabled           = false
autoFarm.AutoInteract      = true
autoFarm.AutoMove          = true
autoFarm.AutoElevator      = true
autoFarm.UseSafeZone       = true
autoFarm.SafeDistance      = 45
autoFarm.CachedGenerators  = {}
autoFarm.SafeZone          = nil
autoFarm.Busy              = false
autoFarm.WallHideOnDanger  = true

autoFarm.InteractRetryMax    = 12
autoFarm.InteractRetryDelay  = 0.2
autoFarm.InteractConfirmWait = 0.35
autoFarm.LastInteractTime    = 0
autoFarm.InteractCooldown    = 0.4
autoFarm.CurrentTarget       = nil

function autoFarm:Init()
    local events = replicatedStorage:WaitForChild("Events")
    events:WaitForChild("SkillcheckUpdate").OnClientInvoke = function(minigame, ...)
        if minigame then
            if minigame:GetAttribute("MinigameType") == "Circle" then
                return { hit = true, circle = "great" }
            end
            return "supercomplete"
        end
        return "supercomplete"
    end

    self.SafeZone = workspace:FindFirstChild("AutoGenSafeZone")
    if not self.SafeZone then
        self.SafeZone = Instance.new("Part")
        self.SafeZone.Name = "AutoGenSafeZone"
        self.SafeZone.Size = Vector3.new(50, 1, 50)
        self.SafeZone.Anchored = true
        self.SafeZone.Transparency = 1
        self.SafeZone.CanCollide = true
        self.SafeZone.Parent = workspace
    end

    local function cacheGenerator(obj)
        if obj:IsA("Model") and obj:GetAttribute("MinigameType") then
            self.CachedGenerators[obj] = true
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do cacheGenerator(obj) end
    workspace.DescendantAdded:Connect(cacheGenerator)
    workspace.DescendantRemoving:Connect(function(obj) self.CachedGenerators[obj] = nil end)

    task.spawn(function()
        while task.wait(0.15) do
            if self.Enabled and not self.Busy then self:Step() end
        end
    end)

    task.spawn(function()
        while task.wait(0.2) do
            if self.Enabled then self:TryInteract() end
        end
    end)

    task.spawn(function()
        while task.wait(0.2) do
            if self.Enabled and self.WallHideOnDanger and WallHide.Enabled then
                local hrp = getHRP()
                if hrp then
                    local dist = self:GetNearestMonsterDistance(hrp.Position)
                    if dist < self.SafeDistance then
                        self.CurrentTarget = nil
                        local info  = workspace:FindFirstChild("Info")
                        local panic = info and info:FindFirstChild("Panic") and info.Panic.Value == true
                        if not panic then WallHide:Escape(hrp.Position) end
                    end
                end
            end
        end
    end)
end

function autoFarm:GetNearestMonsterDistance(pos)
    local currentRoom = workspace:FindFirstChild("CurrentRoom")
    if not currentRoom then return math.huge end
    local map
    for _, obj in pairs(currentRoom:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Folder") then map = obj break end
    end
    if not map then return math.huge end
    local monsters = map:FindFirstChild("Monsters")
    if not monsters then return math.huge end
    local nearest = math.huge
    for _, monster in pairs(monsters:GetChildren()) do
        if monster:IsA("Model") then
            local bp = monster.PrimaryPart or monster:FindFirstChildWhichIsA("BasePart")
            if bp then
                local d = (bp.Position - pos).Magnitude
                if d < nearest then nearest = d end
            end
        end
    end
    return nearest
end

function autoFarm:GetGeneratorTargetCFrame(gen)
    local prompt = gen:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
        return CFrame.new(prompt.Parent.Position) * CFrame.new(0, 0, 2)
    end
    local tpGroup = gen:FindFirstChild("TeleportPositions") or gen:FindFirstChild("TreadmillTeleportPositions")
    if tpGroup and #tpGroup:GetChildren() > 0 then return tpGroup:GetChildren()[1].CFrame end
    local single = gen:FindFirstChild("TeleportPosition") or gen:FindFirstChild("TreadmillTeleportPosition")
    if single then return single.CFrame end
    local pos = gen.PrimaryPart and gen.PrimaryPart.Position or gen:GetPivot().Position
    return CFrame.new(pos) * CFrame.new(0, 0, 4)
end

function autoFarm:GetInteractStatus(generator, character)
    if not generator or not generator.Parent then return "invalid" end
    local stats = generator:FindFirstChild("Stats")
    if not stats then return "invalid" end
    local completed    = stats:FindFirstChild("Completed")
    local activePlayer = stats:FindFirstChild("ActivePlayer")
    if not completed or not activePlayer then return "invalid" end
    if completed.Value then return "done" end
    if activePlayer.Value == character then return "active" end
    if activePlayer.Value ~= nil then return "taken" end
    return "free"
end

function autoFarm:GetPromptInfo(generator)
    local prompt = generator:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt or not prompt.Enabled then return nil end
    local part = prompt.Parent
    local pos = part and part:IsA("BasePart") and part.Position or generator:GetPivot().Position
    return prompt, pos, prompt.MaxActivationDistance
end

function autoFarm:TryInteract()
    if not self.AutoInteract then return end
    if self.CurrentTarget then return end
    if tick() - self.LastInteractTime < self.InteractCooldown then return end

    local character = getCharacter()
    local hrp = getHRP()
    if not hrp then return end

    local target, bestDist = nil, math.huge
    for generator in pairs(self.CachedGenerators) do
        if generator:IsDescendantOf(workspace) then
            local status = self:GetInteractStatus(generator, character)
            if status == "active" then
                self.CurrentTarget = generator
                task.spawn(function()
                    while self.CurrentTarget == generator do
                        task.wait(0.3)
                        local s = self:GetInteractStatus(generator, getCharacter())
                        if s ~= "active" then self.CurrentTarget = nil break end
                    end
                end)
                return
            elseif status == "free" then
                local genPos = generator.PrimaryPart and generator.PrimaryPart.Position
                    or generator:GetPivot().Position
                if self:GetNearestMonsterDistance(genPos) >= self.SafeDistance then
                    local d = (genPos - hrp.Position).Magnitude
                    if d < bestDist then target = generator bestDist = d end
                end
            end
        end
    end

    if not target then return end
    self.CurrentTarget = target

    task.spawn(function()
        for attempt = 1, self.InteractRetryMax do
            local char2 = getCharacter()
            local hrp2 = getHRP()
            if not hrp2 then
                self.CurrentTarget = nil
                smoothTween:Stop()
                return
            end

            local status = self:GetInteractStatus(target, char2)
            if status == "active" or status == "done" or status == "taken" or status == "invalid" then
                self.CurrentTarget = nil
                smoothTween:Stop()
                return
            end

            if self:GetNearestMonsterDistance(hrp2.Position) < self.SafeDistance then
                self.CurrentTarget = nil
                smoothTween:Stop()
                return
            end

            local prompt, promptPos, maxDist = self:GetPromptInfo(target)
            if not prompt then task.wait(0.15) continue end

            local dist = (promptPos - hrp2.Position).Magnitude
            if dist > math.min(maxDist * 0.7, 5) then
                local targetCF = CFrame.new(promptPos) * CFrame.new(0, 0, 2)
                smoothTween:Go(targetCF.Position, nil, 15)
                task.wait(0.05)
            end

            local hrp3 = getHRP()
            if hrp3 then
                pcall(function()
                    hrp3.AssemblyLinearVelocity  = Vector3.zero
                    hrp3.AssemblyAngularVelocity = Vector3.zero
                end)
            end

            fireproximityprompt(prompt)
            self.LastInteractTime = tick()

            local confirmed = false
            local waitEnd = tick() + self.InteractConfirmWait
            while tick() < waitEnd do
                task.wait(0.05)
                local s = self:GetInteractStatus(target, getCharacter())
                if s == "active" or s == "done" then confirmed = true break end
                if s == "taken" or s == "invalid" then
                    self.CurrentTarget = nil
                    smoothTween:Stop()
                    return
                end
            end

            if confirmed then
                self.CurrentTarget = nil
                smoothTween:Stop()
                return
            end

            task.wait(self.InteractRetryDelay)
        end

        self.CurrentTarget = nil
        smoothTween:Stop()
    end)
end

function autoFarm:Step()
    if self.Busy then return end

    local character = getCharacter()
    local hrp = getHRP()
    if not hrp then return end

    local info  = workspace:FindFirstChild("Info")
    local panic = info and info:FindFirstChild("Panic") and info.Panic.Value == true
    local monsterNear = self:GetNearestMonsterDistance(hrp.Position) < self.SafeDistance

    if monsterNear or panic then smoothTween:Stop() end

    local totalGens, unfinishedGens = 0, 0
    local isInteracting, statsRef, bestGenerator = false, nil, nil
    local bestDistance = math.huge

    for generator in pairs(self.CachedGenerators) do
        if not generator:IsDescendantOf(workspace) then
            self.CachedGenerators[generator] = nil
        else
            totalGens += 1
            local stats = generator:FindFirstChild("Stats")
            if stats then
                local completed    = stats:FindFirstChild("Completed")
                local activePlayer = stats:FindFirstChild("ActivePlayer")

                if activePlayer and activePlayer.Value == character then
                    isInteracting = true
                    statsRef = stats
                end

                if completed and not completed.Value then
                    unfinishedGens += 1
                    if activePlayer and activePlayer.Value == nil then
                        if generator ~= self.CurrentTarget then
                            local genPos = generator.PrimaryPart and generator.PrimaryPart.Position
                                or generator:GetPivot().Position
                            if self:GetNearestMonsterDistance(genPos) >= self.SafeDistance then
                                local d = (genPos - hrp.Position).Magnitude
                                if d < bestDistance then
                                    bestGenerator = generator
                                    bestDistance = d
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if isInteracting and (monsterNear or panic) then
        local stopRemote = statsRef:FindFirstChild("StopInteracting")
        if stopRemote and stopRemote:IsA("RemoteEvent") then stopRemote:FireServer() end
        isInteracting = false
    end

    if self.AutoElevator and (panic or (totalGens > 0 and unfinishedGens == 0)) then
        local elevators = workspace:FindFirstChild("Elevators")
        local elevator  = elevators and elevators:FindFirstChild("Elevator")
        if elevator then
            local pivot = elevator.PrimaryPart and elevator.PrimaryPart.CFrame or elevator:GetPivot()
            if (hrp.Position - pivot.Position).Magnitude > 8 then
                self.Busy = true
                smoothTween:Stop()
                TP.Parabola(pivot * CFrame.new(0, 3, 0))   -- 🌀 Parabola
                self.Busy = false
            end
        end
        return
    elseif totalGens == 0 then
        return
    end

    if not isInteracting and self.AutoMove then
        if bestGenerator then
            local target = self:GetGeneratorTargetCFrame(bestGenerator)
            if (target.Position - hrp.Position).Magnitude > 5 then
                self.Busy = true
                smoothTween:Go(target.Position, nil, 20)
                self.Busy = false
            end
        else
            if self.UseSafeZone and not WallHide.Enabled then
                local basePos = hrp.Position
                local anyGen = next(self.CachedGenerators)
                if anyGen then
                    basePos = anyGen.PrimaryPart and anyGen.PrimaryPart.Position
                        or anyGen:GetPivot().Position
                end
                self.SafeZone.Position = Vector3.new(basePos.X, basePos.Y + 50, basePos.Z)
                if math.abs(hrp.Position.Y - self.SafeZone.Position.Y) > 10 then
                    self.Busy = true
                    smoothTween:Stop()
                    TP.Parabola(self.SafeZone.CFrame * CFrame.new(0, 3, 0))   -- 🌀 Parabola
                    self.Busy = false
                end
            end
        end
    end
end
autoFarm:Init()

-- ============================================================
-- GENERATOR ESP
-- ============================================================
local generatorESP = {}
generatorESP.Enabled       = false
generatorESP.Color         = Color3.fromRGB(0, 255, 0)
generatorESP.Objects       = {}
generatorESP.CurrentFolder = nil
generatorESP.Connections   = {}

function generatorESP:GetCurrentMap()
    local room = workspace:FindFirstChild("CurrentRoom")
    if not room then return nil end
    for _, obj in pairs(room:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Folder") then return obj end
    end
end
function generatorESP:GetGeneratorsFolder()
    local map = self:GetCurrentMap()
    return map and map:FindFirstChild("Generators")
end
function generatorESP:AddESP(target)
    if not self.Enabled or self.Objects[target] then return end
    local h = Instance.new("Highlight")
    h.Adornee = target
    h.FillColor = self.Color
    h.FillTransparency = 0.5
    h.OutlineColor = self.Color
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = coreGui
    self.Objects[target] = h
end
function generatorESP:RemoveESP(target)
    if self.Objects[target] then self.Objects[target]:Destroy() self.Objects[target] = nil end
end
function generatorESP:ClearAll() for o in pairs(self.Objects) do self:RemoveESP(o) end end
function generatorESP:Scan()
    if not self.Enabled then return end
    local folder = self:GetGeneratorsFolder()
    if not folder then self:ClearAll() return end
    for _, child in pairs(folder:GetChildren()) do
        if child:IsA("Model") or child:IsA("BasePart") then self:AddESP(child) end
    end
    for obj in pairs(self.Objects) do
        if not obj.Parent or obj.Parent ~= folder then self:RemoveESP(obj) end
    end
end
function generatorESP:ConnectFolder()
    local folder = self:GetGeneratorsFolder()
    if folder == self.CurrentFolder then return end
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = folder
    if not folder then return end
    self.Connections.ChildAdded = folder.ChildAdded:Connect(function(child)
        if (child:IsA("Model") or child:IsA("BasePart")) and self.Enabled then
            task.wait(0.1) self:AddESP(child)
        end
    end)
    self.Connections.ChildRemoved = folder.ChildRemoved:Connect(function(child) self:RemoveESP(child) end)
end
function generatorESP:Start() self.Enabled = true self:ConnectFolder() self:Scan() end
function generatorESP:Stop()
    self.Enabled = false self:ClearAll()
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end

-- ============================================================
-- MONSTER ESP
-- ============================================================
local monsterESP = {}
monsterESP.Enabled       = false
monsterESP.Color         = Color3.fromRGB(255, 0, 0)
monsterESP.Objects       = {}
monsterESP.CurrentFolder = nil
monsterESP.Connections   = {}

function monsterESP:CleanName(name)
    if name:sub(-7) == "Monster" then return name:sub(1, -8) end
    return name
end
function monsterESP:GetCurrentMap()
    local room = workspace:FindFirstChild("CurrentRoom")
    if not room then return nil end
    for _, obj in pairs(room:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Folder") then return obj end
    end
end
function monsterESP:GetMonstersFolder()
    local map = self:GetCurrentMap()
    return map and map:FindFirstChild("Monsters")
end
function monsterESP:AddESP(target)
    if not self.Enabled or self.Objects[target] then return end
    local pp = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
    if not pp then
        local conn
        conn = target.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") then conn:Disconnect() self:AddESP(target) end
        end)
        return
    end
    local h = Instance.new("Highlight")
    h.Adornee = target
    h.FillColor = self.Color
    h.FillTransparency = 0.5
    h.OutlineColor = self.Color
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = coreGui

    local bb = Instance.new("BillboardGui")
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 150, 0, 25)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.LightInfluence = 0
    bb.Adornee = pp
    bb.Parent = coreGui

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.Text = self:CleanName(target.Name)
    label.TextColor3 = self.Color
    label.TextSize = 15
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.fromRGB(80, 0, 0)
    label.Parent = bb

    self.Objects[target] = { Highlight = h, Billboard = bb }
end
function monsterESP:RemoveESP(target)
    if self.Objects[target] then
        self.Objects[target].Highlight:Destroy()
        self.Objects[target].Billboard:Destroy()
        self.Objects[target] = nil
    end
end
function monsterESP:ClearAll() for o in pairs(self.Objects) do self:RemoveESP(o) end end
function monsterESP:Scan()
    if not self.Enabled then return end
    local folder = self:GetMonstersFolder()
    if not folder then self:ClearAll() return end
    for _, child in pairs(folder:GetChildren()) do
        if child:IsA("Model") then self:AddESP(child) end
    end
    for obj in pairs(self.Objects) do
        if not obj.Parent or obj.Parent ~= folder then self:RemoveESP(obj) end
    end
end
function monsterESP:ConnectFolder()
    local folder = self:GetMonstersFolder()
    if folder == self.CurrentFolder then return end
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = folder
    if not folder then return end
    self.Connections.ChildAdded = folder.ChildAdded:Connect(function(child)
        if child:IsA("Model") and self.Enabled then task.wait(0.1) self:AddESP(child) end
    end)
    self.Connections.ChildRemoved = folder.ChildRemoved:Connect(function(child) self:RemoveESP(child) end)
end
function monsterESP:Start() self.Enabled = true self:ConnectFolder() self:Scan() end
function monsterESP:Stop()
    self.Enabled = false self:ClearAll()
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end

-- ============================================================
-- ITEM ESP
-- ============================================================
local itemESP = {}
itemESP.Enabled       = false
itemESP.Color         = Color3.fromRGB(0, 150, 255)
itemESP.HealthColor   = Color3.fromRGB(0, 255, 0)
itemESP.Objects       = {}
itemESP.CurrentFolder = nil
itemESP.Connections   = {}

function itemESP:GetCurrentMap()
    local room = workspace:FindFirstChild("CurrentRoom")
    if not room then return nil end
    for _, obj in pairs(room:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Folder") then return obj end
    end
end
function itemESP:GetItemsFolder()
    local map = self:GetCurrentMap()
    return map and map:FindFirstChild("Items")
end
function itemESP:AddESP(target)
    if not self.Enabled or self.Objects[target] then return end
    local pp = target:IsA("Model")
        and (target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart"))
        or target
    if not pp or not pp:IsA("BasePart") then
        local conn
        conn = target.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") then conn:Disconnect() self:AddESP(target) end
        end)
        return
    end
    local isHealth = (target.Name == "HealthKit" or target.Name == "Bandage")
    local color = isHealth and self.HealthColor or self.Color

    local h = Instance.new("Highlight")
    h.Adornee = target:IsA("Model") and target or pp
    h.FillColor = color
    h.FillTransparency = 0.5
    h.OutlineColor = color
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = coreGui

    local bb = Instance.new("BillboardGui")
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 150, 0, 25)
    bb.StudsOffset = Vector3.new(0, 1.5, 0)
    bb.LightInfluence = 0
    bb.Adornee = pp
    bb.Parent = coreGui

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.Text = target.Name:gsub("(%l)(%u)", "%1 %2")
    label.TextColor3 = color
    label.TextSize = 13
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = bb

    self.Objects[target] = { Highlight = h, Billboard = bb }
end
function itemESP:RemoveESP(target)
    if self.Objects[target] then
        if self.Objects[target].Highlight then self.Objects[target].Highlight:Destroy() end
        if self.Objects[target].Billboard then self.Objects[target].Billboard:Destroy() end
        self.Objects[target] = nil
    end
end
function itemESP:ClearAll() for o in pairs(self.Objects) do self:RemoveESP(o) end end
function itemESP:Scan()
    if not self.Enabled then return end
    local folder = self:GetItemsFolder()
    if not folder then self:ClearAll() return end
    for _, child in pairs(folder:GetChildren()) do
        if child:IsA("Model") or child:IsA("BasePart") then self:AddESP(child) end
    end
    for obj in pairs(self.Objects) do
        if not obj.Parent or obj.Parent ~= folder then self:RemoveESP(obj) end
    end
end
function itemESP:ConnectFolder()
    local folder = self:GetItemsFolder()
    if folder == self.CurrentFolder then return end
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = folder
    if not folder then return end
    self.Connections.ChildAdded = folder.ChildAdded:Connect(function(child)
        if (child:IsA("Model") or child:IsA("BasePart")) and self.Enabled then
            task.wait(0.1) self:AddESP(child)
        end
    end)
    self.Connections.ChildRemoved = folder.ChildRemoved:Connect(function(child) self:RemoveESP(child) end)
end
function itemESP:Start() self.Enabled = true self:ConnectFolder() self:Scan() end
function itemESP:Stop()
    self.Enabled = false self:ClearAll()
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end

-- ============================================================
-- CAMERA / LIGHTING
-- ============================================================
local cameraMod = {}
cameraMod.FOVEnabled        = false
cameraMod.FOV               = 70
cameraMod.FullbrightEnabled = false
cameraMod.LightingConns     = {}
cameraMod.OriginalLighting  = {}

function cameraMod:Init()
    runService.RenderStepped:Connect(function()
        if self.FOVEnabled then
            local cam = workspace.CurrentCamera
            if cam and cam.FieldOfView ~= self.FOV then cam.FieldOfView = self.FOV end
        end
    end)
end
function cameraMod:SetFOV(fov) self.FOV = fov end
function cameraMod:ToggleFOV(state) self.FOVEnabled = state end
function cameraMod:ToggleFullbright(state)
    self.FullbrightEnabled = state
    if state then
        self.OriginalLighting = {
            Brightness = lighting.Brightness,
            ClockTime = lighting.ClockTime,
            FogEnd = lighting.FogEnd,
            GlobalShadows = lighting.GlobalShadows,
            OutdoorAmbient = lighting.OutdoorAmbient,
        }
        local function apply()
            lighting.Brightness = 1
            lighting.ClockTime = 14
            lighting.FogEnd = 100000
            lighting.GlobalShadows = false
            lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        end
        apply()
        self.LightingConns.Brightness    = lighting:GetPropertyChangedSignal("Brightness"):Connect(apply)
        self.LightingConns.ClockTime     = lighting:GetPropertyChangedSignal("ClockTime"):Connect(apply)
        self.LightingConns.FogEnd        = lighting:GetPropertyChangedSignal("FogEnd"):Connect(apply)
        self.LightingConns.GlobalShadows = lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(apply)
        self.LightingConns.OutdoorAmbient = lighting:GetPropertyChangedSignal("OutdoorAmbient"):Connect(apply)
    else
        for _, conn in pairs(self.LightingConns) do conn:Disconnect() end
        self.LightingConns = {}
        if self.OriginalLighting.Brightness then
            lighting.Brightness = self.OriginalLighting.Brightness
            lighting.ClockTime = self.OriginalLighting.ClockTime
            lighting.FogEnd = self.OriginalLighting.FogEnd
            lighting.GlobalShadows = self.OriginalLighting.GlobalShadows
            lighting.OutdoorAmbient = self.OriginalLighting.OutdoorAmbient
        end
    end
end
cameraMod:Init()

-- ============================================================
-- INFINITY JUMP
-- ============================================================
local infinityJump = {}
infinityJump.Enabled   = false
infinityJump.JumpForce = 50
function infinityJump:Jump()
    if not self.Enabled then return end
    local hrp = getHRP()
    if not hrp then return end
    local humanoid = getHumanoid()
    if not humanoid or humanoid.Health <= 0 then return end
    hrp.Velocity = Vector3.new(hrp.Velocity.X, self.JumpForce, hrp.Velocity.Z)
end
userInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Space then infinityJump:Jump() end
end)

-- ============================================================
-- WALK SPEED
-- ============================================================
local walkSpeed = {}
walkSpeed.Enabled  = false
walkSpeed.Speed    = 16
walkSpeed.LoopConn = nil

local function applyWalkSpeed(value)
    local humanoid = getHumanoid()
    if humanoid then humanoid.WalkSpeed = value end
end

function walkSpeed:Start()
    self.Enabled = true
    applyWalkSpeed(self.Speed)
    if self.LoopConn then pcall(function() task.cancel(self.LoopConn) end) end
    self.LoopConn = task.spawn(function()
        while walkSpeed.Enabled do
            task.wait(0.1)
            applyWalkSpeed(walkSpeed.Speed)
        end
    end)
end
function walkSpeed:Stop()
    self.Enabled = false
    if self.LoopConn then
        pcall(function() task.cancel(self.LoopConn) end)
        self.LoopConn = nil
    end
    applyWalkSpeed(16)
end
function walkSpeed:SetSpeed(value)
    self.Speed = value
    if self.Enabled then applyWalkSpeed(value) end
end

-- ============================================================
-- UI: AUTO FARM TAB
-- ============================================================
local farmForm = autoFarmTab:PageSection({ Title = "Auto Farm", Subtitle = "ระบบฟาร์มอัตโนมัติ" }):Form()

do
    local row = farmForm:Row({ SearchIndex = "Enable Auto Farm" })
    row:Left():TitleStack({ Title = "Enable Auto Farm", Subtitle = "Toggle ทั้งหมด" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, value)
            autoFarm.Enabled = value
            if not value then
                smoothTween:Stop()
                WallHide.Enabled = false
            end
            app:Notification({
                Title = "Auto Farm",
                Subtitle = value and "Enabled" or "Disabled",
                Duration = 3,
            })
        end,
    })
end

do
    local row = farmForm:Row({ SearchIndex = "Auto Fix Generators" })
    row:Left():TitleStack({ Title = "Auto Fix Generators", Subtitle = "ซ่อมเครื่องปั่นไฟอัตโนมัติ" })
    row:Right():Toggle({ Value = true, ValueChanged = function(_, v) autoFarm.AutoInteract = v end })
end

do
    local row = farmForm:Row({ SearchIndex = "Auto Move to Generators" })
    row:Left():TitleStack({ Title = "Auto Move to Generators", Subtitle = "เดินไปเครื่องที่ดีที่สุด (SmoothTween)" })
    row:Right():Toggle({ Value = true, ValueChanged = function(_, v) autoFarm.AutoMove = v end })
end

do
    local row = farmForm:Row({ SearchIndex = "Auto Elevator" })
    row:Left():TitleStack({ Title = "Auto Elevator", Subtitle = "TP ไปลิฟต์เมื่อครบทุกเครื่อง (Parabola)" })
    row:Right():Toggle({ Value = true, ValueChanged = function(_, v) autoFarm.AutoElevator = v end })
end

do
    local row = farmForm:Row({ SearchIndex = "Wall Hide on Danger" })
    row:Left():TitleStack({ Title = "Wall Hide on Danger", Subtitle = "มอนมา → เดินเข้ากำแพงซ่อน" })
    row:Right():Toggle({
        Value = true,
        ValueChanged = function(_, v)
            autoFarm.WallHideOnDanger = v
            WallHide.Enabled = v
        end,
    })
end

-- ============================================================
-- UI: AUTO FARM - SAFETY
-- ============================================================
local safetyForm = autoFarmTab:PageSection({ Title = "Safety", Subtitle = "ระบบความปลอดภัย" }):Form()

do
    local row = safetyForm:Row({ SearchIndex = "Auto Save from Monsters" })
    row:Left():TitleStack({ Title = "Auto Save from Monsters", Subtitle = "เปิดระบบหลบมอน (Parabola)" })
    row:Right():Toggle({ Value = true, ValueChanged = function(_, v) autoFarm.UseSafeZone = v end })
end

addSliderWithValue(safetyForm, {
    SearchIndex = "Safe Distance",
    Title = "Safe Distance",
    Subtitle = "ระยะห่างจากมอน",
    Min = 10, Max = 150, Default = 45, Suffix = "studs",
    OnChanged = function(v) autoFarm.SafeDistance = v end,
})

addSliderWithValue(safetyForm, {
    SearchIndex = "Wall Search Radius",
    Title = "Wall Search Radius",
    Subtitle = "ระยะค้นหากำแพง",
    Min = 20, Max = 150, Default = 80, Suffix = "studs",
    OnChanged = function(v) WallHide.SearchRadius = v end,
})

addSliderWithValue(safetyForm, {
    SearchIndex = "Wall Hide Depth",
    Title = "Wall Hide Depth",
    Subtitle = "ความลึกที่ซ่อนในกำแพง",
    Min = 2, Max = 15, Default = 4, Suffix = "studs",
    OnChanged = function(v) WallHide.HideDepth = v end,
})

-- ============================================================
-- UI: PARABOLA TELEPORT SETTINGS
-- ============================================================
local parabForm = autoFarmTab:PageSection({ Title = "Parabola TP", Subtitle = "ตั้งค่า TP แบบพาราโบลา" }):Form()

addSliderWithValue(parabForm, {
    SearchIndex = "Parabola Steps",
    Title = "Steps",
    Subtitle = "จำนวนจังหวะ",
    Min = 3, Max = 12, Default = 6,
    OnChanged = function(v) TP.CFG.Steps = math.floor(v) end,
})

addSliderWithValue(parabForm, {
    SearchIndex = "Parabola Height",
    Title = "Arc Height",
    Subtitle = "ความสูงสูงสุด",
    Min = 5, Max = 80, Default = 18, Suffix = "studs",
    OnChanged = function(v) TP.CFG.ArcHeight = v end,
})

addSliderWithValue(parabForm, {
    SearchIndex = "Parabola Depth",
    Title = "Arc Depth",
    Subtitle = "ระยะถอยหลังสูงสุด",
    Min = 0, Max = 40, Default = 12, Suffix = "studs",
    OnChanged = function(v) TP.CFG.ArcDepth = v end,
})

addSliderWithValue(parabForm, {
    SearchIndex = "Parabola Delay",
    Title = "Delay",
    Subtitle = "รอระหว่างจังหวะ",
    Min = 5, Max = 50, Default = 15, Suffix = "x0.01s",
    OnChanged = function(v) TP.CFG.Delay = v / 100 end,
})

-- ============================================================
-- UI: VISUALS TAB
-- ============================================================
local genForm = visualsTab:PageSection({ Title = "Generator ESP", Subtitle = "ไฮไลต์สีเขียว" }):Form()

do
    local row = genForm:Row({ SearchIndex = "Generator ESP" })
    row:Left():TitleStack({ Title = "Generator ESP", Subtitle = "ไฮไลต์เครื่องปั่นไฟ" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v)
            if v then generatorESP:Start() else generatorESP:Stop() end
        end,
    })
end

local monForm = visualsTab:PageSection({ Title = "Monster ESP", Subtitle = "ไฮไลต์สีแดง" }):Form()

do
    local row = monForm:Row({ SearchIndex = "Monster ESP" })
    row:Left():TitleStack({ Title = "Monster ESP", Subtitle = "ไฮไลต์มอน + ชื่อ" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v)
            if v then monsterESP:Start() else monsterESP:Stop() end
        end,
    })
end

local itemForm = visualsTab:PageSection({ Title = "Item ESP", Subtitle = "ไฮไลต์ไอเทม" }):Form()

do
    local row = itemForm:Row({ SearchIndex = "Item ESP" })
    row:Left():TitleStack({ Title = "Item ESP", Subtitle = "ไฮไลต์ไอเทม + Health" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v)
            if v then itemESP:Start() else itemESP:Stop() end
        end,
    })
end

local camForm = visualsTab:PageSection({ Title = "Camera & Lighting", Subtitle = "กล้องและแสง" }):Form()

do
    local row = camForm:Row({ SearchIndex = "Enable Custom FOV" })
    row:Left():TitleStack({ Title = "Enable Custom FOV", Subtitle = "กำหนด FOV เอง" })
    row:Right():Toggle({ Value = false, ValueChanged = function(_, v) cameraMod:ToggleFOV(v) end })
end

addSliderWithValue(camForm, {
    SearchIndex = "Field Of View",
    Title = "Field Of View",
    Subtitle = "ค่า FOV",
    Min = 30, Max = 120, Default = 70, Suffix = "deg",
    OnChanged = function(v) cameraMod:SetFOV(v) end,
})

do
    local row = camForm:Row({ SearchIndex = "Fullbright" })
    row:Left():TitleStack({ Title = "Fullbright", Subtitle = "เปิดไฟสว่าง ลบหมอก" })
    row:Right():Toggle({ Value = false, ValueChanged = function(_, v) cameraMod:ToggleFullbright(v) end })
end

-- ============================================================
-- UI: MOVEMENT TAB
-- ============================================================
local jumpForm = movementTab:PageSection({ Title = "Infinity Jump", Subtitle = "กระโดดไม่จำกัด" }):Form()

do
    local row = jumpForm:Row({ SearchIndex = "Infinity Jump" })
    row:Left():TitleStack({ Title = "Infinity Jump", Subtitle = "กด SPACE กระโดดตลอด" })
    row:Right():Toggle({ Value = false, ValueChanged = function(_, v) infinityJump.Enabled = v end })
end

addSliderWithValue(jumpForm, {
    SearchIndex = "Jump Force",
    Title = "Jump Force",
    Subtitle = "แรงกระโดด",
    Min = 10, Max = 100, Default = 50,
    OnChanged = function(v) infinityJump.JumpForce = v end,
})

local wsForm = movementTab:PageSection({ Title = "Walk Speed", Subtitle = "ความเร็วเดิน (SmoothTween ใช้ค่านี้)" }):Form()

do
    local row = wsForm:Row({ SearchIndex = "WalkSpeed" })
    row:Left():TitleStack({ Title = "WalkSpeed", Subtitle = "บังคับความเร็วเดิน" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v)
            if v then walkSpeed:Start() else walkSpeed:Stop() end
        end,
    })
end

addSliderWithValue(wsForm, {
    SearchIndex = "Walk Speed Value",
    Title = "Walk Speed",
    Subtitle = "ค่าความเร็ว (SmoothTween ใช้ค่านี้)",
    Min = 1, Max = 500, Default = 100,
    OnChanged = function(v) walkSpeed:SetSpeed(v) end,
})

-- ============================================================
-- UI: SETTINGS TAB
-- ============================================================
local statsForm = settingsTab:PageSection({ Title = "Status", Subtitle = "สถานะ" }):Form()

do
    local row = statsForm:Row({ SearchIndex = "Char Status" })
    local stack = row:Left():TitleStack({
        Title = "Character Status",
        Subtitle = "checking...",
    })
    task.spawn(function()
        while task.wait(0.5) do
            local char = getCharacter()
            local hrp = getHRP()
            local hum = getHumanoid()
            stack.Subtitle = string.format(
                "Char: %s | HRP: %s | Hum: %s | WS: %s",
                char and char.Name or "nil",
                hrp and "✓" or "✗",
                hum and "✓" or "✗",
                hum and tostring(math.floor(hum.WalkSpeed)) or "-"
            )
        end
    end)
end

local creditsForm = settingsTab:PageSection({ Title = "Credits", Subtitle = "ข้อมูลผู้พัฒนา" }):Form()

do
    local row = creditsForm:Row({ SearchIndex = "Credits" })
    row:Left():TitleStack({
        Title = "999Ms HUB",
        Subtitle = "Made by 09ms | v2.8 Parabola Edition",
    })
end

do
    local row = creditsForm:Row({ SearchIndex = "Bypass Status" })
    row:Left():TitleStack({ Title = "AC Bypass" })
    row:Right():Label({ Text = __bypassOk and "ACTIVE" or "INACTIVE" })
end

-- ============================================================
-- ESP ANIMATE
-- ============================================================
runService.RenderStepped:Connect(function()
    local pulse = math.abs(math.sin(tick() * 2))

    if generatorESP.Enabled then
        for target, h in pairs(generatorESP.Objects) do
            if target and target.Parent and h and h.Parent then
                local r, g, b = generatorESP.Color.R, generatorESP.Color.G, generatorESP.Color.B
                h.FillTransparency = 0.4 + pulse * 0.4
                h.OutlineColor = Color3.new(
                    math.clamp(r + pulse * 0.2, 0, 1),
                    math.clamp(g + pulse * 0.2, 0, 1),
                    math.clamp(b + pulse * 0.2, 0, 1)
                )
            end
        end
    end

    if monsterESP.Enabled then
        for target, data in pairs(monsterESP.Objects) do
            if target and target.Parent and data then
                local pp = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
                if pp and data.Billboard and data.Billboard.Adornee ~= pp then
                    data.Billboard.Adornee = pp
                end
                if data.Highlight and data.Highlight.Parent then
                    local r, g, b = monsterESP.Color.R, monsterESP.Color.G, monsterESP.Color.B
                    data.Highlight.FillTransparency = 0.4 + pulse * 0.4
                    data.Highlight.OutlineColor = Color3.new(
                        math.clamp(r + pulse * 0.2, 0, 1),
                        math.clamp(g + pulse * 0.2, 0, 1),
                        math.clamp(b + pulse * 0.2, 0, 1)
                    )
                end
            end
        end
    end

    if itemESP.Enabled then
        for target, data in pairs(itemESP.Objects) do
            if target and target.Parent and data then
                local pp = target:IsA("Model")
                    and (target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart"))
                    or target
                if pp and data.Billboard and data.Billboard.Adornee ~= pp then
                    data.Billboard.Adornee = pp
                end
                if data.Highlight and data.Highlight.Parent then
                    local isHealth = (target.Name == "HealthKit" or target.Name == "Bandage")
                    local color = isHealth and itemESP.HealthColor or itemESP.Color
                    local r, g, b = color.R, color.G, color.B
                    data.Highlight.FillTransparency = 0.4 + pulse * 0.4
                    data.Highlight.OutlineColor = Color3.new(
                        math.clamp(r + pulse * 0.2, 0, 1),
                        math.clamp(g + pulse * 0.2, 0, 1),
                        math.clamp(b + pulse * 0.2, 0, 1)
                    )
                end
            end
        end
    end
end)

-- ============================================================
-- ROOM CHANGE HANDLERS
-- ============================================================
local currentRoom = workspace:FindFirstChild("CurrentRoom")
if currentRoom then
    currentRoom.ChildAdded:Connect(function()
        task.wait(0.5)
        if generatorESP.Enabled then generatorESP:ClearAll() generatorESP:ConnectFolder() generatorESP:Scan() end
        if monsterESP.Enabled then monsterESP:ClearAll() monsterESP:ConnectFolder() monsterESP:Scan() end
        if itemESP.Enabled then itemESP:ClearAll() itemESP:ConnectFolder() itemESP:Scan() end
    end)
    currentRoom.ChildRemoved:Connect(function()
        generatorESP:ClearAll() generatorESP.CurrentFolder = nil
        monsterESP:ClearAll() monsterESP.CurrentFolder = nil
        itemESP:ClearAll() itemESP.CurrentFolder = nil
    end)
end

task.spawn(function()
    while task.wait(2) do
        if generatorESP.Enabled then generatorESP:ConnectFolder() generatorESP:Scan() end
        if monsterESP.Enabled then monsterESP:ConnectFolder() monsterESP:Scan() end
        if itemESP.Enabled then itemESP:ConnectFolder() itemESP:Scan() end
    end
end)

-- ============================================================
-- DONE
-- ============================================================
app:Notification({
    App = "999Ms HUB",
    Title = "Loaded Successfully",
    Subtitle = "999Ms HUB v2.8 | Parabola Edition",
    Icon = cascade.Symbols.checkmark,
    Duration = 5,
})

print("[999Ms HUB] ✅ v2.8 — Parabola Edition — โหลดสำเร็จ!")
print("[999Ms HUB] 🛡️ AC Bypass: " .. (__bypassOk and "ACTIVE" or "INACTIVE"))
print("[999Ms HUB] 📏 Window Size: " .. tostring(WIN_SIZE))
print("[999Ms HUB] 🌀 TP: Parabola 6 steps | 🚀 Move: SmoothTween")