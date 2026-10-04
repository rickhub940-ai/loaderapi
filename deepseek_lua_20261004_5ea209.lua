-- 999ms HUB | Cascade UI + 25ms Farm/ESP + Inf Stamina + 6-Step Teleport
repeat task.wait(0.25) until game:IsLoaded()

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local UserInputService   = game:GetService("UserInputService")
local LocalPlayer        = Players.LocalPlayer

-- ============================================================
-- Cascade UI
-- ============================================================
local coreGui
pcall(function() coreGui = (gethui and gethui()) or game:GetService("CoreGui") end)
if not coreGui then coreGui = game:GetService("CoreGui") end

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

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local WIN_SIZE  = IS_MOBILE
    and UDim2.fromOffset(math.floor(workspace.CurrentCamera.ViewportSize.X * 0.92),
                          math.floor(workspace.CurrentCamera.ViewportSize.Y * 0.72))
    or UDim2.fromOffset(560, 480)

local app = cascade.New({ Theme = cascade.Themes.Dark, Accent = cascade.Accents.Blue, WindowPill = true })
local window = app:Window({
    Title = "999ms HUB", Subtitle = "by 09ms | Fully Merged",
    Size = WIN_SIZE,
    MinSize = IS_MOBILE and Vector2.new(300, 280) or Vector2.new(480, 340),
    MaxSize = IS_MOBILE and Vector2.new(600, 550) or Vector2.new(720, 520),
    Draggable = true, Resizable = true, Dropshadow = true, UIBlur = false, Searching = true,
})

local mainSection = window:Section({ Title = "Menu", Disclosure = true, Expanded = true })
local tabMain     = mainSection:Tab({ Title = "Main",      Icon = cascade.Symbols.circleUserRound, Selected = true })
local tabAbility  = mainSection:Tab({ Title = "Abilities", Icon = cascade.Symbols.zap })
local tabMovement = mainSection:Tab({ Title = "Movement",  Icon = cascade.Symbols.arrowUpCircle })
local tabClient   = mainSection:Tab({ Title = "Client",    Icon = cascade.Symbols.settings })

-- ============================================================
-- Helpers
-- ============================================================
local function addToggle(form, idx, title, sub, cb, def)
    local r = form:Row({ SearchIndex = idx })
    r:Left():TitleStack({ Title = title, Subtitle = sub })
    r:Right():Toggle({ Value = def or false, ValueChanged = function(_, v) cb(v) end })
end

local function addButton(form, idx, title, sub, cb)
    local r = form:Row({ SearchIndex = idx })
    r:Left():TitleStack({ Title = title, Subtitle = sub })
    r:Right():Button({ Title = "Execute", OnClick = cb })
end

local function addSlider(form, o)
    local row = form:Row({ SearchIndex = o.SearchIndex })
    local ts = row:Left():TitleStack({ Title = o.Title, Subtitle = o.Subtitle })
    local function fmt(v)
        if o.Integer ~= false then v = math.floor(v) end
        return tostring(v) .. (o.Suffix and (" " .. o.Suffix) or "")
    end
    ts.Subtitle = (o.Subtitle or "") .. " • " .. fmt(o.Default)
    return row:Right():Slider({
        Minimum = o.Min, Maximum = o.Max, Value = o.Default,
        ValueChanged = function(_, v)
            ts.Subtitle = (o.Subtitle or "") .. " • " .. fmt(v)
            if o.OnChanged then o.OnChanged(o.Integer ~= false and math.floor(v) or v) end
        end,
    })
end

local function notify(title, content)
    app:Notification({ Title = title, Subtitle = content, Duration = 5 })
end

-- ============================================================
-- 📡 ESP (25ms exact)
-- ============================================================
local ESP_SECTION = tabMain:PageSection({ Title = "ESP", Subtitle = "ตาม 25ms" })

-- ── Esp Twisteds ──
local twistedEnabled = false
local twistedConn    = nil
local function highlightTwisteds()
    local currentRoom = workspace:FindFirstChild("CurrentRoom")
    if not currentRoom then return end
    for _, item in pairs(currentRoom:GetChildren()) do
        if item:IsA("Model") then
            local monstersFolder = item:FindFirstChild("Monsters")
            if monstersFolder then
                for _, monster in pairs(monstersFolder:GetChildren()) do
                    if monster:IsA("Model") then
                        if twistedEnabled then
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
                        else
                            local highlight = monster:FindFirstChildOfClass("Highlight")
                            if highlight then highlight:Destroy() end
                            local nameTag = monster:FindFirstChild("NameTag")
                            if nameTag then nameTag:Destroy() end
                        end
                    end
                end
            end
        end
    end
end

-- ── Esp Generators (สีตามสถานะ) ──
local generatorEnabled = false
local generatorConn    = nil
local GEN_COLOR_DONE     = Color3.new(0, 1, 0)
local GEN_COLOR_UNFINISH = Color3.new(1, 0, 0)

local function updateGeneratorColor(generator, color)
    local highlight = generator:FindFirstChildOfClass("Highlight")
    if highlight then
        highlight.FillColor = color
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    end
    local nameTag = generator:FindFirstChild("NameTag")
    if nameTag then
        local textLabel = nameTag:FindFirstChildOfClass("TextLabel")
        if textLabel then
            textLabel.TextColor3 = color
            local uiGradient = textLabel:FindFirstChildOfClass("UIGradient")
            if uiGradient then
                uiGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.5)),
                    ColorSequenceKeypoint.new(1, color)
                })
            end
        end
    end
end

local function isGeneratorCompleted(generator)
    local stats = generator:FindFirstChild("Stats")
    if not stats then return false end
    local completed = stats:FindFirstChild("Completed")
    if completed and completed:IsA("BoolValue") then return completed.Value end
    return false
end

local function highlightGenerators()
    local currentRoom = workspace:FindFirstChild("CurrentRoom")
    if not currentRoom then return end
    for _, item in pairs(currentRoom:GetChildren()) do
        if item:IsA("Model") then
            local generatorsFolder = item:FindFirstChild("Generators")
            if generatorsFolder then
                for _, generator in pairs(generatorsFolder:GetChildren()) do
                    if generator:IsA("Model") then
                        if generatorEnabled then
                            local completed = isGeneratorCompleted(generator)
                            local color = completed and GEN_COLOR_DONE or GEN_COLOR_UNFINISH

                            if not generator:FindFirstChildOfClass("Highlight") then
                                local highlight = Instance.new("Highlight")
                                highlight.Parent = generator
                                highlight.FillColor = color
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
                                textLabel.TextColor3 = color
                                textLabel.TextScaled = false
                                textLabel.Font = Enum.Font.RobotoMono
                                local uiStroke = Instance.new("UIStroke")
                                uiStroke.Parent = textLabel
                                uiStroke.Thickness = 4
                                uiStroke.Color = Color3.fromRGB(0, 0, 0)
                                local uiGradient = Instance.new("UIGradient")
                                uiGradient.Parent = textLabel
                                uiGradient.Color = ColorSequence.new({
                                    ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.5)),
                                    ColorSequenceKeypoint.new(1, color)
                                })
                            else
                                updateGeneratorColor(generator, color)
                            end
                        else
                            local highlight = generator:FindFirstChildOfClass("Highlight")
                            if highlight then highlight:Destroy() end
                            local nameTag = generator:FindFirstChild("NameTag")
                            if nameTag then nameTag:Destroy() end
                        end
                    end
                end
            end
        end
    end
end

-- ── Esp Items ──
local itemsEnabled = false
local itemsConn    = nil
local ITEM_OUTLINE_COLOR = Color3.new(1, 1, 1)
local ITEM_FILL_COLOR    = Color3.new(0, 0, 1)

local function addItemHighlight(model)
    if not model:FindFirstChildOfClass("Highlight") then
        local highlight = Instance.new("Highlight")
        highlight.OutlineColor = ITEM_OUTLINE_COLOR
        highlight.FillColor = ITEM_FILL_COLOR
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
        local textLabel = Instance.new("TextLabel")
        textLabel.Parent = billboardGui
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = model.Name
        textLabel.TextColor3 = ITEM_FILL_COLOR
        textLabel.TextScaled = false
        textLabel.Font = Enum.Font.RobotoMono
        local uiStroke = Instance.new("UIStroke")
        uiStroke.Parent = textLabel
        uiStroke.Thickness = 4
        uiStroke.Color = Color3.fromRGB(0, 0, 0)
        local uiGradient = Instance.new("UIGradient")
        uiGradient.Parent = textLabel
        uiGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, ITEM_FILL_COLOR:Lerp(Color3.new(1, 1, 1), 0.5)),
            ColorSequenceKeypoint.new(1, ITEM_FILL_COLOR)
        })
    end
end

local function highlightItems()
    local currentRoom = workspace:FindFirstChild("CurrentRoom")
    if not (currentRoom and currentRoom:IsA("Folder")) then return end
    for _, item in pairs(currentRoom:GetChildren()) do
        if item:IsA("Model") then
            local itemsFolder = item:FindFirstChild("Items")
            if itemsFolder and itemsFolder:IsA("Folder") then
                for _, subItem in pairs(itemsFolder:GetChildren()) do
                    if subItem:IsA("Model") then
                        if itemsEnabled then
                            addItemHighlight(subItem)
                        else
                            local highlight = subItem:FindFirstChildOfClass("Highlight")
                            if highlight then highlight:Destroy() end
                            local nameTag = subItem:FindFirstChild("NameTag")
                            if nameTag then nameTag:Destroy() end
                        end
                    end
                end
            end
        end
    end
end

-- ── Special Main Twisteds ──
local specialEnabled = false
local specialConn    = nil
local SPECIAL_MAINS = { "AstroMonster","VeeMonster","SproutMonster","PebbleMonster","ShellyMonster","DandyMonster" }

local function highlightSpecialMains()
    local currentRoom = workspace:FindFirstChild("CurrentRoom")
    if not currentRoom then return end
    for _, item in pairs(currentRoom:GetChildren()) do
        if item:IsA("Model") then
            local monstersFolder = item:FindFirstChild("Monsters")
            if monstersFolder then
                for _, monster in pairs(monstersFolder:GetChildren()) do
                    if monster:IsA("Model") and table.find(SPECIAL_MAINS, monster.Name) then
                        if specialEnabled then
                            if not monster:FindFirstChildOfClass("Highlight") then
                                local highlight = Instance.new("Highlight")
                                highlight.Parent = monster
                                highlight.FillColor = Color3.new(1, 1, 0)
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
                                textLabel.TextColor3 = Color3.new(1, 1, 0)
                                textLabel.TextScaled = false
                                textLabel.Font = Enum.Font.RobotoMono
                                local uiStroke = Instance.new("UIStroke")
                                uiStroke.Parent = textLabel
                                uiStroke.Thickness = 4
                                uiStroke.Color = Color3.new(0, 0, 0)
                                local uiGradient = Instance.new("UIGradient")
                                uiGradient.Parent = textLabel
                                uiGradient.Color = ColorSequence.new({
                                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 0.5)),
                                    ColorSequenceKeypoint.new(1, Color3.new(1, 1, 0))
                                })
                            end
                        else
                            local highlight = monster:FindFirstChildOfClass("Highlight")
                            if highlight then highlight:Destroy() end
                            local nameTag = monster:FindFirstChild("NameTag")
                            if nameTag then nameTag:Destroy() end
                        end
                    end
                end
            end
        end
    end
end

-- ── Low Health ──
local lowHealthEnabled = false
local lowHealthConn    = nil
local lowHealthSeen    = {}

local function monitorLowHealth()
    local inGamePlayers = workspace:FindFirstChild("InGamePlayers")
    if not inGamePlayers then return end
    for _, model in ipairs(inGamePlayers:GetChildren()) do
        if model.Name ~= LocalPlayer.Name and model:IsA("Model") then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health == 1 then
                if not lowHealthSeen[model] then
                    notify("Low Health", "Model: " .. model.Name)
                    lowHealthSeen[model] = true
                    if not model:FindFirstChildOfClass("Highlight") then
                        local highlight = Instance.new("Highlight")
                        highlight.Parent = model
                        highlight.FillColor = Color3.new(0.4, 0.26, 0.13)
                        highlight.OutlineColor = Color3.new(1, 1, 1)
                        highlight.FillTransparency = 0.5
                    end
                end
            elseif humanoid and (humanoid.Health == 2 or humanoid.Health == 3) then
                local highlight = model:FindFirstChildOfClass("Highlight")
                if highlight then highlight:Destroy() end
                lowHealthSeen[model] = nil
            end
        end
    end
end

local espForm = ESP_SECTION:Form()
addToggle(espForm, "EspTwisteds", "Esp Twisteds", "แดง - Highlight + NameTag", function(v)
    twistedEnabled = v
    if twistedConn then twistedConn:Disconnect() end
    if v then twistedConn = RunService.Heartbeat:Connect(highlightTwisteds)
    else highlightTwisteds() end
end)
addToggle(espForm, "EspGenerators", "Esp Generators", "🟢 ซ่อมแล้ว / 🔴 ยังไม่ซ่อม", function(v)
    generatorEnabled = v
    if generatorConn then generatorConn:Disconnect() end
    if v then generatorConn = RunService.Heartbeat:Connect(highlightGenerators)
    else highlightGenerators() end
end)
addToggle(espForm, "EspItems", "Esp Items", "ฟ้า - Highlight + NameTag", function(v)
    itemsEnabled = v
    if itemsConn then itemsConn:Disconnect() end
    if v then itemsConn = RunService.Heartbeat:Connect(highlightItems)
    else highlightItems() end
end)
addToggle(espForm, "EspSpecial", "Special Main Twisteds", "เหลือง - Astro/Vee/Sprout ฯลฯ", function(v)
    specialEnabled = v
    if specialConn then specialConn:Disconnect() end
    if v then specialConn = RunService.Heartbeat:Connect(highlightSpecialMains)
    else highlightSpecialMains() end
end)
addToggle(espForm, "LowHealth", "Low Health Esp & Notify", "น้ำตาล - แจ้งเตือนเมื่อเลือด 1", function(v)
    lowHealthEnabled = v
    if lowHealthConn then lowHealthConn:Disconnect() end
    if v then lowHealthConn = RunService.Heartbeat:Connect(monitorLowHealth)
    else
        for model in pairs(lowHealthSeen) do
            local highlight = model:FindFirstChildOfClass("Highlight")
            if highlight then highlight:Destroy() end
        end
        lowHealthSeen = {}
    end
end)

-- ============================================================
-- 🌾 AUTO PLAY [Beta] — 6-STEP ARC TELEPORT
-- ============================================================
local AUTO_SECTION = tabMain:PageSection({ Title = "Auto Play", Subtitle = "วาป 6 จังหวะ ตาม 25ms" })

local autoPlayEnabled = false
local inGamePlayers   = workspace:FindFirstChild("InGamePlayers")

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function teleportTo(part, offset)
    local character = getCharacter()
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart and part then
        humanoidRootPart.CFrame = part.CFrame * offset
        humanoidRootPart.AssemblyLinearVelocity  = Vector3.zero
        humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
    end
end

local function activatePrompt(prompt)
    if prompt:IsA("ProximityPrompt") then
        for _ = 1, 5 do
            prompt:InputHoldBegin()
            wait(0.1)
            prompt:InputHoldEnd()
        end
    end
end

local function findValidGenerator(currentRoom)
    for _, model in ipairs(currentRoom:GetChildren()) do
        local generators = model:FindFirstChild("Generators")
        if generators then
            for _, generator in ipairs(generators:GetChildren()) do
                local stats = generator:FindFirstChild("Stats")
                if stats and stats:FindFirstChild("Completed") and not stats.Completed.Value then
                    return generator
                end
            end
        end
    end
end

local function handleGenerator(generator)
    if not autoPlayEnabled then return end
    local stats = generator:FindFirstChild("Stats")
    if stats and stats:FindFirstChild("Completed") and stats.Completed:IsA("BoolValue") and not stats.Completed.Value then
        local teleportPositions = generator:FindFirstChild("TeleportPositions")
        if teleportPositions and teleportPositions:FindFirstChild("TeleportPosition") then
            local teleportPosition = teleportPositions.TeleportPosition

            -- 🎯 6-STEP ARC TELEPORT (พาราโบลา)
            teleportTo(teleportPosition, CFrame.new(0, 18, 12))   -- ① ขึ้นสูง + ถอยหลังไกล
            wait(0.15)
            teleportTo(teleportPosition, CFrame.new(0, 18, 4))    -- ② สูงเท่าเดิม เข้ามาใกล้
            wait(0.15)
            teleportTo(teleportPosition, CFrame.new(0, 14, -2))   -- ③ เริ่มลดความสูง ผ่านเป้าเล็กน้อย
            wait(0.15)
            teleportTo(teleportPosition, CFrame.new(0, 8, -4))    -- ④ ครึ่งทางลง
            wait(0.15)
            teleportTo(teleportPosition, CFrame.new(0, 3, -2))    -- ⑤ ใกล้พื้น
            wait(0.15)
            teleportTo(teleportPosition, CFrame.new(0, 0, 0))     -- ⑥ ลงตรงเป้า
            wait(0.1)

            -- ยิง ProximityPrompt
            local promptPart = generator:FindFirstChild("Prompt")
            if promptPart and promptPart:IsA("BasePart") then
                local proximityPrompt = promptPart:FindFirstChildOfClass("ProximityPrompt")
                if proximityPrompt then activatePrompt(proximityPrompt) end
            end

            -- รอจนเครื่องเสร็จ
            repeat wait(0.1) until not autoPlayEnabled or stats.Completed.Value
        end
    end
end

local function handleMonsterTeleport(monster, chasingValue, generator)
    if not autoPlayEnabled then return end
    local playerFolder = inGamePlayers:FindFirstChild(LocalPlayer.Name)
    if chasingValue.Value == playerFolder then
        local character = getCharacter()
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, 100, 0)
        end
        wait(10)
        local currentRoom = workspace:FindFirstChild("CurrentRoom")
        if currentRoom and generator then
            local stats = generator:FindFirstChild("Stats")
            if not stats or not stats:FindFirstChild("Completed") or stats.Completed.Value then
                generator = findValidGenerator(currentRoom)
            end
        end
        if generator then
            local teleportPositions = generator:FindFirstChild("TeleportPositions")
            if teleportPositions and teleportPositions:FindFirstChild("TeleportPosition") then
                teleportTo(teleportPositions.TeleportPosition, CFrame.new(0, 0, 0))
            end
            handleGenerator(generator)
        end
    end
end

local function monitorMonsters()
    while autoPlayEnabled do
        local currentRoom = workspace:FindFirstChild("CurrentRoom")
        if not currentRoom or not inGamePlayers then return end
        for _, model in ipairs(currentRoom:GetChildren()) do
            local monsters = model:FindFirstChild("Monsters")
            if monsters then
                for _, monster in ipairs(monsters:GetChildren()) do
                    local chasingValue = monster:FindFirstChild("ChasingValue")
                    if chasingValue and chasingValue:IsA("ObjectValue") then
                        chasingValue:GetPropertyChangedSignal("Value"):Connect(function()
                            local generator = model:FindFirstChild("Generators") and model.Generators:GetChildren()[1]
                            if generator then
                                handleMonsterTeleport(monster, chasingValue, generator)
                            end
                        end)
                    end
                end
            end
        end
        wait(0.3)
    end
end

local function monitorChanges()
    while autoPlayEnabled do
        local currentRoom = workspace:FindFirstChild("CurrentRoom")
        if currentRoom then
            for _, model in ipairs(currentRoom:GetChildren()) do
                local generators = model:FindFirstChild("Generators")
                if generators then
                    for _, generator in ipairs(generators:GetChildren()) do
                        if generator:IsA("Model") then
                            handleGenerator(generator)
                        end
                    end
                end
            end
        end
        wait(0.3)
    end
end

local autoForm = AUTO_SECTION:Form()
addToggle(autoForm, "AutoPlay", "Auto Play [Beta]", "วาป 6 จังหวะ + หลบมอน", function(v)
    autoPlayEnabled = v
    if v then
        spawn(monitorMonsters)
        spawn(monitorChanges)
        notify("Auto Play", "Enabled (6-step)")
    else
        notify("Auto Play", "Disabled")
    end
end)

-- ============================================================
-- 🏃 INF STAMINA (WalkSpeed 30 + Auto-detect Lock)
-- ============================================================
local STAMINA_SECTION = tabMain:PageSection({ Title = "Inf Stamina", Subtitle = "วิ่งเร็ว 30 + ล็อก stamina" })

local staminaSystem = {
    Enabled          = false,
    MoveSpeed        = 30,
    LockStamina      = true,
    ScanInterval     = 1,
    SpeedConnection  = nil,
    RespawnConnection= nil,
    TrackedValues    = {},
    Keywords = { "stamina", "energy", "staminavalue", "staminacount",
                 "sprint", "sprintbar", "sprintcount", "endurance" },
}

local function isStaminaValue(valueName)
    local lowerName = valueName:lower()
    for _, keyword in ipairs(staminaSystem.Keywords) do
        if lowerName:find(keyword) then return true end
    end
    return false
end

local function trackStaminaValue(value)
    if not value:IsA("ValueBase") then return end
    if staminaSystem.TrackedValues[value] then return end
    if not isStaminaValue(value.Name) then return end

    staminaSystem.TrackedValues[value] = true

    task.spawn(function()
        while staminaSystem.LockStamina and value.Parent do
            pcall(function()
                if value:IsA("NumberValue") or value:IsA("IntValue") then
                    local maxField = value:FindFirstChild("MaxValue")
                                  or value:FindFirstChild("Max")
                    if maxField and maxField:IsA("ValueBase") then
                        value.Value = maxField.Value
                    elseif value.Value < 100 then
                        value.Value = 100
                    end
                end
            end)
            task.wait(0.1)
        end
    end)
end

local function scanForStamina()
    local playerFolder = workspace:FindFirstChild("InGamePlayers")
    if playerFolder then
        local myEntry = playerFolder:FindFirstChild(LocalPlayer.Name)
        if myEntry then
            for _, descendant in ipairs(myEntry:GetDescendants()) do
                trackStaminaValue(descendant)
            end
        end
    end

    local dataFolder = ReplicatedStorage:FindFirstChild("PlayerData")
    if dataFolder then
        local myData = dataFolder:FindFirstChild(tostring(LocalPlayer.UserId))
        if myData then
            for _, descendant in ipairs(myData:GetDescendants()) do
                trackStaminaValue(descendant)
            end
        end
    end

    local currentCharacter = LocalPlayer.Character
    if currentCharacter then
        for attributeName, _ in pairs(currentCharacter:GetAttributes()) do
            if isStaminaValue(attributeName) then
                pcall(function() currentCharacter:SetAttribute(attributeName, 100) end)
            end
        end
        local currentHumanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
        if currentHumanoid then
            for attributeName, _ in pairs(currentHumanoid:GetAttributes()) do
                if isStaminaValue(attributeName) then
                    pcall(function() currentHumanoid:SetAttribute(attributeName, 100) end)
                end
            end
        end
    end
end

local function startStaminaSystem()
    staminaSystem.Enabled = true

    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid  = character:WaitForChild("Humanoid")
    humanoid.WalkSpeed = staminaSystem.MoveSpeed

    staminaSystem.SpeedConnection = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if staminaSystem.Enabled and humanoid.WalkSpeed ~= staminaSystem.MoveSpeed then
            humanoid.WalkSpeed = staminaSystem.MoveSpeed
        end
    end)

    staminaSystem.RespawnConnection = LocalPlayer.CharacterAdded:Connect(function(newCharacter)
        if not staminaSystem.Enabled then return end
        local newHumanoid = newCharacter:WaitForChild("Humanoid")
        task.wait(0.1)
        newHumanoid.WalkSpeed = staminaSystem.MoveSpeed
        if staminaSystem.SpeedConnection then staminaSystem.SpeedConnection:Disconnect() end
        staminaSystem.SpeedConnection = newHumanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if staminaSystem.Enabled and newHumanoid.WalkSpeed ~= staminaSystem.MoveSpeed then
                newHumanoid.WalkSpeed = staminaSystem.MoveSpeed
            end
        end)
    end)

    task.spawn(function()
        while staminaSystem.Enabled do
            task.wait(0.1)
            local c = LocalPlayer.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h and h.WalkSpeed ~= staminaSystem.MoveSpeed then
                    h.WalkSpeed = staminaSystem.MoveSpeed
                end
            end
        end
    end)

    scanForStamina()
    task.spawn(function()
        while staminaSystem.LockStamina and staminaSystem.Enabled do
            task.wait(staminaSystem.ScanInterval)
            scanForStamina()
        end
    end)

    task.spawn(function()
        local playerFolder = workspace:WaitForChild("InGamePlayers", 10)
        if playerFolder then
            playerFolder.DescendantAdded:Connect(function(d)
                if d:IsA("ValueBase") and isStaminaValue(d.Name) then
                    trackStaminaValue(d)
                end
            end)
        end
        local dataFolder = ReplicatedStorage:WaitForChild("PlayerData", 10)
        if dataFolder then
            dataFolder.DescendantAdded:Connect(function(d)
                if d:IsA("ValueBase") and isStaminaValue(d.Name) then
                    trackStaminaValue(d)
                end
            end)
        end
    end)
end

local function stopStaminaSystem()
    staminaSystem.Enabled = false
    if staminaSystem.SpeedConnection then
        staminaSystem.SpeedConnection:Disconnect()
        staminaSystem.SpeedConnection = nil
    end
    if staminaSystem.RespawnConnection then
        staminaSystem.RespawnConnection:Disconnect()
        staminaSystem.RespawnConnection = nil
    end
    local c = LocalPlayer.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = 16 end
    end
end

local staminaForm = STAMINA_SECTION:Form()
addSlider(staminaForm, {
    SearchIndex = "StaminaSpeed", Title = "Move Speed",
    Subtitle = "ความเร็วเดิน (ปกติ 16)",
    Min = 16, Max = 100, Default = 30,
    OnChanged = function(v)
        staminaSystem.MoveSpeed = v
        if staminaSystem.Enabled then
            local c = LocalPlayer.Character
            if c and c:FindFirstChildOfClass("Humanoid") then
                c.Humanoid.WalkSpeed = v
            end
        end
    end,
})
addToggle(staminaForm, "InfStaminaToggle", "Enable Inf Stamina",
    "วิ่งเร็ว 30 + lock stamina ให้เต็มตลอด",
    function(v)
        if v then
            startStaminaSystem()
            notify("Inf Stamina", "Enabled — Speed: " .. staminaSystem.MoveSpeed)
        else
            stopStaminaSystem()
            notify("Inf Stamina", "Disabled")
        end
    end
)

-- ============================================================
-- Client Options
-- ============================================================
local CLIENT_SECTION = tabMain:PageSection({ Title = "Client Options", Subtitle = "จาก 25ms" })
local clientForm = CLIENT_SECTION:Form()

addButton(clientForm, "RemoveSkillCheck", "Remove Skill Check", "ลบ SkillCheckFrame", function()
    local scf = LocalPlayer.PlayerGui.ScreenGui.Menu:FindFirstChild("SkillCheckFrame")
    if scf then scf:Destroy() end
    notify("Remove SkillCheck", "Done")
end)

addButton(clientForm, "AutoSkillCheck", "Auto Skill Check GUI", "Setup Calibrate + โหลด Auto Skill", function()
    local screenGui = LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("ScreenGui")
    if screenGui and screenGui:FindFirstChild("Menu") and screenGui.Menu:FindFirstChild("Calibrate") then
        local calibrateButton = screenGui.Menu.Calibrate
        calibrateButton.Size = UDim2.new(1, 0, 1, 0)
        calibrateButton.Position = UDim2.new(0, 0, 0, 0)
        calibrateButton.AnchorPoint = Vector2.new(0, 0)
        calibrateButton.BackgroundTransparency = 0.9
        calibrateButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    end
    loadstring(game:HttpGet("https://rawscripts.net/raw/Dandy's-World-ALPHA-Dandy-s-Auto-Skill-Check-21849"))()
end)

-- ── Teleports ──
local TELEPORT_SECTION = tabMain:PageSection({ Title = "Teleports", Subtitle = "จาก 25ms" })
local teleportForm = TELEPORT_SECTION:Form()

addButton(teleportForm, "PickAll", "Pick All Items", "วาปเก็บไอเทมทั้งหมด", function()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    local currentRoom = workspace:FindFirstChild("CurrentRoom")
    if currentRoom then
        for _, model in ipairs(currentRoom:GetChildren()) do
            if model:IsA("Model") then
                local itemsFolder = model:FindFirstChild("Items")
                if itemsFolder and #itemsFolder:GetChildren() > 0 then
                    for _, item in ipairs(itemsFolder:GetChildren()) do
                        if item:IsA("Model") then
                            humanoidRootPart.CFrame = item:GetModelCFrame()
                            task.wait(0.1)
                            local promptPart = item:FindFirstChild("Prompt")
                            if promptPart and promptPart:IsA("BasePart") then
                                local pp = promptPart:FindFirstChildOfClass("ProximityPrompt")
                                if pp then
                                    for _ = 1, 3 do
                                        pp:InputHoldBegin(); task.wait(0.1)
                                        pp:InputHoldEnd();   task.wait(0.1)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    notify("Pick All", "Done")
end)

-- ── More things ──
local MORE_SECTION = tabMain:PageSection({ Title = "More Things", Subtitle = "จาก 25ms" })
local moreForm = MORE_SECTION:Form()

addButton(moreForm, "Noclip", "Noclip", "ลบ InvisBorder ใน FreeArea", function()
    local currentRoom = workspace:FindFirstChild("CurrentRoom")
    if currentRoom then
        local model = currentRoom:FindFirstChildOfClass("Model")
        if model then
            local freeArea = model:FindFirstChild("FreeArea")
            if freeArea then
                for _, child in ipairs(freeArea:GetChildren()) do
                    if child:IsA("Part") and child.Name == "InvisBorder" then
                        child:Destroy()
                    end
                end
            end
        end
    end
    notify("Noclip", "Done")
end)

addButton(moreForm, "NoFog", "No Fog", "ลบหมอก", function()
    game.Lighting.FogEnd = math.huge
    game.Lighting.FogStart = math.huge
    game.Lighting.FogColor = Color3.new(1, 1, 1)
    notify("No Fog", "Done")
end)

-- ── Notify ──
local NOTIFY_SECTION = tabMain:PageSection({ Title = "Notify", Subtitle = "จาก 25ms" })
local notifyForm = NOTIFY_SECTION:Form()

local notifyRareEnabled = false
addToggle(notifyForm, "NotifyRare", "Notify Rare or better items",
    "Bandage / HealthKit / SmokeBomb ฯลฯ", function(v)
    notifyRareEnabled = v
    if v then
        task.spawn(function()
            local notifiedModels = {}
            local targetModels = { "Bandage","HealthKit","SmokeBomb","EjectButton","Valve",
                                    "Box chocolates","AirHorn","EnigmaCandy","JumperCable","PopBottle" }
            local currentRoom = workspace:FindFirstChild("CurrentRoom")
            if currentRoom then
                while notifyRareEnabled do
                    for _, model in ipairs(currentRoom:GetChildren()) do
                        if model:IsA("Model") then
                            local itemsFolder = model:FindFirstChild("Items")
                            if itemsFolder then
                                for _, item in ipairs(itemsFolder:GetChildren()) do
                                    if table.find(targetModels, item.Name) and not notifiedModels[item.Name] then
                                        notify("Rare Item", item.Name)
                                        notifiedModels[item.Name] = true
                                    end
                                end
                            end
                        end
                    end
                    for modelName in pairs(notifiedModels) do
                        local stillExists = false
                        for _, model in ipairs(currentRoom:GetChildren()) do
                            local itemsFolder = model:FindFirstChild("Items")
                            if itemsFolder and itemsFolder:FindFirstChild(modelName) then
                                stillExists = true; break
                            end
                        end
                        if not stillExists then notifiedModels[modelName] = nil end
                    end
                    task.wait(5)
                end
            end
        end)
    end
end)

local notifyMainEnabled = false
addToggle(notifyForm, "NotifyMain", "Notify Mains Twisteds",
    "Astro / Vee / Sprout / Pebble / Shelly / Dandy", function(v)
    notifyMainEnabled = v
    if v then
        task.spawn(function()
            local notifiedMonsters = {}
            local targetMonsters = { "AstroMonster","VeeMonster","SproutMonster",
                                     "PebbleMonster","ShellyMonster","DandyMonster" }
            local currentRoom = workspace:FindFirstChild("CurrentRoom")
            if currentRoom then
                while notifyMainEnabled do
                    for _, model in ipairs(currentRoom:GetChildren()) do
                        if model:IsA("Model") then
                            local monstersFolder = model:FindFirstChild("Monsters")
                            if monstersFolder then
                                for _, monster in ipairs(monstersFolder:GetChildren()) do
                                    if table.find(targetMonsters, monster.Name) and not notifiedMonsters[monster.Name] then
                                        notify("Rare Monster", monster.Name)
                                        notifiedMonsters[monster.Name] = true
                                    end
                                end
                            end
                        end
                    end
                    for monsterName in pairs(notifiedMonsters) do
                        local stillExists = false
                        for _, model in ipairs(currentRoom:GetChildren()) do
                            local monstersFolder = model:FindFirstChild("Monsters")
                            if monstersFolder and monstersFolder:FindFirstChild(monsterName) then
                                stillExists = true; break
                            end
                        end
                        if not stillExists then notifiedMonsters[monsterName] = nil end
                    end
                    task.wait(5)
                end
            end
        end)
    end
end)

-- ============================================================
-- ⚡ ABILITIES
-- ============================================================
local ITEM_SECTION = tabAbility:PageSection({ Title = "Items", Subtitle = "จาก 25ms" })
local itemForm = ITEM_SECTION:Form()

local autoUseItemsEnabled = false
addToggle(itemForm, "AutoUseItems", "Auto use Items", "ยิง ItemEvent ทุก 0.5 วิ", function(state)
    autoUseItemsEnabled = state
    if state then
        task.spawn(function()
            local function invokeItemEvent(slot)
                local character = LocalPlayer.Character
                if not character then return end
                local inventory = character:FindFirstChild("Inventory")
                if not inventory then return end
                local item = inventory:FindFirstChild(slot)
                if item then
                    ReplicatedStorage.Events.ItemEvent:InvokeServer(character, item)
                end
            end
            while autoUseItemsEnabled do
                invokeItemEvent("Slot1")
                invokeItemEvent("Slot2")
                invokeItemEvent("Slot3")
                wait(0.5)
            end
        end)
    end
end)

local ABILITY_SECTION = tabAbility:PageSection({ Title = "Abilities", Subtitle = "จาก 25ms" })
local abilityForm = ABILITY_SECTION:Form()

local sproutHealEnabled = false
addToggle(abilityForm, "SproutHeal", "Auto Sprout Self Heal",
    "ใช้กับ Sprout — ยิงทุก 1 วิ", function(state)
    sproutHealEnabled = state
    if state then
        task.spawn(function()
            while sproutHealEnabled do
                local args = {
                    [1] = LocalPlayer.Character,
                    [2] = CFrame.new(-179.29843139648438, 146.2311248779297, -164.61495971679688)
                        * CFrame.Angles(3.1415927410125732, 0.4017193913459778, -3.141592502593994),
                    [3] = LocalPlayer.Character
                }
                ReplicatedStorage.Events.AbilityEvent:InvokeServer(unpack(args))
                wait(1)
            end
        end)
    end
end)

local shellyBoostEnabled = false
addToggle(abilityForm, "ShellyBoost", "Auto Shelly Boost",
    "ยิงเมื่อ ActivePlayer == เรา", function(state)
    shellyBoostEnabled = state
    if state then
        task.spawn(function()
            local playerModel = workspace:FindFirstChild("InGamePlayers"):FindFirstChild(LocalPlayer.Name)
            if not playerModel then return end
            while shellyBoostEnabled do
                local currentRoom = workspace:FindFirstChild("CurrentRoom")
                if currentRoom then
                    for _, model in ipairs(currentRoom:GetChildren()) do
                        local generatorsFolder = model:FindFirstChild("Generators")
                        if generatorsFolder then
                            for _, generator in ipairs(generatorsFolder:GetChildren()) do
                                local statsFolder = generator:FindFirstChild("Stats")
                                if statsFolder then
                                    local activePlayer = statsFolder:FindFirstChild("ActivePlayer")
                                    if activePlayer and activePlayer.Value == playerModel then
                                        local args = {
                                            [1] = LocalPlayer.Character,
                                            [2] = CFrame.new(-179.29843139648438, 146.2311248779297, -164.61495971679688)
                                                * CFrame.Angles(3.1415927410125732, 0.4017193913459778, -3.141592502593994),
                                            [3] = LocalPlayer.Character
                                        }
                                        ReplicatedStorage.Events.AbilityEvent:InvokeServer(unpack(args))
                                    end
                                end
                            end
                        end
                    end
                end
                wait(1)
            end
        end)
    end
end)

local autoAbilityEnabled = false
addToggle(abilityForm, "AutoAbility", "Auto use ability", "ยิง AbilityEvent ทุก 0.3 วิ", function(state)
    autoAbilityEnabled = state
    if state then
        task.spawn(function()
            while autoAbilityEnabled do
                local args = {
                    [1] = LocalPlayer.Character,
                    [2] = CFrame.new(-65.78115844726562, 145.7693634033203, 86.53424072265625)
                        * CFrame.Angles(4.4136689858476075e-09, 2.9576958503043716e-16, 5.338084818617972e-08),
                    [3] = false
                }
                ReplicatedStorage.Events.AbilityEvent:InvokeServer(unpack(args))
                wait(0.3)
            end
        end)
    end
end)

addButton(abilityForm, "HealSelf", "Heal yourself", "ใช้กับ Sprout", function()
    local args = {
        [1] = LocalPlayer.Character,
        [2] = CFrame.new(-65.78115844726562, 145.7693634033203, 86.53424072265625)
            * CFrame.Angles(4.4136689858476075e-09, 2.9576958503043716e-16, 5.338084818617972e-08),
        [3] = false
    }
    ReplicatedStorage.Events.AbilityEvent:InvokeServer(unpack(args))
end)

-- ============================================================
-- 🏃 MOVEMENT
-- ============================================================
local INFJUMP_SECTION = tabMovement:PageSection({ Title = "Infinity Jump", Subtitle = "" })
local infJump = { Enabled = false, JumpForce = 50 }

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Space and infJump.Enabled then
        local character = LocalPlayer.Character
        if not character then return end
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoidRootPart and humanoid and humanoid.Health > 0 then
            humanoidRootPart.Velocity = Vector3.new(
                humanoidRootPart.Velocity.X,
                infJump.JumpForce,
                humanoidRootPart.Velocity.Z
            )
        end
    end
end)

local infJumpForm = INFJUMP_SECTION:Form()
addToggle(infJumpForm, "InfJump", "Infinity Jump", "กด SPACE กระโดดกลางอากาศ", function(v)
    infJump.Enabled = v
end)
addSlider(infJumpForm, {
    SearchIndex = "JumpForce", Title = "Jump Force", Subtitle = "แรงกระโดด",
    Min = 10, Max = 100, Default = 50,
    OnChanged = function(v) infJump.JumpForce = v end,
})

-- ── Fly ──
local FLY_SECTION = tabMovement:PageSection({ Title = "Fly", Subtitle = "" })
local flySystem = { Enabled = false, Speed = 60, BodyVelocity = nil, BodyGyro = nil, Connection = nil }

local function getHRP()
    local c = LocalPlayer.Character
    return c, c and c:FindFirstChild("HumanoidRootPart")
end

local flyForm = FLY_SECTION:Form()
addToggle(flyForm, "FlyToggle", "Fly", "W/A/S/D + SPACE/SHIFT", function(v)
    flySystem.Enabled = v
    if v then
        local _, hrp = getHRP()
        if not hrp then return end

        if flySystem.BodyVelocity then flySystem.BodyVelocity:Destroy() end
        if flySystem.BodyGyro then flySystem.BodyGyro:Destroy() end

        flySystem.BodyVelocity = Instance.new("BodyVelocity")
        flySystem.BodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        flySystem.BodyVelocity.Velocity = Vector3.zero
        flySystem.BodyVelocity.Parent = hrp

        flySystem.BodyGyro = Instance.new("BodyGyro")
        flySystem.BodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        flySystem.BodyGyro.P = 1000
        flySystem.BodyGyro.Parent = hrp

        if flySystem.Connection then flySystem.Connection:Disconnect() end
        flySystem.Connection = RunService.Heartbeat:Connect(function()
            if not flySystem.Enabled then return end
            local _, r = getHRP()
            if not r then return end
            local camera = workspace.CurrentCamera
            local direction = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then direction -= Vector3.new(0, 1, 0) end
            flySystem.BodyVelocity.Velocity = direction.Magnitude > 0 and (direction.Unit * flySystem.Speed) or Vector3.zero
            flySystem.BodyGyro.CFrame = camera.CFrame
        end)
    else
        if flySystem.Connection then flySystem.Connection:Disconnect(); flySystem.Connection = nil end
        if flySystem.BodyVelocity then flySystem.BodyVelocity:Destroy(); flySystem.BodyVelocity = nil end
        if flySystem.BodyGyro then flySystem.BodyGyro:Destroy(); flySystem.BodyGyro = nil end
    end
end)
addSlider(flyForm, {
    SearchIndex = "FlySpeed", Title = "Fly Speed", Subtitle = "ความเร็วบิน",
    Min = 20, Max = 300, Default = 60,
    OnChanged = function(v) flySystem.Speed = v end,
})

-- ============================================================
-- Ready Notification
-- ============================================================
notify("999ms HUB", "Fully Merged (6-Step Teleport)")