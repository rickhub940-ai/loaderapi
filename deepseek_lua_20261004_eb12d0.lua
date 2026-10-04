-- 999ms HUB | Cascade UI Edition (Corrected API + Device-based Size)
-- No Music, No TP Walk | Fixed Colors | Slider with number display
-- + Parabolic Teleport (6-step) for Auto Farm & Safe Zone

local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local lighting = game:GetService("Lighting")
local players = game:GetService("Players")
local userInputService = game:GetService("UserInputService")
local localPlayer = players.LocalPlayer

-- ============================================================
-- ✅ CoreGui
-- ============================================================
local coreGui
pcall(function()
    coreGui = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not coreGui then
    coreGui = game:GetService("CoreGui")
end

-- ============================================================
-- 📏 ขนาด UI ตามอุปกรณ์ (viewport จริง)
-- ============================================================
local IS_MOBILE = userInputService.TouchEnabled and not userInputService.KeyboardEnabled

local function getWindowSize()
    if IS_MOBILE then
        local vp = workspace.CurrentCamera.ViewportSize
        return UDim2.fromOffset(
            math.floor(vp.X * 0.92),
            math.floor(vp.Y * 0.72)
        )
    else
        return UDim2.fromOffset(560, 380)
    end
end

local WIN_SIZE      = getWindowSize()
local WIN_MIN_SIZE  = IS_MOBILE and Vector2.new(300, 280) or Vector2.new(480, 320)
local WIN_MAX_SIZE  = IS_MOBILE and Vector2.new(600, 550) or Vector2.new(720, 520)

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
    Theme = cascade.Themes.Dark,
    Accent = cascade.Accents.Blue,
    WindowPill = true,
})

local window = app:Window({
    Title = "999ms HUB",
    Subtitle = "by 09ms | Dandy World",
    Size = WIN_SIZE,
    MinSize = WIN_MIN_SIZE,
    MaxSize = WIN_MAX_SIZE,
    Draggable = true,
    Resizable = true,
    Dropshadow = true,
    UIBlur = false,
    Searching = true,
})

-- ============================================================
-- Tabs
-- ============================================================
local mainSection = window:Section({ Title = "Menu", Disclosure = true, Expanded = true })

local autoFarmTab = mainSection:Tab({ Title = "Auto Farm", Icon = cascade.Symbols.squareStack3dUp, Selected = true })
local visualsTab  = mainSection:Tab({ Title = "Visuals",   Icon = cascade.Symbols.eye })
local movementTab = mainSection:Tab({ Title = "Movement",  Icon = cascade.Symbols.arrowUpCircle })
local settingsTab = mainSection:Tab({ Title = "Settings",  Icon = cascade.Symbols.gear })

-- ============================================================
-- Helper: สร้าง Row ที่มี Slider + แสดงตัวเลข
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

    titleStack.Subtitle = (opts.Subtitle and (opts.Subtitle .. " • ") or "")
        .. formatValue(opts.Default)

    local slider = row:Right():Slider({
        Minimum = opts.Min,
        Maximum = opts.Max,
        Value = opts.Default,
        ValueChanged = function(_, value)
            titleStack.Subtitle = (opts.Subtitle and (opts.Subtitle .. " • ") or "")
                .. formatValue(value)
            if opts.OnChanged then
                opts.OnChanged(opts.Integer ~= false and math.floor(value) or value)
            end
        end,
    })

    return slider
end

-- ============================================================
-- PARABOLIC TELEPORT (6 จังหวะ)
-- ============================================================
local function teleportTo(targetCFrame, offset)
    local character = localPlayer.Character
    if not character or not character.Parent then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    character:PivotTo(targetCFrame * offset)
end

-- ปรับ delay ได้ผ่าน autoFarm.ParabolaDelay
local function parabolaTo(targetCFrame, delay)
    delay = delay or 0.15
    teleportTo(targetCFrame, CFrame.new(0, 18, 12)); task.wait(delay) -- ① ขึ้นสูง + ถอยหลัง
    teleportTo(targetCFrame, CFrame.new(0, 18, 4));  task.wait(delay) -- ② สูงเท่าเดิม เข้าใกล้
    teleportTo(targetCFrame, CFrame.new(0, 14, -2)); task.wait(delay) -- ③ ลดความสูง
    teleportTo(targetCFrame, CFrame.new(0, 8, -4));  task.wait(delay) -- ④ ครึ่งทาง
    teleportTo(targetCFrame, CFrame.new(0, 3, -2));  task.wait(delay) -- ⑤ ใกล้พื้น
    teleportTo(targetCFrame, CFrame.new(0, 0, 0));   task.wait(0.10)   -- ⑥ ลงเป้า
end

-- ============================================================
-- AUTO FARM
-- ============================================================
local autoFarm = {}
autoFarm.Enabled          = false
autoFarm.AutoInteract     = true
autoFarm.AutoTeleport     = true
autoFarm.AutoElevator     = true
autoFarm.UseSafeZone      = true
autoFarm.SafeDistance     = 45
autoFarm.CachedGenerators = {}
autoFarm.SafeZone         = nil
autoFarm.Busy             = false     -- กัน loop ซ้อนระหว่าง parabola
autoFarm.UseParabola      = true      -- ✅ เปิด/ปิด parabola
autoFarm.ParabolaDelay    = 0.15      -- ✅ ความเร็วแต่ละจังหวะ

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
        while task.wait(0.2) do
            if self.Enabled then self:Step() end
        end
    end)
end

function autoFarm:GetNearestMonsterDistance(pos)
    local currentRoom = workspace:FindFirstChild("CurrentRoom")
    if not currentRoom then return math.huge end
    local map
    for _, obj in pairs(currentRoom:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Folder") then map = obj; break end
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
    local tpGroup = gen:FindFirstChild("TeleportPositions") or gen:FindFirstChild("TreadmillTeleportPositions")
    if tpGroup and #tpGroup:GetChildren() > 0 then return tpGroup:GetChildren()[1].CFrame end
    local single = gen:FindFirstChild("TeleportPosition") or gen:FindFirstChild("TreadmillTeleportPosition")
    if single then return single.CFrame end
    local pos = gen.PrimaryPart and gen.PrimaryPart.Position or gen:GetPivot().Position
    return CFrame.new(pos) * CFrame.new(0, 0, 4)
end

function autoFarm:Step()
    if self.Busy then return end   -- กำลังวาปอยู่ → ข้าม

    local character = localPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local info  = workspace:FindFirstChild("Info")
    local panic = info and info:FindFirstChild("Panic") and info.Panic.Value == true
    local monsterNear = self:GetNearestMonsterDistance(hrp.Position) < self.SafeDistance

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
                        local genPos = generator.PrimaryPart and generator.PrimaryPart.Position
                            or generator:GetPivot().Position
                        if self:GetNearestMonsterDistance(genPos) >= self.SafeDistance then
                            local d = (genPos - hrp.Position).Magnitude
                            if d < bestDistance then
                                bestGenerator = generator
                                bestDistance  = d
                            end
                        end
                    end
                end
            end
        end
    end

    -- ⛔ หยุดซ่อมถ้ามอนใกล้หรือ Panic
    if isInteracting and (monsterNear or panic) then
        local stopRemote = statsRef:FindFirstChild("StopInteracting")
        if stopRemote and stopRemote:IsA("RemoteEvent") then stopRemote:FireServer() end
        isInteracting = false
    end

    -- 🛗 Auto Elevator (วาปตรง ไม่ต้อง parabola)
    if self.AutoElevator and (panic or (totalGens > 0 and unfinishedGens == 0)) then
        local elevators = workspace:FindFirstChild("Elevators")
        local elevator  = elevators and elevators:FindFirstChild("Elevator")
        if elevator then
            local pivot = elevator.PrimaryPart and elevator.PrimaryPart.CFrame or elevator:GetPivot()
            if (hrp.Position - pivot.Position).Magnitude > 8 then
                character:PivotTo(pivot * CFrame.new(0, 3, 0))
            end
        end
        return
    elseif totalGens == 0 then
        return
    end

    -- ✈️ วาปไป Generator หรือกลับ Safe Zone
    if not isInteracting and self.AutoTeleport then
        if bestGenerator then
            local target = self:GetGeneratorTargetCFrame(bestGenerator)
            if (target.Position - hrp.Position).Magnitude > 5 then
                self.Busy = true
                if self.UseParabola then
                    parabolaTo(target, self.ParabolaDelay)   -- 🌟 6 จังหวะ
                else
                    character:PivotTo(target)
                    task.wait(0.15)
                end
                self.Busy = false
            end
        else
            -- ไม่มี gen ว่าง → ขึ้น safe zone
            if self.UseSafeZone then
                local basePos = hrp.Position
                local anyGen = next(self.CachedGenerators)
                if anyGen then
                    basePos = anyGen.PrimaryPart and anyGen.PrimaryPart.Position
                        or anyGen:GetPivot().Position
                end
                self.SafeZone.Position = Vector3.new(basePos.X, basePos.Y + 50, basePos.Z)
                if math.abs(hrp.Position.Y - self.SafeZone.Position.Y) > 10 then
                    self.Busy = true
                    character:PivotTo(self.SafeZone.CFrame * CFrame.new(0, 3, 0))
                    task.wait(0.15)
                    self.Busy = false
                end
            end
        end
    end

    -- 🔧 Auto Interact (ซ่อม) — เฉพาะตอน "ไม่อยู่ safe zone"
    if self.AutoInteract and math.abs(hrp.Position.Y - self.SafeZone.Position.Y) > 10 then
        for generator in pairs(self.CachedGenerators) do
            local stats = generator:FindFirstChild("Stats")
            if stats then
                local completed    = stats:FindFirstChild("Completed")
                local activePlayer = stats:FindFirstChild("ActivePlayer")
                if completed and not completed.Value and activePlayer
                    and (activePlayer.Value == nil or activePlayer.Value == character) then
                    local genPos = generator.PrimaryPart and generator.PrimaryPart.Position
                        or generator:GetPivot().Position
                    local prompt = generator:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt and prompt.Enabled
                        and (genPos - hrp.Position).Magnitude <= prompt.MaxActivationDistance + 2 then
                        fireproximityprompt(prompt, 1)
                    end
                end
            end
        end
    end
end
autoFarm:Init()

-- ============================================================
-- GENERATOR ESP (สีคงที่: เขียว)
-- ============================================================
local generatorESP = {}
generatorESP.Enabled = false
generatorESP.Color = Color3.fromRGB(0, 255, 0)
generatorESP.Objects = {}
generatorESP.CurrentFolder = nil
generatorESP.Connections = {}

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
    if self.Objects[target] then self.Objects[target]:Destroy(); self.Objects[target] = nil end
end
function generatorESP:ClearAll() for o in pairs(self.Objects) do self:RemoveESP(o) end end
function generatorESP:Scan()
    if not self.Enabled then return end
    local folder = self:GetGeneratorsFolder()
    if not folder then self:ClearAll(); return end
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
            task.wait(0.1); self:AddESP(child)
        end
    end)
    self.Connections.ChildRemoved = folder.ChildRemoved:Connect(function(child) self:RemoveESP(child) end)
end
function generatorESP:Start() self.Enabled = true; self:ConnectFolder(); self:Scan() end
function generatorESP:Stop()
    self.Enabled = false; self:ClearAll()
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end

-- ============================================================
-- MONSTER ESP (สีคงที่: แดง)
-- ============================================================
local monsterESP = {}
monsterESP.Enabled = false
monsterESP.Color = Color3.fromRGB(255, 0, 0)
monsterESP.Objects = {}
monsterESP.CurrentFolder = nil
monsterESP.Connections = {}

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
            if child:IsA("BasePart") then conn:Disconnect(); self:AddESP(target) end
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
    if not folder then self:ClearAll(); return end
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
        if child:IsA("Model") and self.Enabled then task.wait(0.1); self:AddESP(child) end
    end)
    self.Connections.ChildRemoved = folder.ChildRemoved:Connect(function(child) self:RemoveESP(child) end)
end
function monsterESP:Start() self.Enabled = true; self:ConnectFolder(); self:Scan() end
function monsterESP:Stop()
    self.Enabled = false; self:ClearAll()
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end

-- ============================================================
-- ITEM ESP (สีคงที่: ฟ้า + เขียวสำหรับ health)
-- ============================================================
local itemESP = {}
itemESP.Enabled = false
itemESP.Color = Color3.fromRGB(0, 150, 255)
itemESP.HealthColor = Color3.fromRGB(0, 255, 0)
itemESP.Objects = {}
itemESP.CurrentFolder = nil
itemESP.Connections = {}

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
            if child:IsA("BasePart") then conn:Disconnect(); self:AddESP(target) end
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
    if not folder then self:ClearAll(); return end
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
            task.wait(0.1); self:AddESP(child)
        end
    end)
    self.Connections.ChildRemoved = folder.ChildRemoved:Connect(function(child) self:RemoveESP(child) end)
end
function itemESP:Start() self.Enabled = true; self:ConnectFolder(); self:Scan() end
function itemESP:Stop()
    self.Enabled = false; self:ClearAll()
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end

-- ============================================================
-- CAMERA / LIGHTING
-- ============================================================
local cameraMod = {}
cameraMod.FOVEnabled = false
cameraMod.FOV = 70
cameraMod.FullbrightEnabled = false
cameraMod.LightingConns = {}
cameraMod.OriginalLighting = {}

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
        self.LightingConns.Brightness = lighting:GetPropertyChangedSignal("Brightness"):Connect(apply)
        self.LightingConns.ClockTime = lighting:GetPropertyChangedSignal("ClockTime"):Connect(apply)
        self.LightingConns.FogEnd = lighting:GetPropertyChangedSignal("FogEnd"):Connect(apply)
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
infinityJump.Enabled = false
infinityJump.JumpForce = 50
function infinityJump:Jump()
    if not self.Enabled then return end
    local character = localPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
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
walkSpeed.Enabled = false
walkSpeed.Speed = 16
walkSpeed.LoopConn = nil
walkSpeed.CharConn = nil

local function getHumanoid()
    local character = localPlayer.Character
    return character and character:FindFirstChildWhichIsA("Humanoid")
end
local function applyWalkSpeed(value)
    local humanoid = getHumanoid()
    if humanoid then humanoid.WalkSpeed = value end
end
function walkSpeed:Start()
    self.Enabled = true
    applyWalkSpeed(self.Speed)
    local humanoid = getHumanoid()
    if humanoid then
        if self.LoopConn then self.LoopConn:Disconnect() end
        self.LoopConn = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if self.Enabled then applyWalkSpeed(self.Speed) end
        end)
    end
    if self.CharConn then self.CharConn:Disconnect() end
    self.CharConn = localPlayer.CharacterAdded:Connect(function(character)
        if not self.Enabled then return end
        local humanoid2 = character:WaitForChild("Humanoid")
        applyWalkSpeed(self.Speed)
        if self.LoopConn then self.LoopConn:Disconnect() end
        self.LoopConn = humanoid2:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if self.Enabled then applyWalkSpeed(self.Speed) end
        end)
    end)
end
function walkSpeed:Stop()
    self.Enabled = false
    if self.LoopConn then self.LoopConn:Disconnect(); self.LoopConn = nil end
    if self.CharConn then self.CharConn:Disconnect(); self.CharConn = nil end
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
    local row = farmForm:Row({ SearchIndex = "Auto TP to Generators" })
    row:Left():TitleStack({ Title = "Auto TP to Generators", Subtitle = "TP ไปเครื่องที่ดีที่สุด" })
    row:Right():Toggle({ Value = true, ValueChanged = function(_, v) autoFarm.AutoTeleport = v end })
end

do
    local row = farmForm:Row({ SearchIndex = "Auto Elevator" })
    row:Left():TitleStack({ Title = "Auto Elevator", Subtitle = "TP ไปลิฟต์เมื่อครบทุกเครื่อง" })
    row:Right():Toggle({ Value = true, ValueChanged = function(_, v) autoFarm.AutoElevator = v end })
end

-- 🌟 SECTION ใหม่: Parabola Teleport
local parabForm = autoFarmTab:PageSection({ Title = "Parabola Teleport", Subtitle = "วาปแบบพาราโบลา 6 จังหวะ" }):Form()

do
    local row = parabForm:Row({ SearchIndex = "Use Parabola Teleport" })
    row:Left():TitleStack({ Title = "Use Parabola Teleport", Subtitle = "เปิดวาปแบบพาราโบลา (นุ่มนวลกว่า)" })
    row:Right():Toggle({
        Value = true,
        ValueChanged = function(_, v) autoFarm.UseParabola = v end,
    })
end

addSliderWithValue(parabForm, {
    SearchIndex = "Parabola Delay",
    Title = "Parabola Delay",
    Subtitle = "หน่วงแต่ละจังหวะ (วินาที)",
    Min = 5,
    Max = 30,
    Default = 15,
    Suffix = "x0.01s",
    OnChanged = function(v) autoFarm.ParabolaDelay = v / 100 end,
})

local safetyForm = autoFarmTab:PageSection({ Title = "Safety", Subtitle = "ระบบความปลอดภัย" }):Form()

do
    local row = safetyForm:Row({ SearchIndex = "Auto Save from Monsters" })
    row:Left():TitleStack({ Title = "Auto Save from Monsters", Subtitle = "หนีขึ้นฟ้าเมื่อมอนใกล้" })
    row:Right():Toggle({ Value = true, ValueChanged = function(_, v) autoFarm.UseSafeZone = v end })
end

addSliderWithValue(safetyForm, {
    SearchIndex = "Safe Distance",
    Title = "Safe Distance",
    Subtitle = "ระยะห่างจากมอน",
    Min = 10,
    Max = 150,
    Default = 45,
    Suffix = "studs",
    OnChanged = function(v) autoFarm.SafeDistance = v end,
})

-- ============================================================
-- UI: VISUALS TAB
-- ============================================================
local genForm = visualsTab:PageSection({ Title = "Generator ESP", Subtitle = "ไฮไลต์สีเขียว" }):Form()

do
    local row = genForm:Row({ SearchIndex = "Generator ESP" })
    row:Left():TitleStack({ Title = "Generator ESP", Subtitle = "ไฮไลต์เครื่องปั่นไฟ (สีเขียว)" })
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
    row:Left():TitleStack({ Title = "Monster ESP", Subtitle = "ไฮไลต์มอน + ชื่อ (สีแดง)" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v)
            if v then monsterESP:Start() else monsterESP:Stop() end
        end,
    })
end

local itemForm = visualsTab:PageSection({ Title = "Item ESP", Subtitle = "ไฮไลต์ไอเทมบนพื้น" }):Form()

do
    local row = itemForm:Row({ SearchIndex = "Item ESP" })
    row:Left():TitleStack({ Title = "Item ESP", Subtitle = "ไฮไลต์ไอเทม (ฟ้า) + Health (เขียว)" })
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
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v) cameraMod:ToggleFOV(v) end,
    })
end

addSliderWithValue(camForm, {
    SearchIndex = "Field Of View",
    Title = "Field Of View",
    Subtitle = "ค่า FOV",
    Min = 30,
    Max = 120,
    Default = 70,
    Suffix = "deg",
    OnChanged = function(v) cameraMod:SetFOV(v) end,
})

do
    local row = camForm:Row({ SearchIndex = "Fullbright" })
    row:Left():TitleStack({ Title = "Fullbright", Subtitle = "เปิดไฟสว่างทั้งแมพ ลบหมอก" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v) cameraMod:ToggleFullbright(v) end,
    })
end

-- ============================================================
-- UI: MOVEMENT TAB
-- ============================================================
local jumpForm = movementTab:PageSection({ Title = "Infinity Jump", Subtitle = "กระโดดไม่จำกัด" }):Form()

do
    local row = jumpForm:Row({ SearchIndex = "Infinity Jump" })
    row:Left():TitleStack({ Title = "Infinity Jump", Subtitle = "กด SPACE เพื่อกระโดดได้ตลอด" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v) infinityJump.Enabled = v end,
    })
end

addSliderWithValue(jumpForm, {
    SearchIndex = "Jump Force",
    Title = "Jump Force",
    Subtitle = "แรงกระโดด",
    Min = 10,
    Max = 100,
    Default = 50,
    OnChanged = function(v) infinityJump.JumpForce = v end,
})

local wsForm = movementTab:PageSection({ Title = "Walk Speed", Subtitle = "ความเร็วเดิน" }):Form()

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
    SearchIndex = "Speed",
    Title = "Speed",
    Subtitle = "ค่าความเร็ว (default 16)",
    Min = 1,
    Max = 500,
    Default = 16,
    OnChanged = function(v) walkSpeed:SetSpeed(v) end,
})

-- ============================================================
-- UI: SETTINGS TAB
-- ============================================================
local creditsForm = settingsTab:PageSection({ Title = "Credits", Subtitle = "ข้อมูลผู้พัฒนา" }):Form()

do
    local row = creditsForm:Row({ SearchIndex = "Credits" })
    row:Left():TitleStack({
        Title = "999ms HUB",
        Subtitle = "Made by 09ms | Cascade UI Edition + Parabola",
    })
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
        if generatorESP.Enabled then generatorESP:ClearAll(); generatorESP:ConnectFolder(); generatorESP:Scan() end
        if monsterESP.Enabled then monsterESP:ClearAll(); monsterESP:ConnectFolder(); monsterESP:Scan() end
        if itemESP.Enabled then itemESP:ClearAll(); itemESP:ConnectFolder(); itemESP:Scan() end
    end)
    currentRoom.ChildRemoved:Connect(function()
        generatorESP:ClearAll(); generatorESP.CurrentFolder = nil
        monsterESP:ClearAll(); monsterESP.CurrentFolder = nil
        itemESP:ClearAll(); itemESP.CurrentFolder = nil
    end)
end

task.spawn(function()
    while task.wait(2) do
        if generatorESP.Enabled then generatorESP:ConnectFolder(); generatorESP:Scan() end
        if monsterESP.Enabled then monsterESP:ConnectFolder(); monsterESP:Scan() end
        if itemESP.Enabled then itemESP:ConnectFolder(); itemESP:Scan() end
    end
end)

-- ============================================================
app:Notification({
    App = "999ms HUB",
    Title = "Loaded Successfully",
    Subtitle = "999ms HUB | Dandy World (Parabola Edition)",
    Icon = cascade.Symbols.checkmark,
    Duration = 5,
})