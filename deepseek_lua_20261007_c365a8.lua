--[[
    █████╗  █████╗  █████╗ ███╗   ███╗███████╗
    ██╔══██╗██╔══██╗██╔══██╗████╗ ████║██╔════╝
    ███████║╚██████║╚██████║██╔████╔██║███████╗
    ██╔══██║ ╚═══██║ ╚═══██║██║╚██╔╝██║╚════██║
    ██║  ██║ █████╔╝ █████╔╝██║ ╚═╝ ██║███████║
    ╚═╝  ╚═╝ ╚════╝  ╚════╝ ╚═╝     ╚═╝╚══════╝
              999Ms HUB  v3.3
       BY. 009exe | Dandys World
   Target Finding 25ms + PivotTo Parabola
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
    Subtitle    = "by 09ms | v3.3",
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
-- 🌀 PIVOTTO + PARABOLA
-- ============================================================
local TP = {}
TP.Stats = { Success = 0, Failed = 0 }

TP.CFG = {
    Steps     = 6,
    ArcHeight = 18,
    ArcDepth  = 12,
    Delay     = 0.15,
    FinalWait = 0.10,
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

        local arcT    = 4 * t * (1 - t)
        local yOffset = arcT * arcHeight
        local zOffset = math.sin(math.pi * t) * arcDepth

        local offsetCFrame = CFrame.new(0, yOffset, zOffset)
        local stepCFrame   = targetCFrame * offsetCFrame

        pcall(function()
            character:PivotTo(stepCFrame)
        end)

        if i < steps then
            task.wait(TP.CFG.Delay)
        end
    end

    task.wait(TP.CFG.FinalWait)
    pcall(function()
        character:PivotTo(targetCFrame)
    end)

    TP.Stats.Success += 1
    return true
end

function TP.Direct(targetCFrame)
    local character = getCharacter()
    if not character then return false end
    pcall(function()
        character:PivotTo(targetCFrame)
    end)
    return true
end

function TP.ToPart(partName)
    local part = workspace:FindFirstChild(partName, true)
    if not part or not part:IsA("BasePart") then
        return false, "ไม่เจอ Part"
    end
    return TP.Parabola(part.CFrame)
end

function TP.ToPlayer(playerName)
    local target = players:FindFirstChild(playerName)
    if not target or not target.Character or not target.Character.PrimaryPart then
        return false, "ไม่เจอ Player"
    end
    return TP.Parabola(target.Character.PrimaryPart.CFrame)
end

function TP.ToCoords(x, y, z)
    return TP.Parabola(CFrame.new(x, y, z))
end

-- NetworkOwner
local function applyNetworkOwner(character)
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    if hrp then pcall(function() hrp:SetNetworkOwner(localPlayer) end) end
end
if localPlayer.Character then applyNetworkOwner(localPlayer.Character) end
localPlayer.CharacterAdded:Connect(applyNetworkOwner)

-- ============================================================
-- 🌾 AUTO FARM — Target Finding 25ms + Parabola TP
-- ============================================================
local autoFarm = {}
autoFarm.Enabled          = false
autoFarm.AutoInteract     = true
autoFarm.AutoTeleport     = true
autoFarm.AutoElevator     = true
autoFarm.UseSafeZone      = true
autoFarm.SafeDistance     = 45
autoFarm.SafeZone         = nil
autoFarm.Busy             = false
autoFarm.UseParabola      = true

-- 🔍 หา Generator ที่ดีที่สุด (แบบ 25ms — ตัวแรกที่ยังไม่ซ่อม)
function autoFarm:FindValidGenerator(currentRoom)
    if not currentRoom then return nil end

    for _, model in ipairs(currentRoom:GetChildren()) do
        if model:IsA("Model") or model:IsA("Folder") then
            local generatorsFolder = model:FindFirstChild("Generators")
            if generatorsFolder then
                for _, generator in ipairs(generatorsFolder:GetChildren()) do
                    if generator:IsA("Model") then
                        local stats = generator:FindFirstChild("Stats")
                        if stats and stats:FindFirstChild("Completed")
                           and not stats.Completed.Value then
                            return generator
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- 🔧 หา TeleportPosition จาก Generator (แบบ 25ms)
function autoFarm:GetTeleportPosition(generator)
    if not generator then return nil end

    local tpGroup = generator:FindFirstChild("TeleportPositions")
                 or generator:FindFirstChild("TreadmillTeleportPositions")
    if tpGroup then
        local tp = tpGroup:FindFirstChild("TeleportPosition")
                or tpGroup:FindFirstChildWhichIsA("BasePart")
        if tp and tp:IsA("BasePart") then
            return tp.CFrame
        end
    end

    local single = generator:FindFirstChild("TeleportPosition")
                or generator:FindFirstChild("TreadmillTeleportPosition")
    if single and single:IsA("BasePart") then
        return single.CFrame
    end

    local pos = generator.PrimaryPart and generator.PrimaryPart.Position
             or generator:GetPivot().Position
    return CFrame.new(pos) * CFrame.new(0, 0, 4)
end

-- 🛡️ เช็คมอนใกล้
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

-- 🌀 วาร์ป (ผ่าน TP)
function autoFarm:TeleportTo(targetCFrame)
    if not targetCFrame then return end
    if self.UseParabola then
        TP.Parabola(targetCFrame)
    else
        TP.Direct(targetCFrame)
    end
end

-- 🎯 Main Step
function autoFarm:Step()
    if self.Busy then return end
    if not self.Enabled then return end

    local character = getCharacter()
    local hrp = getHRP()
    if not hrp then return end

    local currentRoom = workspace:FindFirstChild("CurrentRoom")
    if not currentRoom then return end

    local info  = workspace:FindFirstChild("Info")
    local panic = info and info:FindFirstChild("Panic") and info.Panic.Value == true
    local monsterNear = self:GetNearestMonsterDistance(hrp.Position) < self.SafeDistance

    local generator = self:FindValidGenerator(currentRoom)

    local elevators = workspace:FindFirstChild("Elevators")
    local elevator  = elevators and elevators:FindFirstChild("Elevator")

    -- ไม่มี Generator → ไป Elevator
    if not generator then
        if self.AutoElevator and elevator then
            local pivot = elevator.PrimaryPart and elevator.PrimaryPart.CFrame
                       or elevator:GetPivot()
            if (hrp.Position - pivot.Position).Magnitude > 8 then
                self.Busy = true
                self:TeleportTo(pivot * CFrame.new(0, 3, 0))
                self.Busy = false
            end
        end
        return
    end

    -- มี Generator → วาร์ปไป
    if self.AutoTeleport then
        -- ถ้ามอนใกล้ → ขึ้น Safe Zone
        if (monsterNear or panic) and self.UseSafeZone then
            local genPos = generator.PrimaryPart and generator.PrimaryPart.Position
                        or generator:GetPivot().Position
            self.SafeZone.Position = Vector3.new(genPos.X, genPos.Y + 50, genPos.Z)
            if math.abs(hrp.Position.Y - self.SafeZone.Position.Y) > 10 then
                self.Busy = true
                self:TeleportTo(self.SafeZone.CFrame * CFrame.new(0, 3, 0))
                self.Busy = false
            end
            return
        end

        -- วาร์ปไปที่ TeleportPosition ของ Generator
        local targetCF = self:GetTeleportPosition(generator)
        if targetCF then
            if (targetCF.Position - hrp.Position).Magnitude > 5 then
                self.Busy = true
                self:TeleportTo(targetCF)
                task.wait(0.15)
                self.Busy = false
            end
        end

        -- Auto Interact — กด Prompt 3 ครั้ง
        if self.AutoInteract then
            local promptPart = generator:FindFirstChild("Prompt")
            if promptPart and promptPart:IsA("BasePart") then
                local prompt = promptPart:FindFirstChildOfClass("ProximityPrompt")
                if prompt then
                    for _ = 1, 3 do
                        pcall(function()
                            prompt:InputHoldBegin()
                            task.wait(0.05)
                            prompt:InputHoldEnd()
                        end)
                        task.wait(0.05)
                    end
                end
            end
        end
    end
end

-- Init
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

    task.spawn(function()
        while task.wait(0.3) do
            if self.Enabled and not self.Busy then
                pcall(function() self:Step() end)
            end
        end
    end)
end

autoFarm:Init()

-- ============================================================
-- GENERATOR ESP (แบบไฟล์ 25ms)
-- ============================================================
local generatorESP = {}
generatorESP.Enabled = false
generatorESP.Connection = nil

local function getCurrentRoom()
    return workspace:FindFirstChild("CurrentRoom")
end

function generatorESP:AddHighlight(generator)
    if not generator:FindFirstChildOfClass("Highlight") then
        local highlight = Instance.new("Highlight")
        highlight.Parent = generator
        highlight.FillColor = Color3.new(0, 1, 0)
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.5
    end

    if not generator:FindFirstChild("NameTag") then
        local billboardGui = Instance.new("BillboardGui")
        billboardGui.Name = "NameTag"
        billboardGui.Parent = generator
        billboardGui.Size = UDim2.new(8, 0, 2, 0)
        billboardGui.AlwaysOnTop = true
        billboardGui.MaxDistance = 2000

        local textLabel = Instance.new("TextLabel")
        textLabel.Parent = billboardGui
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = generator.Name
        textLabel.TextColor3 = Color3.new(0, 1, 0)
        textLabel.TextScaled = false
        textLabel.Font = Enum.Font.RobotoMono

        local uiStroke = Instance.new("UIStroke")
        uiStroke.Parent = textLabel
        uiStroke.Thickness = 4
        uiStroke.Color = Color3.fromRGB(0, 0, 0)

        local uiGradient = Instance.new("UIGradient")
        uiGradient.Parent = textLabel
        uiGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(0.7, 1, 0.7)),
            ColorSequenceKeypoint.new(1, Color3.new(0, 1, 0))
        })
    end
end

function generatorESP:RemoveHighlight(generator)
    local highlight = generator:FindFirstChildOfClass("Highlight")
    if highlight then highlight:Destroy() end

    local nameTag = generator:FindFirstChild("NameTag")
    if nameTag then nameTag:Destroy() end
end

function generatorESP:HighlightGenerators()
    local currentRoom = getCurrentRoom()
    if not currentRoom then return end

    for _, item in pairs(currentRoom:GetChildren()) do
        if item:IsA("Model") then
            local generatorsFolder = item:FindFirstChild("Generators")
            if generatorsFolder then
                for _, generator in pairs(generatorsFolder:GetChildren()) do
                    if generator:IsA("Model") then
                        if self.Enabled then
                            self:AddHighlight(generator)
                        else
                            self:RemoveHighlight(generator)
                        end
                    end
                end
            end
        end
    end
end

function generatorESP:Start()
    self.Enabled = true
    if self.Connection then self.Connection:Disconnect() end
    self.Connection = runService.Heartbeat:Connect(function()
        self:HighlightGenerators()
    end)
end

function generatorESP:Stop()
    self.Enabled = false
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    self:HighlightGenerators()
end

-- ============================================================
-- MONSTER ESP (แบบไฟล์ 25ms)
-- ============================================================
local monsterESP = {}
monsterESP.Enabled = false
monsterESP.Connection = nil

function monsterESP:AddHighlight(monster)
    if not monster:FindFirstChildOfClass("Highlight") then
        local highlight = Instance.new("Highlight")
        highlight.Parent = monster
        highlight.FillColor = Color3.new(1, 0, 0)
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.FillTransparency = 0.5
    end

    if not monster:FindFirstChild("NameTag") then
        local billboardGui = Instance.new("BillboardGui")
        billboardGui.Name = "NameTag"
        billboardGui.Parent = monster
        billboardGui.Size = UDim2.new(8, 0, 2, 0)
        billboardGui.AlwaysOnTop = true
        billboardGui.MaxDistance = 2000

        local textLabel = Instance.new("TextLabel")
        textLabel.Parent = billboardGui
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = monster.Name
        textLabel.TextColor3 = Color3.new(1, 0, 0)
        textLabel.TextScaled = false
        textLabel.Font = Enum.Font.RobotoMono

        local uiStroke = Instance.new("UIStroke")
        uiStroke.Parent = textLabel
        uiStroke.Thickness = 4
        uiStroke.Color = Color3.new(0, 0, 0)

        local uiGradient = Instance.new("UIGradient")
        uiGradient.Parent = textLabel
        uiGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 0.5, 0.5)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 0, 0))
        })
    end
end

function monsterESP:RemoveHighlight(monster)
    local highlight = monster:FindFirstChildOfClass("Highlight")
    if highlight then highlight:Destroy() end

    local nameTag = monster:FindFirstChild("NameTag")
    if nameTag then nameTag:Destroy() end
end

function monsterESP:HighlightMonsters()
    local currentRoom = getCurrentRoom()
    if not currentRoom then return end

    for _, item in pairs(currentRoom:GetChildren()) do
        if item:IsA("Model") then
            local monstersFolder = item:FindFirstChild("Monsters")
            if monstersFolder then
                for _, monster in pairs(monstersFolder:GetChildren()) do
                    if monster:IsA("Model") then
                        if self.Enabled then
                            self:AddHighlight(monster)
                        else
                            self:RemoveHighlight(monster)
                        end
                    end
                end
            end
        end
    end
end

function monsterESP:Start()
    self.Enabled = true
    if self.Connection then self.Connection:Disconnect() end
    self.Connection = runService.Heartbeat:Connect(function()
        self:HighlightMonsters()
    end)
end

function monsterESP:Stop()
    self.Enabled = false
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    self:HighlightMonsters()
end

-- ============================================================
-- ITEM ESP (แบบไฟล์ 25ms)
-- ============================================================
local itemESP = {}
itemESP.Enabled = false
itemESP.Connection = nil

local ITEM_FILL_COLOR    = Color3.new(0, 0, 1)
local ITEM_OUTLINE_COLOR = Color3.new(1, 1, 1)
local HEALTH_COLOR       = Color3.new(0, 1, 0)

function itemESP:AddHighlight(model)
    if not model:FindFirstChildOfClass("Highlight") then
        local isHealth = (model.Name == "HealthKit" or model.Name == "Bandage")
        local fillColor = isHealth and HEALTH_COLOR or ITEM_FILL_COLOR

        local highlight = Instance.new("Highlight")
        highlight.OutlineColor = ITEM_OUTLINE_COLOR
        highlight.FillColor = fillColor
        highlight.FillTransparency = 0.5
        highlight.Parent = model
    end

    if not model:FindFirstChild("NameTag") then
        local billboardGui = Instance.new("BillboardGui")
        billboardGui.Name = "NameTag"
        billboardGui.Parent = model
        billboardGui.Size = UDim2.new(8, 0, 2, 0)
        billboardGui.AlwaysOnTop = true
        billboardGui.MaxDistance = 2000

        local isHealth = (model.Name == "HealthKit" or model.Name == "Bandage")
        local textColor = isHealth and HEALTH_COLOR or ITEM_FILL_COLOR

        local textLabel = Instance.new("TextLabel")
        textLabel.Parent = billboardGui
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = model.Name
        textLabel.TextColor3 = textColor
        textLabel.TextScaled = false
        textLabel.Font = Enum.Font.RobotoMono

        local uiStroke = Instance.new("UIStroke")
        uiStroke.Parent = textLabel
        uiStroke.Thickness = 4
        uiStroke.Color = Color3.fromRGB(0, 0, 0)

        local uiGradient = Instance.new("UIGradient")
        uiGradient.Parent = textLabel
        uiGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, textColor:Lerp(Color3.new(1, 1, 1), 0.5)),
            ColorSequenceKeypoint.new(1, textColor)
        })
    end
end

function itemESP:RemoveHighlight(model)
    local highlight = model:FindFirstChildOfClass("Highlight")
    if highlight then highlight:Destroy() end

    local nameTag = model:FindFirstChild("NameTag")
    if nameTag then nameTag:Destroy() end
end

function itemESP:HighlightItems()
    local currentRoom = getCurrentRoom()
    if not currentRoom or not currentRoom:IsA("Folder") then return end

    for _, item in pairs(currentRoom:GetChildren()) do
        if item:IsA("Model") then
            local itemsFolder = item:FindFirstChild("Items")
            if itemsFolder and itemsFolder:IsA("Folder") then
                for _, subItem in pairs(itemsFolder:GetChildren()) do
                    if subItem:IsA("Model") then
                        if self.Enabled then
                            self:AddHighlight(subItem)
                        else
                            self:RemoveHighlight(subItem)
                        end
                    end
                end
            end
        end
    end
end

function itemESP:Start()
    self.Enabled = true
    if self.Connection then self.Connection:Disconnect() end
    self.Connection = runService.Heartbeat:Connect(function()
        self:HighlightItems()
    end)
end

function itemESP:Stop()
    self.Enabled = false
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    self:HighlightItems()
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

do
    local row = farmForm:Row({ SearchIndex = "Use Parabola" })
    row:Left():TitleStack({ Title = "Use Parabola TP", Subtitle = "วาร์ปแบบโค้ง 6 จังหวะ" })
    row:Right():Toggle({ Value = true, ValueChanged = function(_, v) autoFarm.UseParabola = v end })
end

-- Parabola Settings
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

-- Safety
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
    Min = 10, Max = 150, Default = 45, Suffix = "studs",
    OnChanged = function(v) autoFarm.SafeDistance = v end,
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
    row:Left():TitleStack({ Title = "Item ESP", Subtitle = "ไฮไลต์ไอเทม + Health เขียว" })
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
    SearchIndex = "Walk Speed Value",
    Title = "Walk Speed",
    Subtitle = "ค่าความเร็ว (default 16)",
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
        Subtitle = "Made by 09ms | v3.3 Target Finding 25ms",
    })
end
do
    local row = creditsForm:Row({ SearchIndex = "Bypass Status" })
    row:Left():TitleStack({ Title = "AC Bypass" })
    row:Right():Label({ Text = __bypassOk and "ACTIVE" or "INACTIVE" })
end

-- ============================================================
-- DONE
-- ============================================================
app:Notification({
    App = "999Ms HUB",
    Title = "Loaded Successfully",
    Subtitle = "999Ms HUB v3.3 | Target Finding 25ms",
    Icon = cascade.Symbols.checkmark,
    Duration = 5,
})

print("[999Ms HUB] ✅ v3.3 — Target Finding 25ms — โหลดสำเร็จ!")
print("[999Ms HUB] 🛡️ AC Bypass: " .. (__bypassOk and "ACTIVE" or "INACTIVE"))
print("[999Ms HUB] 📏 Window Size: " .. tostring(WIN_SIZE))
print("[999Ms HUB] 🌀 TP: PivotTo Parabola 6 steps")