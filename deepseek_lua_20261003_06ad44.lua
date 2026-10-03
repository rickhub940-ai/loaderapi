-- 999ms HUB | Cascade UI Edition (DPI Fixed Size, No Music, No TP Walk)
-- Original logic deobfuscated by LeakD | Rewritten for Cascade

local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local lighting = game:GetService("Lighting")
local players = game:GetService("Players")
local userInputService = game:GetService("UserInputService")
local localPlayer = players.LocalPlayer

-- ============================================================
-- ✅ FIX: CoreGui
-- ============================================================
local coreGui
pcall(function()
    coreGui = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not coreGui then
    coreGui = game:GetService("CoreGui")
end

-- ============================================================
-- 📏 DPI-based FIXED SIZE
-- ============================================================
local function isMobile()
    return userInputService.TouchEnabled and not userInputService.KeyboardEnabled
end

local function getDPIScale()
    local cam = workspace.CurrentCamera
    local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
    local diag = math.sqrt(vp.X * vp.X + vp.Y * vp.Y)
    local baseDiag = math.sqrt(1920 * 1920 + 1080 * 1080)
    local scale = diag / baseDiag
    if isMobile() then scale = scale * 1.30 end
    return math.clamp(scale, 0.55, 1.5)
end

local DPI_SCALE = getDPIScale()
local IS_MOBILE = isMobile()

local BASE_W       = 560
local BASE_H       = 380
local BASE_SIDEBAR = 160

local WIN_W = math.floor(BASE_W * DPI_SCALE)
local WIN_H = math.floor(BASE_H * DPI_SCALE)
local WIN_SIZE = UDim2.fromOffset(WIN_W, WIN_H)

local WIN_MIN_SIZE = Vector2.new(math.floor(WIN_W * 0.85), math.floor(WIN_H * 0.85))
local WIN_MAX_SIZE = Vector2.new(math.floor(WIN_W * 1.30), math.floor(WIN_H * 1.30))
local SIDEBAR_WIDTH = math.clamp(math.floor(BASE_SIDEBAR * DPI_SCALE), 110, 220)

-- ============================================================
-- โหลด Cascade UI
-- ============================================================
local function importRelease(owner, repo, version, file)
    local tag = (version == "latest" and "latest/download" or "download/" .. version)
    local url = ("https://github.com/%s/%s/releases/%s/%s"):format(owner, repo, tag, file)
    return loadstring(game:HttpGet(url))()
end

local cascade
do
    local ok, result = pcall(function()
        return importRelease("biggaboy212", "Cascade", "latest", "dist.luau")
    end)
    if not ok or not result then
        warn("[999ms HUB] Failed to load Cascade:", result)
        return
    end
    cascade = result
end

local app = cascade.New({
    WindowPill = true,
    Theme = cascade.Themes.Dark,
    Accent = cascade.Accents.Purple,
})

local window = app:Window({
    Title = "999ms HUB",
    Subtitle = "by 09ms | Dandy World",
    Size = WIN_SIZE,
    MinSize = WIN_MIN_SIZE,
    MaxSize = WIN_MAX_SIZE,
    Resizable = true,
    SideBarWidth = SIDEBAR_WIDTH,
})

-- ============================================================
-- TABS
-- ============================================================
local mainSection = window:Section({ Disclosure = false, Title = "Menu" })

local autoFarmTab = mainSection:Tab({ Selected = true, Title = "Auto Farm", Icon = cascade.Symbols.sword })
local visualsTab  = mainSection:Tab({ Title = "Visuals",   Icon = cascade.Symbols.eye })
local movementTab = mainSection:Tab({ Title = "Movement",  Icon = cascade.Symbols.arrowUpCircle })
local settingsTab = mainSection:Tab({ Title = "Settings",  Icon = cascade.Symbols.settings })

-- ============================================================
-- AUTO FARM MODULE
-- ============================================================
local autoFarm = {}
autoFarm.Enabled = false
autoFarm.AutoInteract = true
autoFarm.AutoTeleport = true
autoFarm.AutoElevator = true
autoFarm.UseSafeZone = true
autoFarm.SafeDistance = 45
autoFarm.CachedGenerators = {}
autoFarm.SafeZone = nil

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

    for _, obj in ipairs(workspace:GetDescendants()) do
        cacheGenerator(obj)
    end

    workspace.DescendantAdded:Connect(cacheGenerator)
    workspace.DescendantRemoving:Connect(function(obj)
        self.CachedGenerators[obj] = nil
    end)

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
        if obj:IsA("Model") or obj:IsA("Folder") then
            map = obj
            break
        end
    end
    if not map then return math.huge end

    local monsters = map:FindFirstChild("Monsters")
    if not monsters then return math.huge end

    local nearest = math.huge
    for _, monster in pairs(monsters:GetChildren()) do
        if monster:IsA("Model") then
            local basePart = monster.PrimaryPart or monster:FindFirstChildWhichIsA("BasePart")
            if basePart then
                local dist = (basePart.Position - pos).Magnitude
                if dist < nearest then nearest = dist end
            end
        end
    end
    return nearest
end

function autoFarm:GetGeneratorTargetCFrame(generator)
    local teleportGroup = generator:FindFirstChild("TeleportPositions")
        or generator:FindFirstChild("TreadmillTeleportPositions")

    if teleportGroup and #teleportGroup:GetChildren() > 0 then
        return teleportGroup:GetChildren()[1].CFrame
    end

    local singleTp = generator:FindFirstChild("TeleportPosition")
        or generator:FindFirstChild("TreadmillTeleportPosition")
    if singleTp then return singleTp.CFrame end

    local pos = generator.PrimaryPart and generator.PrimaryPart.Position
        or generator:GetPivot().Position
    return CFrame.new(pos) * CFrame.new(0, 0, 4)
end

function autoFarm:GoToSafeZone(character, hrp)
    if not self.UseSafeZone then return end

    local basePos = hrp.Position
    local anyGen = next(self.CachedGenerators)
    if anyGen then
        basePos = anyGen.PrimaryPart and anyGen.PrimaryPart.Position
            or anyGen:GetPivot().Position
    end

    self.SafeZone.Position = Vector3.new(basePos.X, basePos.Y + 50, basePos.Z)
    if math.abs(hrp.Position.Y - self.SafeZone.Position.Y) > 10 then
        character:PivotTo(self.SafeZone.CFrame * CFrame.new(0, 3, 0))
    end
end

function autoFarm:Step()
    local character = localPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local info = workspace:FindFirstChild("Info")
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
                local completed = stats:FindFirstChild("Completed")
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
                                bestDistance = d
                            end
                        end
                    end
                end
            end
        end
    end

    if isInteracting and (monsterNear or panic) then
        local stopRemote = statsRef:FindFirstChild("StopInteracting")
        if stopRemote and stopRemote:IsA("RemoteEvent") then
            stopRemote:FireServer()
        end
        isInteracting = false
    end

    if self.AutoElevator and (panic or (totalGens > 0 and unfinishedGens == 0)) then
        local elevators = workspace:FindFirstChild("Elevators")
        local elevator = elevators and elevators:FindFirstChild("Elevator")
        if elevator then
            local pivot = elevator.PrimaryPart and elevator.PrimaryPart.CFrame
                or elevator:GetPivot()
            if (hrp.Position - pivot.Position).Magnitude > 8 then
                character:PivotTo(pivot * CFrame.new(0, 3, 0))
            end
        end
        return
    elseif totalGens == 0 then
        return
    end

    if not isInteracting and self.AutoTeleport then
        if bestGenerator then
            local target = self:GetGeneratorTargetCFrame(bestGenerator)
            if (target.Position - hrp.Position).Magnitude > 5 then
                character:PivotTo(target)
                task.wait(0.3)
            end
        else
            self:GoToSafeZone(character, hrp)
        end
    end

    if self.AutoInteract and math.abs(hrp.Position.Y - self.SafeZone.Position.Y) > 10 then
        for generator in pairs(self.CachedGenerators) do
            local stats = generator:FindFirstChild("Stats")
            if stats then
                local completed = stats:FindFirstChild("Completed")
                local activePlayer = stats:FindFirstChild("ActivePlayer")
                if completed and not completed.Value
                    and activePlayer
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
-- GENERATOR ESP
-- ============================================================
local generatorESP = {}
generatorESP.Enabled = false
generatorESP.Color = Color3.fromRGB(0, 255, 0)
generatorESP.Objects = {}
generatorESP.CurrentFolder = nil
generatorESP.Connections = {}

function generatorESP:GetCurrentMap()
    local currentRoom = workspace:FindFirstChild("CurrentRoom")
    if not currentRoom then return nil end
    for _, obj in pairs(currentRoom:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Folder") then return obj end
    end
end
function generatorESP:GetGeneratorsFolder()
    local map = self:GetCurrentMap()
    return map and map:FindFirstChild("Generators")
end
function generatorESP:AddESP(target)
    if not self.Enabled or self.Objects[target] then return end
    local highlight = Instance.new("Highlight")
    highlight.Adornee = target
    highlight.FillColor = self.Color
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = self.Color
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = coreGui
    self.Objects[target] = highlight
end
function generatorESP:RemoveESP(target)
    if self.Objects[target] then
        self.Objects[target]:Destroy()
        self.Objects[target] = nil
    end
end
function generatorESP:ClearAll()
    for obj in pairs(self.Objects) do self:RemoveESP(obj) end
end
function generatorESP:Scan()
    if not self.Enabled then return end
    local folder = self:GetGeneratorsFolder()
    if not folder then self:ClearAll(); return end
    for _, child in pairs(folder:GetChildren()) do
        if child:IsA("Model") or child:IsA("BasePart") then
            self:AddESP(child)
        end
    end
    for obj in pairs(self.Objects) do
        if not obj.Parent or obj.Parent ~= folder then
            self:RemoveESP(obj)
        end
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
            task.wait(0.1)
            self:AddESP(child)
        end
    end)
    self.Connections.ChildRemoved = folder.ChildRemoved:Connect(function(child)
        self:RemoveESP(child)
    end)
end
function generatorESP:Start()
    self.Enabled = true
    self:ConnectFolder()
    self:Scan()
end
function generatorESP:Stop()
    self.Enabled = false
    self:ClearAll()
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end
function generatorESP:UpdateColor(color)
    self.Color = color
    for _, highlight in pairs(self.Objects) do
        if highlight and highlight.Parent then
            highlight.FillColor = color
            highlight.OutlineColor = color
        end
    end
end

-- ============================================================
-- MONSTER ESP
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
    local currentRoom = workspace:FindFirstChild("CurrentRoom")
    if not currentRoom then return nil end
    for _, obj in pairs(currentRoom:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Folder") then return obj end
    end
end
function monsterESP:GetMonstersFolder()
    local map = self:GetCurrentMap()
    return map and map:FindFirstChild("Monsters")
end
function monsterESP:AddESP(target)
    if not self.Enabled or self.Objects[target] then return end
    local primaryPart = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        local conn
        conn = target.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") then
                conn:Disconnect()
                self:AddESP(target)
            end
        end)
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = target
    highlight.FillColor = self.Color
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = self.Color
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = coreGui

    local billboard = Instance.new("BillboardGui")
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 150, 0, 25)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.LightInfluence = 0
    billboard.Adornee = primaryPart
    billboard.Parent = coreGui

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.Text = self:CleanName(target.Name)
    label.TextColor3 = self.Color
    label.TextSize = 15
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.fromRGB(80, 0, 0)
    label.Parent = billboard

    self.Objects[target] = { Highlight = highlight, Billboard = billboard }
end
function monsterESP:RemoveESP(target)
    if self.Objects[target] then
        self.Objects[target].Highlight:Destroy()
        self.Objects[target].Billboard:Destroy()
        self.Objects[target] = nil
    end
end
function monsterESP:ClearAll()
    for obj in pairs(self.Objects) do self:RemoveESP(obj) end
end
function monsterESP:Scan()
    if not self.Enabled then return end
    local folder = self:GetMonstersFolder()
    if not folder then self:ClearAll(); return end
    for _, child in pairs(folder:GetChildren()) do
        if child:IsA("Model") then self:AddESP(child) end
    end
    for obj in pairs(self.Objects) do
        if not obj.Parent or obj.Parent ~= folder then
            self:RemoveESP(obj)
        end
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
        if child:IsA("Model") and self.Enabled then
            task.wait(0.1)
            self:AddESP(child)
        end
    end)
    self.Connections.ChildRemoved = folder.ChildRemoved:Connect(function(child)
        self:RemoveESP(child)
    end)
end
function monsterESP:Start()
    self.Enabled = true
    self:ConnectFolder()
    self:Scan()
end
function monsterESP:Stop()
    self.Enabled = false
    self:ClearAll()
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end
function monsterESP:UpdateColor(color)
    self.Color = color
    for _, data in pairs(self.Objects) do
        if data.Highlight and data.Highlight.Parent then
            data.Highlight.FillColor = color
            data.Highlight.OutlineColor = color
        end
        if data.Billboard then
            local label = data.Billboard:FindFirstChildWhichIsA("TextLabel")
            if label then label.TextColor3 = color end
        end
    end
end

-- ============================================================
-- ITEM ESP
-- ============================================================
local itemESP = {}
itemESP.Enabled = false
itemESP.Color = Color3.fromRGB(0, 150, 255)
itemESP.HealthColor = Color3.fromRGB(0, 255, 0)
itemESP.Objects = {}
itemESP.CurrentFolder = nil
itemESP.Connections = {}

function itemESP:GetCurrentMap()
    local currentRoom = workspace:FindFirstChild("CurrentRoom")
    if not currentRoom then return nil end
    for _, obj in pairs(currentRoom:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Folder") then return obj end
    end
end
function itemESP:GetItemsFolder()
    local map = self:GetCurrentMap()
    return map and map:FindFirstChild("Items")
end
function itemESP:AddESP(target)
    if not self.Enabled or self.Objects[target] then return end
    local primaryPart = target:IsA("Model")
        and (target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart"))
        or target

    if not primaryPart or not primaryPart:IsA("BasePart") then
        local conn
        conn = target.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") then
                conn:Disconnect()
                self:AddESP(target)
            end
        end)
        return
    end

    local isHealthItem = (target.Name == "HealthKit" or target.Name == "Bandage")
    local color = isHealthItem and self.HealthColor or self.Color

    local highlight = Instance.new("Highlight")
    highlight.Adornee = target:IsA("Model") and target or primaryPart
    highlight.FillColor = color
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = coreGui

    local billboard = Instance.new("BillboardGui")
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 150, 0, 25)
    billboard.StudsOffset = Vector3.new(0, 1.5, 0)
    billboard.LightInfluence = 0
    billboard.Adornee = primaryPart
    billboard.Parent = coreGui

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.Text = target.Name:gsub("(%l)(%u)", "%1 %2")
    label.TextColor3 = color
    label.TextSize = 13
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = billboard

    self.Objects[target] = { Highlight = highlight, Billboard = billboard }
end
function itemESP:RemoveESP(target)
    if self.Objects[target] then
        if self.Objects[target].Highlight then self.Objects[target].Highlight:Destroy() end
        if self.Objects[target].Billboard then self.Objects[target].Billboard:Destroy() end
        self.Objects[target] = nil
    end
end
function itemESP:ClearAll()
    for obj in pairs(self.Objects) do self:RemoveESP(obj) end
end
function itemESP:Scan()
    if not self.Enabled then return end
    local folder = self:GetItemsFolder()
    if not folder then self:ClearAll(); return end
    for _, child in pairs(folder:GetChildren()) do
        if child:IsA("Model") or child:IsA("BasePart") then
            self:AddESP(child)
        end
    end
    for obj in pairs(self.Objects) do
        if not obj.Parent or obj.Parent ~= folder then
            self:RemoveESP(obj)
        end
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
            task.wait(0.1)
            self:AddESP(child)
        end
    end)
    self.Connections.ChildRemoved = folder.ChildRemoved:Connect(function(child)
        self:RemoveESP(child)
    end)
end
function itemESP:Start()
    self.Enabled = true
    self:ConnectFolder()
    self:Scan()
end
function itemESP:Stop()
    self.Enabled = false
    self:ClearAll()
    if self.Connections.ChildAdded then self.Connections.ChildAdded:Disconnect() end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end
function itemESP:UpdateColor(color)
    self.Color = color
    for key, data in pairs(self.Objects) do
        local isHealthItem = (key.Name == "HealthKit" or key.Name == "Bandage")
        local col = isHealthItem and self.HealthColor or color
        if data.Highlight and data.Highlight.Parent then
            data.Highlight.FillColor = col
            data.Highlight.OutlineColor = col
        end
        if data.Billboard then
            local label = data.Billboard:FindFirstChildWhichIsA("TextLabel")
            if label then label.TextColor3 = col end
        end
    end
end
function itemESP:UpdateHealthColor(color)
    self.HealthColor = color
    for key, data in pairs(self.Objects) do
        if key.Name == "HealthKit" or key.Name == "Bandage" then
            if data.Highlight and data.Highlight.Parent then
                data.Highlight.FillColor = color
                data.Highlight.OutlineColor = color
            end
            if data.Billboard then
                local label = data.Billboard:FindFirstChildWhichIsA("TextLabel")
                if label then label.TextColor3 = color end
            end
        end
    end
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
            if cam and cam.FieldOfView ~= self.FOV then
                cam.FieldOfView = self.FOV
            end
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

userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Space then
        infinityJump:Jump()
    end
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
local farmForm = autoFarmTab:PageSection({ Title = "Auto Farm" }):Form()

local farmHeader = farmForm:Row({ SearchIndex = "FarmHeader" })
farmHeader:Left():TitleStack({ Title = "Enable Auto Farm", Subtitle = "Toggle ทั้งหมด" })
farmHeader:Right():Toggle({
    Value = false,
    ValueChanged = function(_, value)
        autoFarm.Enabled = value
        if value then
            window:Toast({ Title = "Auto Farm", Content = "Enabled" })
        else
            window:Toast({ Title = "Auto Farm", Content = "Disabled" })
        end
    end,
})

local interactRow = farmForm:Row({ SearchIndex = "AutoInteract" })
interactRow:Left():TitleStack({ Title = "Auto Fix Generators", Subtitle = "ซ่อมเครื่องปั่นไฟอัตโนมัติ" })
interactRow:Right():Toggle({
    Value = true,
    ValueChanged = function(_, value) autoFarm.AutoInteract = value end,
})

local tpRow = farmForm:Row({ SearchIndex = "AutoTeleport" })
tpRow:Left():TitleStack({ Title = "Auto TP to Generators", Subtitle = "TP ไปเครื่องที่ดีที่สุด" })
tpRow:Right():Toggle({
    Value = true,
    ValueChanged = function(_, value) autoFarm.AutoTeleport = value end,
})

local elevatorRow = farmForm:Row({ SearchIndex = "AutoElevator" })
elevatorRow:Left():TitleStack({ Title = "Auto Elevator", Subtitle = "TP ไปลิฟต์เมื่อครบทุกเครื่อง" })
elevatorRow:Right():Toggle({
    Value = true,
    ValueChanged = function(_, value) autoFarm.AutoElevator = value end,
})

local safetyForm = autoFarmTab:PageSection({ Title = "Safety" }):Form()

local safeZoneRow = safetyForm:Row({ SearchIndex = "UseSafeZone" })
safeZoneRow:Left():TitleStack({ Title = "Auto Save from Monsters", Subtitle = "หนีขึ้นฟ้าเมื่อมอนใกล้" })
safeZoneRow:Right():Toggle({
    Value = true,
    ValueChanged = function(_, value) autoFarm.UseSafeZone = value end,
})

local safeDistanceRow = safetyForm:Row({ SearchIndex = "SafeDistance" })
safeDistanceRow:Left():TitleStack({ Title = "Safe Distance", Subtitle = "ระยะห่างจากมอน (studs)" })
safeDistanceRow:Right():Slider({
    Value = 45,
    Min = 10,
    Max = 150,
    ValueChanged = function(_, value) autoFarm.SafeDistance = value end,
})

-- ============================================================
-- UI: VISUALS TAB
-- ============================================================
local genForm = visualsTab:PageSection({ Title = "Generator ESP" }):Form()
local genToggleRow = genForm:Row({ SearchIndex = "GeneratorESP" })
genToggleRow:Left():TitleStack({ Title = "Generator ESP", Subtitle = "ไฮไลต์เครื่องปั่นไฟ" })
genToggleRow:Right():Toggle({
    Value = false,
    ValueChanged = function(_, value)
        if value then generatorESP:Start() else generatorESP:Stop() end
    end,
})
local genColorRow = genForm:Row({ SearchIndex = "GenColor" })
genColorRow:Left():TitleStack({ Title = "Generator Color", Subtitle = "สีไฮไลต์" })
genColorRow:Right():ColorPicker({
    Value = Color3.fromRGB(0, 255, 0),
    ValueChanged = function(_, color) generatorESP:UpdateColor(color) end,
})

local monForm = visualsTab:PageSection({ Title = "Monster ESP" }):Form()
local monToggleRow = monForm:Row({ SearchIndex = "MonsterESP" })
monToggleRow:Left():TitleStack({ Title = "Monster ESP", Subtitle = "ไฮไลต์มอน + ชื่อ" })
monToggleRow:Right():Toggle({
    Value = false,
    ValueChanged = function(_, value)
        if value then monsterESP:Start() else monsterESP:Stop() end
    end,
})
local monColorRow = monForm:Row({ SearchIndex = "MonsterColor" })
monColorRow:Left():TitleStack({ Title = "Monster Color", Subtitle = "สีไฮไลต์มอน" })
monColorRow:Right():ColorPicker({
    Value = Color3.fromRGB(255, 0, 0),
    ValueChanged = function(_, color) monsterESP:UpdateColor(color) end,
})

local itemForm = visualsTab:PageSection({ Title = "Item ESP" }):Form()
local itemToggleRow = itemForm:Row({ SearchIndex = "ItemESP" })
itemToggleRow:Left():TitleStack({ Title = "Item ESP", Subtitle = "ไฮไลต์ไอเทมบนพื้น" })
itemToggleRow:Right():Toggle({
    Value = false,
    ValueChanged = function(_, value)
        if value then itemESP:Start() else itemESP:Stop() end
    end,
})
local itemColorRow = itemForm:Row({ SearchIndex = "ItemColor" })
itemColorRow:Left():TitleStack({ Title = "Item Color", Subtitle = "สีไฮไลต์ไอเทมทั่วไป" })
itemColorRow:Right():ColorPicker({
    Value = Color3.fromRGB(0, 150, 255),
    ValueChanged = function(_, color) itemESP:UpdateColor(color) end,
})
local healthColorRow = itemForm:Row({ SearchIndex = "HealthColor" })
healthColorRow:Left():TitleStack({ Title = "Health Item Color", Subtitle = "สีของ HealthKit/Bandage" })
healthColorRow:Right():ColorPicker({
    Value = Color3.fromRGB(0, 255, 0),
    ValueChanged = function(_, color) itemESP:UpdateHealthColor(color) end,
})

local camForm = visualsTab:PageSection({ Title = "Camera & Lighting" }):Form()
local fovToggleRow = camForm:Row({ SearchIndex = "FOVToggle" })
fovToggleRow:Left():TitleStack({ Title = "Enable Custom FOV", Subtitle = "กำหนด FOV เอง" })
fovToggleRow:Right():Toggle({
    Value = false,
    ValueChanged = function(_, value) cameraMod:ToggleFOV(value) end,
})
local fovSliderRow = camForm:Row({ SearchIndex = "FOVSlider" })
fovSliderRow:Left():TitleStack({ Title = "Field Of View", Subtitle = "ค่า FOV ที่ต้องการ" })
fovSliderRow:Right():Slider({
    Value = 70,
    Min = 30,
    Max = 120,
    ValueChanged = function(_, value) cameraMod:SetFOV(value) end,
})
local fullbrightRow = camForm:Row({ SearchIndex = "Fullbright" })
fullbrightRow:Left():TitleStack({ Title = "Fullbright", Subtitle = "เปิดไฟสว่างทั้งแมพ ลบหมอก" })
fullbrightRow:Right():Toggle({
    Value = false,
    ValueChanged = function(_, value) cameraMod:ToggleFullbright(value) end,
})

-- ============================================================
-- UI: MOVEMENT TAB
-- ============================================================
local jumpForm = movementTab:PageSection({ Title = "Infinity Jump" }):Form()
local jumpToggleRow = jumpForm:Row({ SearchIndex = "InfinityJump" })
jumpToggleRow:Left():TitleStack({ Title = "Infinity Jump", Subtitle = "กด SPACE เพื่อกระโดดได้ตลอด" })
jumpToggleRow:Right():Toggle({
    Value = false,
    ValueChanged = function(_, value) infinityJump.Enabled = value end,
})
local jumpForceRow = jumpForm:Row({ SearchIndex = "JumpForce" })
jumpForceRow:Left():TitleStack({ Title = "Jump Force", Subtitle = "แรงกระโดด" })
jumpForceRow:Right():Slider({
    Value = 50,
    Min = 10,
    Max = 100,
    ValueChanged = function(_, value) infinityJump.JumpForce = value end,
})

local wsForm = movementTab:PageSection({ Title = "Walk Speed" }):Form()
local wsToggleRow = wsForm:Row({ SearchIndex = "WalkSpeed" })
wsToggleRow:Left():TitleStack({ Title = "WalkSpeed", Subtitle = "บังคับความเร็วเดิน" })
wsToggleRow:Right():Toggle({
    Value = false,
    ValueChanged = function(_, value)
        if value then walkSpeed:Start() else walkSpeed:Stop() end
    end,
})
local wsValueRow = wsForm:Row({ SearchIndex = "WalkSpeedValue" })
wsValueRow:Left():TitleStack({ Title = "Speed", Subtitle = "ค่าความเร็ว (default 16)" })
wsValueRow:Right():Slider({
    Value = 16,
    Min = 1,
    Max = 500,
    ValueChanged = function(_, value) walkSpeed:SetSpeed(value) end,
})

-- ============================================================
-- UI: SETTINGS TAB
-- ============================================================
settingsTab:PageSection({ Title = "Credits" })
    :Paragraph({ Text = "999ms HUB | Made by 09ms | Cascade UI Edition" })

-- ============================================================
-- ESP ANIMATE
-- ============================================================
runService.RenderStepped:Connect(function()
    local pulse = math.abs(math.sin(tick() * 2))

    if generatorESP.Enabled then
        for target, highlight in pairs(generatorESP.Objects) do
            if target and target.Parent and highlight and highlight.Parent then
                local r, g, b = generatorESP.Color.R, generatorESP.Color.G, generatorESP.Color.B
                highlight.FillTransparency = 0.4 + pulse * 0.4
                highlight.OutlineColor = Color3.new(
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
                local primaryPart = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
                if primaryPart and data.Billboard and data.Billboard.Adornee ~= primaryPart then
                    data.Billboard.Adornee = primaryPart
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
                local primaryPart = target:IsA("Model")
                    and (target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart"))
                    or target
                if primaryPart and data.Billboard and data.Billboard.Adornee ~= primaryPart then
                    data.Billboard.Adornee = primaryPart
                end
                if data.Highlight and data.Highlight.Parent then
                    local isHealthItem = (target.Name == "HealthKit" or target.Name == "Bandage")
                    local color = isHealthItem and itemESP.HealthColor or itemESP.Color
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
        if generatorESP.Enabled then
            generatorESP:ClearAll(); generatorESP:ConnectFolder(); generatorESP:Scan()
        end
        if monsterESP.Enabled then
            monsterESP:ClearAll(); monsterESP:ConnectFolder(); monsterESP:Scan()
        end
        if itemESP.Enabled then
            itemESP:ClearAll(); itemESP:ConnectFolder(); itemESP:Scan()
        end
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
window:Toast({ Title = "999ms HUB", Content = "Loaded | Dandy World" })