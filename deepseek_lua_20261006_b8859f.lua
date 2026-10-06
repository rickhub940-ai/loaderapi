--[[
    █████╗  █████╗  █████╗ ███╗   ███╗███████╗
    ██╔══██╗██╔══██╗██╔══██╗████╗ ████║██╔════╝
    ███████║╚██████║╚██████║██╔████╔██║███████╗
    ██╔══██║ ╚═══██║ ╚═══██║██║╚██╔╝██║╚════██║
    ██║  ██║ █████╔╝ █████╔╝██║ ╚═╝ ██║███████║
    ╚═╝  ╚═╝ ╚════╝  ╚════╝ ╚═╝     ╚═╝╚══════╝
              999Ms HUB  v2.3
       BY. 009exe | Dandys World
   AC Bypass v2 (Rate-Limit) + TP 10 studs/tick
]]

-- ============================================================
-- [ 999MS HUB ] AC BYPASS v2 — ต้องอยู่บนสุดเสมอ
-- Rate-Limit + Name Filter
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
            if __now - __lastFire < __minGap then
                return nil
            end
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
-- SECTION 1: SAFETY & SERVICES
-- ============================================================
if not game:IsLoaded() then game.Loaded:Wait() end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local CoreGui           = game:GetService("CoreGui")
local Lighting          = game:GetService("Lighting")
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local LocalPlayer       = Players.LocalPlayer

if not ReplicatedStorage:FindFirstChild("Events") then
    warn("[999Ms HUB] ❌ กรุณาเข้าเกม Dandy's World ก่อนรันสคริปต์")
    return
end

-- ============================================================
-- SECTION 2: IMPORT CASCADE UI
-- ============================================================
local function importRelease(owner, repo, version, file)
    local tag = (version == "latest" and "latest/download" or "download/" .. version)
    return loadstring(game:HttpGetAsync(
        ("https://github.com/%s/%s/releases/%s/%s"):format(owner, repo, tag, file)
    ), file)()
end

local cascade
local ok, err = pcall(function()
    cascade = importRelease("cascadeui", "Cascade", "latest", "dist.luau")
end)

if not ok or not cascade then
    warn("[999Ms HUB] ❌ โหลด Cascade UI ไม่ได้: " .. tostring(err))
    return
end
task.wait(0.1)

-- ============================================================
-- SECTION 3: APP & WINDOW
-- ============================================================
local App = cascade.New({
    Theme      = cascade.Themes.Dark,
    Accent     = cascade.Accents.Purple,
    WindowPill = true,
})

local Window = App:Window({
    Title      = "999Ms HUB",
    Subtitle   = "BY. 009exe | Dandys World",
    Searching  = true,
    Draggable  = true,
    Resizable  = true,
    Dropshadow = true,
    UIBlur     = false,
    CanExit    = true,
    CanMinimize= true,
    CanZoom    = true,
})

local MainSection = Window:Section({
    Title      = "Main Menu",
    Disclosure = true,
    Expanded   = true,
})

local AutoFarmTab  = MainSection:Tab({ Title = "Auto Farm", Selected = true })
local VisualsTab   = MainSection:Tab({ Title = "Visuals" })
local MovementTab  = MainSection:Tab({ Title = "Movement" })
local TPTab        = MainSection:Tab({ Title = "TP" })
local SettingsTab  = MainSection:Tab({ Title = "Settings" })

local function Notify(title, subtitle, duration)
    pcall(function()
        App:Notification({
            App      = "999MS HUB",
            Title    = title,
            Subtitle = subtitle,
            Duration = duration or 3,
        })
    end)
end

-- ============================================================
-- SECTION 4: AUTO FARM MODULE
-- ============================================================
local AutoFarm = {
    Enabled        = false,
    AutoInteract   = true,
    AutoTeleport   = true,
    AutoElevator   = true,
    UseSafeZone    = true,
    SafeDistance   = 45,
    CachedGenerators = {},
    SafeZone       = nil,
}

function AutoFarm:Init()
    local events = ReplicatedStorage:WaitForChild("Events", 15)
    if events then
        local skillcheck = events:WaitForChild("SkillcheckUpdate", 10)
        if skillcheck then
            skillcheck.OnClientInvoke = function(target, ...)
                if target and target:GetAttribute("MinigameType") == "Circle" then
                    return { hit = true, circle = "great" }
                end
                return "supercomplete"
            end
        end
    end

    self.SafeZone = workspace:FindFirstChild("AutoGenSafeZone")
    if not self.SafeZone then
        self.SafeZone = Instance.new("Part")
        self.SafeZone.Name         = "AutoGenSafeZone"
        self.SafeZone.Size         = Vector3.new(50, 1, 50)
        self.SafeZone.Anchored     = true
        self.SafeZone.Transparency = 1
        self.SafeZone.CanCollide   = true
        self.SafeZone.Parent       = workspace
    end

    local function onDescendantAdded(desc)
        if desc:IsA("Model") and desc:GetAttribute("MinigameType") then
            self.CachedGenerators[desc] = true
        end
    end
    for _, d in ipairs(workspace:GetDescendants()) do onDescendantAdded(d) end
    workspace.DescendantAdded:Connect(onDescendantAdded)
    workspace.DescendantRemoving:Connect(function(d) self.CachedGenerators[d] = nil end)

    task.spawn(function()
        while task.wait(0.2) do
            if self.Enabled then pcall(function() self:Step() end) end
        end
    end)
end

function AutoFarm:GetNearestMonsterDistance(pos)
    local currentRoom = workspace:FindFirstChild("CurrentRoom")
    if not currentRoom then return math.huge end
    local targetMap
    for _, v in pairs(currentRoom:GetChildren()) do
        if v:IsA("Model") or v:IsA("Folder") then targetMap = v break end
    end
    if not targetMap then return math.huge end
    local monsters = targetMap:FindFirstChild("Monsters")
    if not monsters then return math.huge end
    local nearest = math.huge
    for _, m in pairs(monsters:GetChildren()) do
        if m:IsA("Model") then
            local pp = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
            if pp then
                local mag = (pp.Position - pos).Magnitude
                if mag < nearest then nearest = mag end
            end
        end
    end
    return nearest
end

function AutoFarm:GetGeneratorTargetCFrame(gen)
    local tp = gen:FindFirstChild("TeleportPositions") or gen:FindFirstChild("TreadmillTeleportPositions")
    if tp and #tp:GetChildren() > 0 then return tp:GetChildren()[1].CFrame end
    local single = gen:FindFirstChild("TeleportPosition") or gen:FindFirstChild("TreadmillTeleportPosition")
    if single then return single.CFrame end
    local pos = gen.PrimaryPart and gen.PrimaryPart.Position or gen:GetPivot().Position
    return CFrame.new(pos) * CFrame.new(0, 0, 4)
end

function AutoFarm:GoToSafeZone(character, hrp)
    if not self.UseSafeZone then return end
    local targetPos = hrp.Position
    local cachedGen = next(self.CachedGenerators)
    if cachedGen then
        targetPos = cachedGen.PrimaryPart and cachedGen.PrimaryPart.Position or cachedGen:GetPivot().Position
    end
    self.SafeZone.Position = Vector3.new(targetPos.X, targetPos.Y + 50, targetPos.Z)
    if math.abs(hrp.Position.Y - self.SafeZone.Position.Y) > 10 then
        character:PivotTo(self.SafeZone.CFrame * CFrame.new(0, 3, 0))
    end
end

function AutoFarm:Step()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local info = workspace:FindFirstChild("Info")
    local panic = info and info:FindFirstChild("Panic") and info.Panic.Value == true
    local isNearMonster = self:GetNearestMonsterDistance(hrp.Position) < self.SafeDistance
    local totalGens, brokenGens = 0, 0
    local isGeneratorActive, activeStats, bestGen = false, nil, nil
    local minMag = math.huge

    for gen in pairs(self.CachedGenerators) do
        if not gen:IsDescendantOf(workspace) then
            self.CachedGenerators[gen] = nil
        else
            totalGens = totalGens + 1
            local stats = gen:FindFirstChild("Stats")
            if stats then
                local completed    = stats:FindFirstChild("Completed")
                local activePlayer = stats:FindFirstChild("ActivePlayer")
                if activePlayer and activePlayer.Value == character then
                    isGeneratorActive = true
                    activeStats = stats
                end
                if completed and not completed.Value then
                    brokenGens = brokenGens + 1
                    if activePlayer and activePlayer.Value == nil then
                        local pos = gen.PrimaryPart and gen.PrimaryPart.Position or gen:GetPivot().Position
                        if self:GetNearestMonsterDistance(pos) >= self.SafeDistance then
                            local mag = (pos - hrp.Position).Magnitude
                            if mag < minMag then bestGen = gen minMag = mag end
                        end
                    end
                end
            end
        end
    end

    if isGeneratorActive and (isNearMonster or panic) then
        local stop = activeStats and activeStats:FindFirstChild("StopInteracting")
        if stop and stop:IsA("RemoteEvent") then stop:FireServer() end
        isGeneratorActive = false
    end

    if self.AutoElevator and (panic or (totalGens > 0 and brokenGens == 0)) then
        local elevators = workspace:FindFirstChild("Elevators")
        local elevator = elevators and elevators:FindFirstChild("Elevator")
        if elevator then
            local cf = elevator.PrimaryPart and elevator.PrimaryPart.CFrame or elevator:GetPivot()
            if (hrp.Position - cf.Position).Magnitude > 8 then
                character:PivotTo(cf * CFrame.new(0, 3, 0))
            end
        end
    elseif totalGens ~= 0 then
        if not isGeneratorActive and self.AutoTeleport then
            if bestGen then
                local target = self:GetGeneratorTargetCFrame(bestGen)
                if (target.Position - hrp.Position).Magnitude > 5 then
                    character:PivotTo(target)
                    task.wait(0.3)
                end
            else
                self:GoToSafeZone(character, hrp)
            end
        end
        if self.AutoInteract and math.abs(hrp.Position.Y - self.SafeZone.Position.Y) > 10 then
            for gen in pairs(self.CachedGenerators) do
                local stats = gen:FindFirstChild("Stats")
                if stats then
                    local c = stats:FindFirstChild("Completed")
                    local ap = stats:FindFirstChild("ActivePlayer")
                    if c and not c.Value and ap and (ap.Value == nil or ap.Value == character) then
                        local pos = gen.PrimaryPart and gen.PrimaryPart.Position or gen:GetPivot().Position
                        local prompt = gen:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if prompt and prompt.Enabled
                            and (pos - hrp.Position).Magnitude <= prompt.MaxActivationDistance + 2 then
                            pcall(function() fireproximityprompt(prompt, 1) end)
                        end
                    end
                end
            end
        end
    end
end

AutoFarm:Init()

-- ============================================================
-- SECTION 5: GENERATOR ESP  (แดง = ยังไม่ซ่อม / เขียว = ซ่อมแล้ว)
-- ============================================================
local GeneratorESP = {
    Enabled       = false,
    BrokenColor   = Color3.fromRGB(255, 40, 40),
    FixedColor    = Color3.fromRGB(0, 255, 80),
    Objects       = {},
    ValueConns    = {},
    CurrentFolder = nil,
    Connections   = {},
}

function GeneratorESP:GetCurrentMap()
    local r = workspace:FindFirstChild("CurrentRoom")
    if not r then return nil end
    for _, v in pairs(r:GetChildren()) do
        if v:IsA("Model") or v:IsA("Folder") then return v end
    end
end
function GeneratorESP:GetGeneratorsFolder()
    local m = self:GetCurrentMap()
    return m and m:FindFirstChild("Generators")
end

function GeneratorESP:GetColor(gen)
    local stats = gen:FindFirstChild("Stats")
    local completed = stats and stats:FindFirstChild("Completed")
    if completed and completed.Value == true then
        return self.FixedColor
    end
    return self.BrokenColor
end

function GeneratorESP:ApplyColor(gen)
    local obj = self.Objects[gen]
    if not obj then return end
    local c = self:GetColor(gen)
    obj.Highlight.FillColor = c
    obj.Highlight.OutlineColor = c
    if obj.Label then obj.Label.TextColor3 = c end
    if obj.BG then obj.BG.BackgroundColor3 = c end
end

function GeneratorESP:AddESP(gen)
    if not self.Enabled or self.Objects[gen] then return end
    local color = self:GetColor(gen)

    local highlight = Instance.new("Highlight")
    highlight.Adornee = gen
    highlight.FillColor = color
    highlight.FillTransparency = 0.55
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = CoreGui

    local pp = gen.PrimaryPart or gen:FindFirstChildWhichIsA("BasePart")
    local billboard, label, bg
    if pp then
        billboard = Instance.new("BillboardGui")
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.new(0, 130, 0, 26)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.LightInfluence = 0
        billboard.Adornee = pp
        billboard.Parent = CoreGui

        bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = color
        bg.BackgroundTransparency = 0.15
        bg.BorderSizePixel = 0
        bg.Parent = billboard

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = bg

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Thickness = 1.2
        stroke.Transparency = 0.3
        stroke.Parent = bg

        label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 1, 0)
        label.Font = Enum.Font.GothamBold
        label.Text = "🔧 Generator"
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 13
        label.TextStrokeTransparency = 0.5
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Parent = bg
    end

    self.Objects[gen] = { Highlight = highlight, Billboard = billboard, Label = label, BG = bg }

    local stats = gen:FindFirstChild("Stats")
    local completed = stats and stats:FindFirstChild("Completed")
    if completed then
        local conn = completed:GetPropertyChangedSignal("Value"):Connect(function()
            self:ApplyColor(gen)
            if label then
                label.Text = completed.Value and "✅ Fixed" or "🔧 Generator"
            end
        end)
        self.ValueConns[gen] = conn
    end

    if label then
        label.Text = (completed and completed.Value) and "✅ Fixed" or "🔧 Generator"
    end
end

function GeneratorESP:RemoveESP(gen)
    if self.Objects[gen] then
        if self.Objects[gen].Highlight then self.Objects[gen].Highlight:Destroy() end
        if self.Objects[gen].Billboard then self.Objects[gen].Billboard:Destroy() end
        self.Objects[gen] = nil
    end
    if self.ValueConns[gen] then
        self.ValueConns[gen]:Disconnect()
        self.ValueConns[gen] = nil
    end
end

function GeneratorESP:ClearAll()
    for gen in pairs(self.Objects) do self:RemoveESP(gen) end
end

function GeneratorESP:Scan()
    if not self.Enabled then return end
    local folder = self:GetGeneratorsFolder()
    if not folder then self:ClearAll() return end
    for _, v in pairs(folder:GetChildren()) do
        if v:IsA("Model") or v:IsA("BasePart") then self:AddESP(v) end
    end
    for gen in pairs(self.Objects) do
        if not gen.Parent or gen.Parent ~= folder then self:RemoveESP(gen) end
    end
end

function GeneratorESP:ConnectFolder()
    local folder = self:GetGeneratorsFolder()
    if folder == self.CurrentFolder then return end
    if self.Connections.ChildAdded   then self.Connections.ChildAdded:Disconnect()   end
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

function GeneratorESP:Start() self.Enabled = true self:ConnectFolder() self:Scan() end

function GeneratorESP:Stop()
    self.Enabled = false
    self:ClearAll()
    if self.Connections.ChildAdded   then self.Connections.ChildAdded:Disconnect()   end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end

-- ============================================================
-- SECTION 6: MONSTER ESP
-- ============================================================
local MonsterESP = {
    Enabled       = false,
    Color         = Color3.fromRGB(255, 0, 0),
    Objects       = {},
    CurrentFolder = nil,
    Connections   = {},
}

function MonsterESP:CleanName(name)
    if name:sub(-7) == "Monster" then return name:sub(1, -8) end
    return name
end

function MonsterESP:GetCurrentMap()
    local r = workspace:FindFirstChild("CurrentRoom")
    if not r then return nil end
    for _, v in pairs(r:GetChildren()) do
        if v:IsA("Model") or v:IsA("Folder") then return v end
    end
end
function MonsterESP:GetMonstersFolder()
    local m = self:GetCurrentMap()
    return m and m:FindFirstChild("Monsters")
end

function MonsterESP:AddESP(monster)
    if not self.Enabled or self.Objects[monster] then return end
    local pp = monster.PrimaryPart or monster:FindFirstChildWhichIsA("BasePart")
    if not pp then
        local conn
        conn = monster.ChildAdded:Connect(function(c)
            if c:IsA("BasePart") then conn:Disconnect() self:AddESP(monster) end
        end)
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = monster
    highlight.FillColor = self.Color
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = self.Color
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = CoreGui

    local billboard = Instance.new("BillboardGui")
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 150, 0, 26)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.LightInfluence = 0
    billboard.Adornee = pp
    billboard.Parent = CoreGui

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = self.Color
    bg.BackgroundTransparency = 0.25
    bg.BorderSizePixel = 0
    bg.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = bg

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1.2
    stroke.Transparency = 0.3
    stroke.Parent = bg

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.Text = "👹 " .. self:CleanName(monster.Name)
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = bg

    self.Objects[monster] = { Highlight = highlight, Billboard = billboard, Label = label, BG = bg }
end

function MonsterESP:RemoveESP(monster)
    if self.Objects[monster] then
        self.Objects[monster].Highlight:Destroy()
        self.Objects[monster].Billboard:Destroy()
        self.Objects[monster] = nil
    end
end

function MonsterESP:ClearAll()
    for m in pairs(self.Objects) do self:RemoveESP(m) end
end

function MonsterESP:Scan()
    if not self.Enabled then return end
    local folder = self:GetMonstersFolder()
    if not folder then self:ClearAll() return end
    for _, v in pairs(folder:GetChildren()) do
        if v:IsA("Model") then self:AddESP(v) end
    end
    for m in pairs(self.Objects) do
        if not m.Parent or m.Parent ~= folder then self:RemoveESP(m) end
    end
end

function MonsterESP:ConnectFolder()
    local folder = self:GetMonstersFolder()
    if folder == self.CurrentFolder then return end
    if self.Connections.ChildAdded   then self.Connections.ChildAdded:Disconnect()   end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = folder
    if not folder then return end
    self.Connections.ChildAdded = folder.ChildAdded:Connect(function(c)
        if c:IsA("Model") and self.Enabled then task.wait(0.1) self:AddESP(c) end
    end)
    self.Connections.ChildRemoved = folder.ChildRemoved:Connect(function(c) self:RemoveESP(c) end)
end

function MonsterESP:Start() self.Enabled = true self:ConnectFolder() self:Scan() end

function MonsterESP:Stop()
    self.Enabled = false
    self:ClearAll()
    if self.Connections.ChildAdded   then self.Connections.ChildAdded:Disconnect()   end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end

function MonsterESP:UpdateColor(color)
    self.Color = color
    for _, obj in pairs(self.Objects) do
        if obj.Highlight and obj.Highlight.Parent then
            obj.Highlight.FillColor = color
            obj.Highlight.OutlineColor = color
        end
        if obj.BG then obj.BG.BackgroundColor3 = color end
    end
end

-- ============================================================
-- SECTION 7: ITEM ESP (การ์ดสวย + ไอคอน + สีตามชนิด)
-- ============================================================
local ItemESP = {
    Enabled = false,
    Objects = {},
    CurrentFolder = nil,
    Connections = {},
}

local ITEM_STYLE = {
    HealthKit = { color = Color3.fromRGB(255, 80, 120), icon = "❤",  label = "Health Kit" },
    Bandage   = { color = Color3.fromRGB(120, 255, 140), icon = "✚",  label = "Bandage" },
    Medkit    = { color = Color3.fromRGB(80, 220, 255),  icon = "❤",  label = "Medkit" },
    Tape      = { color = Color3.fromRGB(255, 210, 60),  icon = "◎",  label = "Tape" },
    Gumball   = { color = Color3.fromRGB(255, 120, 200), icon = "●",  label = "Gumball" },
    Flashlight= { color = Color3.fromRGB(255, 240, 150), icon = "🔦", label = "Flashlight" },
    Key       = { color = Color3.fromRGB(255, 200, 80),  icon = "🗝",  label = "Key" },
    Battery   = { color = Color3.fromRGB(180, 255, 80),  icon = "🔋", label = "Battery" },
    Box       = { color = Color3.fromRGB(200, 180, 140), icon = "📦", label = "Box" },
}
local DEFAULT_ITEM_STYLE = { color = Color3.fromRGB(120, 200, 255), icon = "◆", label = nil }

function ItemESP:GetCurrentMap()
    local r = workspace:FindFirstChild("CurrentRoom")
    if not r then return nil end
    for _, v in pairs(r:GetChildren()) do
        if v:IsA("Model") or v:IsA("Folder") then return v end
    end
end
function ItemESP:GetItemsFolder()
    local m = self:GetCurrentMap()
    return m and m:FindFirstChild("Items")
end

function ItemESP:GetStyle(name)
    for key, style in pairs(ITEM_STYLE) do
        if name:find(key) then return style, key end
    end
    return DEFAULT_ITEM_STYLE, name
end

function ItemESP:AddESP(item)
    if not self.Enabled or self.Objects[item] then return end
    local pp = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
    if not pp or not pp:IsA("BasePart") then
        local conn
        conn = item.ChildAdded:Connect(function(c)
            if c:IsA("BasePart") then conn:Disconnect() self:AddESP(item) end
        end)
        return
    end

    local style = self:GetStyle(item.Name)

    local highlight = Instance.new("Highlight")
    highlight.Adornee = item:IsA("Model") and item or pp
    highlight.FillColor = style.color
    highlight.FillTransparency = 0.7
    highlight.OutlineColor = style.color
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = CoreGui

    local billboard = Instance.new("BillboardGui")
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 170, 0, 34)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.LightInfluence = 0
    billboard.Adornee = pp
    billboard.Parent = CoreGui

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 1, 0)
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    card.BackgroundTransparency = 0.15
    card.BorderSizePixel = 0
    card.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = style.color
    stroke.Thickness = 1.5
    stroke.Transparency = 0.15
    stroke.Parent = card

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, style.color),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 28)),
    })
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.65),
        NumberSequenceKeypoint.new(0.6, 0.95),
        NumberSequenceKeypoint.new(1, 1),
    })
    gradient.Rotation = 90
    gradient.Parent = card

    local icon = Instance.new("TextLabel")
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(0, 34, 1, 0)
    icon.Position = UDim2.new(0, 4, 0, 0)
    icon.Font = Enum.Font.GothamBlack
    icon.Text = style.icon
    icon.TextColor3 = style.color
    icon.TextSize = 20
    icon.TextStrokeTransparency = 0.5
    icon.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    icon.Parent = card

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -44, 1, 0)
    label.Position = UDim2.new(0, 40, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.Text = style.label or item.Name:gsub("(%l)(%u)", "%1 %2")
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextStrokeTransparency = 0.6
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = card

    self.Objects[item] = {
        Highlight = highlight,
        Billboard = billboard,
        Card = card,
        Icon = icon,
        Label = label,
        Style = style,
    }
end

function ItemESP:RemoveESP(item)
    if self.Objects[item] then
        if self.Objects[item].Highlight then self.Objects[item].Highlight:Destroy() end
        if self.Objects[item].Billboard then self.Objects[item].Billboard:Destroy() end
        self.Objects[item] = nil
    end
end

function ItemESP:ClearAll()
    for i in pairs(self.Objects) do self:RemoveESP(i) end
end

function ItemESP:Scan()
    if not self.Enabled then return end
    local folder = self:GetItemsFolder()
    if not folder then self:ClearAll() return end
    for _, v in pairs(folder:GetChildren()) do
        if v:IsA("Model") or v:IsA("BasePart") then self:AddESP(v) end
    end
    for i in pairs(self.Objects) do
        if not i.Parent or i.Parent ~= folder then self:RemoveESP(i) end
    end
end

function ItemESP:ConnectFolder()
    local folder = self:GetItemsFolder()
    if folder == self.CurrentFolder then return end
    if self.Connections.ChildAdded   then self.Connections.ChildAdded:Disconnect()   end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = folder
    if not folder then return end
    self.Connections.ChildAdded = folder.ChildAdded:Connect(function(c)
        if (c:IsA("Model") or c:IsA("BasePart")) and self.Enabled then
            task.wait(0.1) self:AddESP(c)
        end
    end)
    self.Connections.ChildRemoved = folder.ChildRemoved:Connect(function(c) self:RemoveESP(c) end)
end

function ItemESP:Start() self.Enabled = true self:ConnectFolder() self:Scan() end

function ItemESP:Stop()
    self.Enabled = false
    self:ClearAll()
    if self.Connections.ChildAdded   then self.Connections.ChildAdded:Disconnect()   end
    if self.Connections.ChildRemoved then self.Connections.ChildRemoved:Disconnect() end
    self.CurrentFolder = nil
end

-- ============================================================
-- SECTION 8: CAMERA & LIGHTING
-- ============================================================
local Camera = {
    FOVEnabled = false,
    FOV = 70,
    FullbrightEnabled = false,
    LightingConns = {},
    OriginalLighting = {},
}

function Camera:Init()
    RunService.RenderStepped:Connect(function()
        if self.FOVEnabled then
            local cam = workspace.CurrentCamera
            if cam and cam.FieldOfView ~= self.FOV then cam.FieldOfView = self.FOV end
        end
    end)
end
function Camera:SetFOV(fov) self.FOV = fov end
function Camera:ToggleFOV(on) self.FOVEnabled = on end
function Camera:ToggleFullbright(on)
    self.FullbrightEnabled = on
    if on then
        self.OriginalLighting = {
            Brightness     = Lighting.Brightness,
            ClockTime      = Lighting.ClockTime,
            FogEnd         = Lighting.FogEnd,
            GlobalShadows  = Lighting.GlobalShadows,
            OutdoorAmbient = Lighting.OutdoorAmbient,
        }
        local function apply()
            Lighting.Brightness = 1
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        end
        apply()
        self.LightingConns.Brightness     = Lighting:GetPropertyChangedSignal("Brightness"):Connect(apply)
        self.LightingConns.ClockTime      = Lighting:GetPropertyChangedSignal("ClockTime"):Connect(apply)
        self.LightingConns.FogEnd         = Lighting:GetPropertyChangedSignal("FogEnd"):Connect(apply)
        self.LightingConns.GlobalShadows  = Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(apply)
        self.LightingConns.OutdoorAmbient = Lighting:GetPropertyChangedSignal("OutdoorAmbient"):Connect(apply)
    else
        for _, c in pairs(self.LightingConns) do c:Disconnect() end
        self.LightingConns = {}
        if self.OriginalLighting.Brightness then
            Lighting.Brightness     = self.OriginalLighting.Brightness
            Lighting.ClockTime      = self.OriginalLighting.ClockTime
            Lighting.FogEnd         = self.OriginalLighting.FogEnd
            Lighting.GlobalShadows  = self.OriginalLighting.GlobalShadows
            Lighting.OutdoorAmbient = self.OriginalLighting.OutdoorAmbient
        end
    end
end
Camera:Init()

-- ============================================================
-- SECTION 9: INFINITY JUMP
-- ============================================================
local InfinityJump = { Enabled = false, JumpForce = 50 }
function InfinityJump:Jump()
    if not self.Enabled then return end
    local ch = LocalPlayer.Character
    if not ch then return end
    local hrp = ch:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    hrp.Velocity = Vector3.new(hrp.Velocity.X, self.JumpForce, hrp.Velocity.Z)
end
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Space then InfinityJump:Jump() end
end)

-- ============================================================
-- SECTION 10: WALK SPEED
-- ============================================================
local WalkSpeed = { Enabled = false, Speed = 16, LoopConn = nil, CharConn = nil }

local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildWhichIsA("Humanoid")
end
local function applySpeed(sp)
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = sp end
end

function WalkSpeed:Start()
    self.Enabled = true
    applySpeed(self.Speed)
    local hum = getHumanoid()
    if hum then
        if self.LoopConn then self.LoopConn:Disconnect() end
        self.LoopConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if self.Enabled then applySpeed(self.Speed) end
        end)
    end
    if self.CharConn then self.CharConn:Disconnect() end
    self.CharConn = LocalPlayer.CharacterAdded:Connect(function(ch)
        if not self.Enabled then return end
        local newHum = ch:WaitForChild("Humanoid")
        applySpeed(self.Speed)
        if self.LoopConn then self.LoopConn:Disconnect() end
        self.LoopConn = newHum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if self.Enabled then applySpeed(self.Speed) end
        end)
    end)
end

function WalkSpeed:Stop()
    self.Enabled = false
    if self.LoopConn then self.LoopConn:Disconnect() self.LoopConn = nil end
    if self.CharConn then self.CharConn:Disconnect() self.CharConn = nil end
    applySpeed(16)
end

function WalkSpeed:SetSpeed(v)
    self.Speed = v
    if self.Enabled then applySpeed(v) end
end

-- ============================================================
-- SECTION 11: TP WALK
-- ============================================================
local TPWalk = { Enabled = false, Speed = 1, Conn = nil }
function TPWalk:Start()
    self.Enabled = true
    if self.Conn then self.Conn:Disconnect() end
    self.Conn = RunService.Heartbeat:Connect(function(dt)
        local ch = LocalPlayer.Character
        local hum = ch and ch:FindFirstChildWhichIsA("Humanoid")
        if not (ch and hum and hum.Parent) then return end
        if hum.MoveDirection.Magnitude > 0 then
            ch:TranslateBy(hum.MoveDirection * self.Speed * dt * 10)
        end
    end)
end
function TPWalk:Stop()
    self.Enabled = false
    if self.Conn then self.Conn:Disconnect() self.Conn = nil end
end
function TPWalk:SetSpeed(v)
    self.Speed = v
    if self.Enabled then self:Stop() self:Start() end
end

-- ============================================================
-- SECTION 12: CUSTOM TP (วาร์ป 10 studs/tick)
-- ============================================================
local CustomTP = {
    Speed     = 10,
    Threshold = 5,
    MaxTicks  = 300,
    Active    = false,
    Target    = nil,
    TickConn  = nil,
}

function CustomTP:Start(targetCFrame)
    if not targetCFrame then return end
    self:Stop()
    self.Target = targetCFrame
    self.Active = true
    local tickCount = 0

    self.TickConn = RunService.Heartbeat:Connect(function(dt)
        if not self.Active then return end
        tickCount = tickCount + 1
        if tickCount > self.MaxTicks then self:Stop() return end

        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then self:Stop() return end

        local currentPos = hrp.Position
        local targetPos  = self.Target.Position
        local direction  = (targetPos - currentPos)
        local distance   = direction.Magnitude

        if distance <= self.Threshold then
            pcall(function()
                char:PivotTo(CFrame.new(targetPos) * CFrame.new(0, 3, 0))
            end)
            self:Stop()
            return
        end

        local step = direction.Unit * math.min(self.Speed, distance)
        local newCFrame = CFrame.new(currentPos + step) * (hrp.CFrame - hrp.CFrame.Position)

        pcall(function()
            char:PivotTo(newCFrame)
        end)
    end)
end

function CustomTP:Stop()
    self.Active = false
    self.Target = nil
    if self.TickConn then
        self.TickConn:Disconnect()
        self.TickConn = nil
    end
end

function CustomTP:ToPart(partName)
    local part = workspace:FindFirstChild(partName, true)
    if not part or not part:IsA("BasePart") then
        Notify("TP", "❌ ไม่เจอ Part: " .. tostring(partName))
        return
    end
    self:Start(part.CFrame)
    Notify("TP", "🚀 กำลังวาร์ปไป " .. partName)
end

function CustomTP:ToPlayer(playerName)
    local target = Players:FindFirstChild(playerName)
    if not target or not target.Character or not target.Character.PrimaryPart then
        Notify("TP", "❌ ไม่เจอ Player: " .. tostring(playerName))
        return
    end
    self:Start(target.Character.PrimaryPart.CFrame)
    Notify("TP", "🚀 กำลังวาร์ปไป " .. playerName)
end

function CustomTP:ToCoords(x, y, z)
    self:Start(CFrame.new(x, y, z))
    Notify("TP", string.format("🚀 กำลังวาร์ปไป (%.0f, %.0f, %.0f)", x, y, z))
end

-- ============================================================
-- SECTION 13: COLOR PRESETS
-- ============================================================
local COLOR_MAP = {
    Green  = Color3.fromRGB(0, 255, 0),
    Red    = Color3.fromRGB(255, 0, 0),
    Blue   = Color3.fromRGB(0, 150, 255),
    Yellow = Color3.fromRGB(255, 255, 0),
    Purple = Color3.fromRGB(180, 0, 255),
    Cyan   = Color3.fromRGB(0, 255, 255),
    Orange = Color3.fromRGB(255, 140, 0),
    Pink   = Color3.fromRGB(255, 105, 180),
    White  = Color3.fromRGB(255, 255, 255),
    Black  = Color3.fromRGB(0, 0, 0),
}
local COLOR_NAMES = { "Green","Red","Blue","Yellow","Purple","Cyan","Orange","Pink","White","Black" }

-- ============================================================
-- SECTION 14: UI — AUTO FARM TAB
-- ============================================================
local afMain = AutoFarmTab:PageSection({ Title = "Main", Subtitle = "ปรับการทำงานหลักของ Auto Farm" })
local afMainForm = afMain:Form()
do
    local row = afMainForm:Row({ SearchIndex = "Enable Auto Farm" })
    row:Left():TitleStack({ Title = "Enable Auto Farm", Subtitle = "เปิด/ปิดระบบ Auto Farm ทั้งหมด" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v)
            AutoFarm.Enabled = v
            Notify("Auto Farm", v and "✅ Enabled" or "⛔ Disabled")
        end,
    })
end
do
    local row = afMainForm:Row({ SearchIndex = "Auto Fix Generators" })
    row:Left():TitleStack({ Title = "Auto Fix Generators", Subtitle = "ซ่อม Generator อัตโนมัติ" })
    row:Right():Toggle({
        Value = true,
        ValueChanged = function(_, v) AutoFarm.AutoInteract = v end,
    })
end
do
    local row = afMainForm:Row({ SearchIndex = "Auto TP" })
    row:Left():TitleStack({ Title = "Auto TP to Generators", Subtitle = "วาร์ปไป Generator ที่ใกล้ที่สุด" })
    row:Right():Toggle({
        Value = true,
        ValueChanged = function(_, v) AutoFarm.AutoTeleport = v end,
    })
end
do
    local row = afMainForm:Row({ SearchIndex = "Auto Elevator" })
    row:Left():TitleStack({ Title = "Auto Elevator", Subtitle = "วาร์ปไป Elevator เมื่อเสร็จทั้งหมด" })
    row:Right():Toggle({
        Value = true,
        ValueChanged = function(_, v) AutoFarm.AutoElevator = v end,
    })
end

local afSafety = AutoFarmTab:PageSection({ Title = "Safety", Subtitle = "ตั้งค่าความปลอดภัยจากมอนสเตอร์" })
local afSafetyForm = afSafety:Form()
do
    local row = afSafetyForm:Row({ SearchIndex = "Auto Save from Monsters" })
    row:Left():TitleStack({ Title = "Auto Save from Monsters", Subtitle = "วาร์ปขึ้นฟ้าเมื่อมอนสเตอร์ใกล้" })
    row:Right():Toggle({
        Value = true,
        ValueChanged = function(_, v) AutoFarm.UseSafeZone = v end,
    })
end
do
    local row = afSafetyForm:Row({ SearchIndex = "Safe Distance" })
    row:Left():TitleStack({ Title = "Safe Distance", Subtitle = "ระยะที่ถือว่ามอนใกล้เกินไป" })
    row:Right():Slider({
        Minimum = 10, Maximum = 150, Value = 45,
        ValueChanged = function(_, v) AutoFarm.SafeDistance = v end,
    })
end

-- ============================================================
-- SECTION 15: UI — VISUALS TAB
-- ============================================================
local vGenSec = VisualsTab:PageSection({
    Title = "Generator ESP",
    Subtitle = "🔴 แดง = ยังไม่ซ่อม   🟢 เขียว = ซ่อมแล้ว (อัปเดตอัตโนมัติ)",
})
local vGenForm = vGenSec:Form()
do
    local row = vGenForm:Row({ SearchIndex = "Generator ESP" })
    row:Left():TitleStack({ Title = "Generator ESP", Subtitle = "เปิด/ปิด" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v)
            if v then GeneratorESP:Start() Notify("Generator ESP", "✅ Enabled") else GeneratorESP:Stop() end
        end,
    })
end
do
    local row = vGenForm:Row({ SearchIndex = "Broken Color" })
    row:Left():TitleStack({ Title = "Broken Color", Subtitle = "สีของเครื่องที่ยังไม่ซ่อม (ค่าเริ่มต้น แดง)" })
    row:Right():PopUpButton({
        Options = COLOR_NAMES,
        ValueChanged = function(_, v)
            local name = COLOR_NAMES[v]
            if name then GeneratorESP.BrokenColor = COLOR_MAP[name] end
        end,
    })
end
do
    local row = vGenForm:Row({ SearchIndex = "Fixed Color" })
    row:Left():TitleStack({ Title = "Fixed Color", Subtitle = "สีของเครื่องที่ซ่อมแล้ว (ค่าเริ่มต้น เขียว)" })
    row:Right():PopUpButton({
        Options = COLOR_NAMES,
        ValueChanged = function(_, v)
            local name = COLOR_NAMES[v]
            if name then GeneratorESP.FixedColor = COLOR_MAP[name] end
        end,
    })
end

local vMonSec = VisualsTab:PageSection({ Title = "Monster ESP", Subtitle = "ไฮไลต์มอนสเตอร์ + ชื่อ" })
local vMonForm = vMonSec:Form()
do
    local row = vMonForm:Row({ SearchIndex = "Monster ESP" })
    row:Left():TitleStack({ Title = "Monster ESP", Subtitle = "เปิด/ปิด" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v)
            if v then MonsterESP:Start() Notify("Monster ESP", "✅ Enabled") else MonsterESP:Stop() end
        end,
    })
end
do
    local row = vMonForm:Row({ SearchIndex = "Monster Color" })
    row:Left():TitleStack({ Title = "Monster Color", Subtitle = "สีของ ESP" })
    row:Right():PopUpButton({
        Options = COLOR_NAMES,
        ValueChanged = function(_, v)
            local name = COLOR_NAMES[v]
            if name then MonsterESP:UpdateColor(COLOR_MAP[name]) end
        end,
    })
end

local vItemSec = VisualsTab:PageSection({ Title = "Item ESP", Subtitle = "✨ การ์ดสวย + ไอคอน + สีตามชนิดไอเทม" })
local vItemForm = vItemSec:Form()
do
    local row = vItemForm:Row({ SearchIndex = "Item ESP" })
    row:Left():TitleStack({ Title = "Item ESP", Subtitle = "เปิด/ปิด" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v)
            if v then ItemESP:Start() Notify("Item ESP", "✅ Enabled") else ItemESP:Stop() end
        end,
    })
end

local vCamSec = VisualsTab:PageSection({ Title = "Camera & Lighting", Subtitle = "FOV และ Fullbright" })
local vCamForm = vCamSec:Form()
do
    local row = vCamForm:Row({ SearchIndex = "Custom FOV" })
    row:Left():TitleStack({ Title = "Enable Custom FOV", Subtitle = "Override ค่า FOV" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v) Camera:ToggleFOV(v) end,
    })
end
do
    local row = vCamForm:Row({ SearchIndex = "Field Of View" })
    row:Left():TitleStack({ Title = "Field Of View", Subtitle = "ปรับ FOV กล้อง" })
    row:Right():Slider({
        Minimum = 30, Maximum = 120, Value = 70,
        ValueChanged = function(_, v) Camera:SetFOV(v) end,
    })
end
do
    local row = vCamForm:Row({ SearchIndex = "Fullbright" })
    row:Left():TitleStack({ Title = "Fullbright", Subtitle = "สว่างทั้งเกม ลบหมอก" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v) Camera:ToggleFullbright(v) end,
    })
end

-- ============================================================
-- SECTION 16: UI — MOVEMENT TAB
-- ============================================================
local mJumpSec = MovementTab:PageSection({ Title = "Infinity Jump", Subtitle = "กระโดดได้ไม่จำกัด" })
local mJumpForm = mJumpSec:Form()
do
    local row = mJumpForm:Row({ SearchIndex = "Infinity Jump" })
    row:Left():TitleStack({ Title = "Infinity Jump", Subtitle = "กด SPACE เพื่อกระโดด" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v)
            InfinityJump.Enabled = v
            if v then Notify("Infinity Jump", "✅ กด Space เพื่อกระโดด") end
        end,
    })
end
do
    local row = mJumpForm:Row({ SearchIndex = "Jump Force" })
    row:Left():TitleStack({ Title = "Jump Force", Subtitle = "ความสูงที่กระโดด" })
    row:Right():Slider({
        Minimum = 10, Maximum = 100, Value = 50,
        ValueChanged = function(_, v) InfinityJump.JumpForce = v end,
    })
end

local mSpeedSec = MovementTab:PageSection({ Title = "Walk Speed", Subtitle = "บังคับความเร็วเดิน" })
local mSpeedForm = mSpeedSec:Form()
do
    local row = mSpeedForm:Row({ SearchIndex = "WalkSpeed" })
    row:Left():TitleStack({ Title = "WalkSpeed", Subtitle = "บังคับ WalkSpeed ให้คงที่" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v)
            if v then WalkSpeed:Start() Notify("Walk Speed", "✅ Enabled") else WalkSpeed:Stop() end
        end,
    })
end
do
    local row = mSpeedForm:Row({ SearchIndex = "Speed" })
    row:Left():TitleStack({ Title = "Speed", Subtitle = "ค่า WalkSpeed (ปกติ 16)" })
    row:Right():Slider({
        Minimum = 1, Maximum = 500, Value = 16,
        ValueChanged = function(_, v) WalkSpeed:SetSpeed(v) end,
    })
end

local mTpSec = MovementTab:PageSection({ Title = "TP Walk", Subtitle = "วาร์ปไปข้างหน้าทุกเฟรม" })
local mTpForm = mTpSec:Form()
do
    local row = mTpForm:Row({ SearchIndex = "TP Walk" })
    row:Left():TitleStack({ Title = "TP Walk", Subtitle = "วาร์ปไปข้างหน้าแบบต่อเนื่อง" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v)
            if v then TPWalk:Start() Notify("TP Walk", "✅ Enabled") else TPWalk:Stop() end
        end,
    })
end
do
    local row = mTpForm:Row({ SearchIndex = "TP Speed" })
    row:Left():TitleStack({ Title = "TP Speed", Subtitle = "ความเร็ว (1 = ปกติ)" })
    row:Right():Slider({
        Minimum = 1, Maximum = 10, Value = 1,
        ValueChanged = function(_, v) TPWalk:SetSpeed(v) end,
    })
end

-- ============================================================
-- SECTION 17: UI — TP TAB
-- ============================================================
local tpMainSec = TPTab:PageSection({
    Title = "Custom TP",
    Subtitle = "วาร์ป 10 studs/tick (เรียบเนียน)",
})
local tpForm = tpMainSec:Form()

local tpInputPart, tpInputPlayer
do
    local row = tpForm:Row({ SearchIndex = "Part Name" })
    row:Left():TitleStack({ Title = "Part Name", Subtitle = "ชื่อ Part ที่จะวาร์ปไป" })
    tpInputPart = row:Right():TextField({
        Placeholder = "เช่น hee, Base, Exit...",
        ValueChanged = function(self, v) self.Value = v end,
    })
end

do
    local row = tpForm:Row({ SearchIndex = "TP to Part" })
    row:Left():TitleStack({ Title = "TP to Part", Subtitle = "วาร์ปไปหา Part ที่ระบุ" })
    row:Right():Button({
        Label = "GO",
        State = "Primary",
        Pushed = function()
            local name = tpInputPart and tpInputPart.Value or ""
            if name ~= "" then CustomTP:ToPart(name)
            else Notify("TP", "⚠ กรุณาใส่ชื่อ Part ก่อน") end
        end,
    })
end

do
    local row = tpForm:Row({ SearchIndex = "Player Name" })
    row:Left():TitleStack({ Title = "Player Name", Subtitle = "ชื่อผู้เล่นที่จะวาร์ปไปหา" })
    tpInputPlayer = row:Right():TextField({
        Placeholder = "เช่น Toon, Noob123...",
        ValueChanged = function(self, v) self.Value = v end,
    })
end

do
    local row = tpForm:Row({ SearchIndex = "TP to Player" })
    row:Left():TitleStack({ Title = "TP to Player", Subtitle = "วาร์ปไปหาผู้เล่น" })
    row:Right():Button({
        Label = "GO",
        State = "Primary",
        Pushed = function()
            local name = tpInputPlayer and tpInputPlayer.Value or ""
            if name ~= "" then CustomTP:ToPlayer(name)
            else Notify("TP", "⚠ กรุณาใส่ชื่อ Player ก่อน") end
        end,
    })
end

local tpCoordX, tpCoordY, tpCoordZ
do
    local row = tpForm:Row({ SearchIndex = "X Coord" })
    row:Left():TitleStack({ Title = "X Coord", Subtitle = "พิกัด X" })
    tpCoordX = row:Right():TextField({
        Placeholder = "0",
        ValueChanged = function(self, v) self.Value = v end,
    })
end
do
    local row = tpForm:Row({ SearchIndex = "Y Coord" })
    row:Left():TitleStack({ Title = "Y Coord", Subtitle = "พิกัด Y" })
    tpCoordY = row:Right():TextField({
        Placeholder = "50",
        ValueChanged = function(self, v) self.Value = v end,
    })
end
do
    local row = tpForm:Row({ SearchIndex = "Z Coord" })
    row:Left():TitleStack({ Title = "Z Coord", Subtitle = "พิกัด Z" })
    tpCoordZ = row:Right():TextField({
        Placeholder = "0",
        ValueChanged = function(self, v) self.Value = v end,
    })
end
do
    local row = tpForm:Row({ SearchIndex = "TP to Coords" })
    row:Left():TitleStack({ Title = "TP to Coordinates", Subtitle = "วาร์ปไปพิกัด X Y Z" })
    row:Right():Button({
        Label = "GO",
        State = "Primary",
        Pushed = function()
            local x = tonumber(tpCoordX and tpCoordX.Value) or 0
            local y = tonumber(tpCoordY and tpCoordY.Value) or 50
            local z = tonumber(tpCoordZ and tpCoordZ.Value) or 0
            CustomTP:ToCoords(x, y, z)
        end,
    })
end

do
    local row = tpForm:Row({ SearchIndex = "Stop TP" })
    row:Left():TitleStack({ Title = "Stop TP", Subtitle = "หยุดวาร์ปกลางทาง" })
    row:Right():Button({
        Label = "STOP",
        State = "Destructive",
        Pushed = function()
            CustomTP:Stop()
            Notify("TP", "⛔ หยุดวาร์ปแล้ว")
        end,
    })
end

local tpSettingsSec = TPTab:PageSection({
    Title = "Settings",
    Subtitle = "ปรับความเร็วและระยะ",
})
local tpSettingsForm = tpSettingsSec:Form()

do
    local row = tpSettingsForm:Row({ SearchIndex = "Speed" })
    row:Left():TitleStack({ Title = "Speed (studs/tick)", Subtitle = "ระยะที่วาร์ปต่อ tick (10 = เรียบเนียน)" })
    row:Right():Slider({
        Minimum = 1, Maximum = 50, Value = 10,
        ValueChanged = function(_, v) CustomTP.Speed = v end,
    })
end

do
    local row = tpSettingsForm:Row({ SearchIndex = "Threshold" })
    row:Left():TitleStack({ Title = "Threshold", Subtitle = "ระยะที่ถือว่าถึงปลายทาง" })
    row:Right():Slider({
        Minimum = 1, Maximum = 20, Value = 5,
        ValueChanged = function(_, v) CustomTP.Threshold = v end,
    })
end

do
    local row = tpSettingsForm:Row({ SearchIndex = "MaxTicks" })
    row:Left():TitleStack({ Title = "Max Ticks", Subtitle = "จำนวน tick สูงสุด (กันวนไม่จบ)" })
    row:Right():Slider({
        Minimum = 30, Maximum = 1000, Value = 300,
        ValueChanged = function(_, v) CustomTP.MaxTicks = math.floor(v) end,
    })
end

local tpQuickSec = TPTab:PageSection({
    Title = "Quick Actions",
    Subtitle = "ปุ่มลัดสำหรับวาร์ปบ่อย ๆ",
})
local tpQuickForm = tpQuickSec:Form()

do
    local row = tpQuickForm:Row({ SearchIndex = "Quick Elevator" })
    row:Left():TitleStack({ Title = "TP to Elevator", Subtitle = "วาร์ปไปลิฟต์ทันที" })
    row:Right():Button({
        Label = "GO",
        State = "Secondary",
        Pushed = function()
            local elevators = workspace:FindFirstChild("Elevators")
            local elevator = elevators and elevators:FindFirstChild("Elevator")
            if elevator then
                local cf = elevator.PrimaryPart and elevator.PrimaryPart.CFrame or elevator:GetPivot()
                CustomTP:Start(cf)
                Notify("TP", "🚀 กำลังวาร์ปไป Elevator")
            else
                Notify("TP", "❌ ไม่เจอ Elevator")
            end
        end,
    })
end

do
    local row = tpQuickForm:Row({ SearchIndex = "Quick CurrentRoom" })
    row:Left():TitleStack({ Title = "TP to CurrentRoom", Subtitle = "วาร์ปไปกลางห้อง" })
    row:Right():Button({
        Label = "GO",
        State = "Secondary",
        Pushed = function()
            local room = workspace:FindFirstChild("CurrentRoom")
            if room and room:IsA("Model") and room.PrimaryPart then
                CustomTP:Start(room.PrimaryPart.CFrame)
                Notify("TP", "🚀 กำลังวาร์ปไป CurrentRoom")
            else
                Notify("TP", "❌ ไม่เจอ CurrentRoom")
            end
        end,
    })
end

do
    local row = tpQuickForm:Row({ SearchIndex = "Quick Spawn" })
    row:Left():TitleStack({ Title = "TP to Spawn", Subtitle = "วาร์ปไปจุดเกิด" })
    row:Right():Button({
        Label = "GO",
        State = "Secondary",
        Pushed = function()
            local spawnLoc = workspace:FindFirstChildOfClass("SpawnLocation")
            if spawnLoc then
                CustomTP:Start(spawnLoc.CFrame)
                Notify("TP", "🚀 กำลังวาร์ปไป Spawn")
            else
                Notify("TP", "❌ ไม่เจอ Spawn")
            end
        end,
    })
end

-- ============================================================
-- SECTION 18: UI — SETTINGS TAB
-- ============================================================
local sAppSec = SettingsTab:PageSection({ Title = "Appearance", Subtitle = "ปรับธีม & Accent" })
local sAppForm = sAppSec:Form()
do
    local row = sAppForm:Row({ SearchIndex = "Dark Mode" })
    row:Left():TitleStack({ Title = "Dark Mode", Subtitle = "ใช้ธีมมืด" })
    row:Right():Toggle({
        Value = true,
        ValueChanged = function(_, v)
            App.Theme = v and cascade.Themes.Dark or cascade.Themes.Light
        end,
    })
end
do
    local row = sAppForm:Row({ SearchIndex = "Accent Color" })
    row:Left():TitleStack({ Title = "Accent Color", Subtitle = "เปลี่ยนสีหลักของ UI" })
    row:Right():PopUpButton({
        Options = { "Blue","Red","Orange","Yellow","Green","Pink","Purple","Graphite" },
        ValueChanged = function(_, v)
            local names = { "Blue","Red","Orange","Yellow","Green","Pink","Purple","Graphite" }
            local n = names[v]
            if n and cascade.Accents[n] then App.Accent = cascade.Accents[n] end
        end,
    })
end

local sWinSec = SettingsTab:PageSection({ Title = "Window", Subtitle = "ตั้งค่าหน้าต่าง" })
local sWinForm = sWinSec:Form()
do
    local row = sWinForm:Row({ SearchIndex = "Search" })
    row:Left():TitleStack({ Title = "Search Bar", Subtitle = "แสดงช่องค้นหา" })
    row:Right():Toggle({
        Value = true,
        ValueChanged = function(_, v) Window.Searching = v end,
    })
end
do
    local row = sWinForm:Row({ SearchIndex = "Draggable" })
    row:Left():TitleStack({ Title = "Draggable", Subtitle = "ลากหน้าต่างได้" })
    row:Right():Toggle({
        Value = true,
        ValueChanged = function(_, v) Window.Draggable = v end,
    })
end
do
    local row = sWinForm:Row({ SearchIndex = "Resizable" })
    row:Left():TitleStack({ Title = "Resizable", Subtitle = "ปรับขนาดหน้าต่างได้" })
    row:Right():Toggle({
        Value = true,
        ValueChanged = function(_, v) Window.Resizable = v end,
    })
end
do
    local row = sWinForm:Row({ SearchIndex = "Dropshadow" })
    row:Left():TitleStack({ Title = "Dropshadow", Subtitle = "เงาของหน้าต่าง" })
    row:Right():Toggle({
        Value = true,
        ValueChanged = function(_, v) Window.Dropshadow = v end,
    })
end
do
    local row = sWinForm:Row({ SearchIndex = "Blur" })
    row:Left():TitleStack({ Title = "Background Blur", Subtitle = "เบลอพื้นหลัง (กิน resource)" })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v) Window.UIBlur = v end,
    })
end

local sCreditsSec = SettingsTab:PageSection({
    Title = "Credits",
    Subtitle = "999Ms HUB  •  BY. 009exe  •  Dandys World",
})
local sCreditsForm = sCreditsSec:Form()
do
    local row = sCreditsForm:Row()
    row:Left():TitleStack({ Title = "Developer", Subtitle = "009exe" })
    row:Right():Label({ Text = "999Ms HUB" })
end
do
    local row = sCreditsForm:Row()
    row:Left():TitleStack({ Title = "Game", Subtitle = "Dandy's World" })
    row:Right():Label({ Text = "v2.3" })
end
do
    local row = sCreditsForm:Row()
    row:Left():TitleStack({ Title = "AC Bypass", Subtitle = "Rate-Limit v2" })
    row:Right():Label({ Text = __bypassOk and "ACTIVE" or "INACTIVE" })
end

-- ============================================================
-- SECTION 19: PULSE ANIMATION
-- ============================================================
RunService.RenderStepped:Connect(function()
    local pulse = math.abs(math.sin(tick() * 2))

    if GeneratorESP.Enabled then
        for gen, obj in pairs(GeneratorESP.Objects) do
            if gen and gen.Parent and obj and obj.Highlight then
                obj.Highlight.FillTransparency = 0.55 + pulse * 0.25
            end
        end
    end

    if MonsterESP.Enabled then
        for monster, obj in pairs(MonsterESP.Objects) do
            if monster and monster.Parent and obj then
                local pp = monster.PrimaryPart or monster:FindFirstChildWhichIsA("BasePart")
                if pp and obj.Billboard and obj.Billboard.Adornee ~= pp then
                    obj.Billboard.Adornee = pp
                end
                if obj.Highlight and obj.Highlight.Parent then
                    local r, g, b = MonsterESP.Color.R, MonsterESP.Color.G, MonsterESP.Color.B
                    obj.Highlight.FillTransparency = 0.4 + pulse * 0.4
                    obj.Highlight.OutlineColor = Color3.new(
                        math.clamp(r + pulse * 0.2, 0, 1),
                        math.clamp(g + pulse * 0.2, 0, 1),
                        math.clamp(b + pulse * 0.2, 0, 1)
                    )
                end
            end
        end
    end

    if ItemESP.Enabled then
        for item, obj in pairs(ItemESP.Objects) do
            if item and item.Parent and obj then
                local pp = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
                if pp and obj.Billboard and obj.Billboard.Adornee ~= pp then
                    obj.Billboard.Adornee = pp
                end
                if obj.Highlight and obj.Highlight.Parent then
                    obj.Highlight.FillTransparency = 0.65 + pulse * 0.15
                end
            end
        end
    end
end)

-- ============================================================
-- SECTION 20: ROOM CHANGE LISTENERS
-- ============================================================
local CurrentRoom = workspace:FindFirstChild("CurrentRoom")
if CurrentRoom then
    CurrentRoom.ChildAdded:Connect(function()
        task.wait(0.5)
        if GeneratorESP.Enabled then GeneratorESP:ClearAll() GeneratorESP:ConnectFolder() GeneratorESP:Scan() end
        if MonsterESP.Enabled   then MonsterESP:ClearAll()   MonsterESP:ConnectFolder()   MonsterESP:Scan()   end
        if ItemESP.Enabled      then ItemESP:ClearAll()      ItemESP:ConnectFolder()      ItemESP:Scan()      end
    end)
    CurrentRoom.ChildRemoved:Connect(function()
        GeneratorESP:ClearAll() GeneratorESP.CurrentFolder = nil
        MonsterESP:ClearAll()   MonsterESP.CurrentFolder = nil
        ItemESP:ClearAll()      ItemESP.CurrentFolder = nil
    end)
end

task.spawn(function()
    while task.wait(2) do
        if GeneratorESP.Enabled then GeneratorESP:ConnectFolder() GeneratorESP:Scan() end
        if MonsterESP.Enabled   then MonsterESP:ConnectFolder()   MonsterESP:Scan()   end
        if ItemESP.Enabled      then ItemESP:ConnectFolder()      ItemESP:Scan()      end
    end
end)

-- ============================================================
-- SECTION 21: DONE
-- ============================================================
Notify("999Ms HUB", "✅ v2.3 โหลดสำเร็จ! BY. 009exe | Dandys World", 5)
print("[999Ms HUB] ✅ v2.3 — BY. 009exe | Dandys World — โหลดสำเร็จ!")
print("[999Ms HUB] 🛡️ AC Bypass v2: " .. (__bypassOk and "ACTIVE" or "INACTIVE"))