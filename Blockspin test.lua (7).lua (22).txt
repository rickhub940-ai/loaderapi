

local WindUI = loadstring(game:HttpGet(
"https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

local player = game.Players.LocalPlayer




local avatar = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds="
..player.UserId.."&size=420x420&format=Png"

local Window = WindUI:CreateWindow({
    Title = "Dipper HUB | Premium [ BLOCK SPIN] ",
    Author = "Dipper TEAM",
    Folder = "N HUB",
    Size = UDim2.fromOffset(700, 540),
    Background = "rbxassetid://124013844566613",
    Transparent = true,
    Resizable = true,


    User = {
        Enabled = true,
        Custom = {
            Name = Anonymous,
            Bio = "RickHUB USER",
            Image = avatar
        }
    }
})
Window:Tag({
    Title = "v0.0.1",
    Icon = "github",
    Color = Color3.fromHex("#00bfff"),
    Radius = 5,
})

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

Window:EditOpenButton({ Enabled = false })

local ScreenGui = Instance.new("ScreenGui")
local ToggleBtn = Instance.new("ImageButton")

ScreenGui.Name = "WindUI_Toggle"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0, 20, 0.5, -25)
ToggleBtn.BackgroundTransparency = 1
ToggleBtn.Image = "rbxassetid://124339558110081"
ToggleBtn.Active = true
ToggleBtn.Draggable = true
ToggleBtn.Parent = ScreenGui


local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = ToggleBtn

local UIStroke = Instance.new("UIStroke")
UIStroke.Thickness = 2
UIStroke.Color = Color3.fromRGB(255,255,255)
UIStroke.Parent = ToggleBtn

local opened = true

local function toggle()
    opened = not opened
    if Window.UI then
        Window.UI.Enabled = opened
    else
        Window:Toggle()
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    ToggleBtn:TweenSize(
        UDim2.new(0, 56, 0, 56),
        Enum.EasingDirection.Out,
        Enum.EasingStyle.Quad,
        0.12,
        true,
        function()
            ToggleBtn:TweenSize(
                UDim2.new(0, 50, 0, 50),
                Enum.EasingDirection.Out,
                Enum.EasingStyle.Quad,
                0.12,
                true
            )
        end
    )
    toggle()
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.T then
        toggle()
    end
end)





-- Silent aim




local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Network = require(game.ReplicatedStorage.Modules.Core.Net)

local TargetHistory = {}
local FOV = 200
local ShowFOV = false
local SilentAimEnabled = false 
local AimPart = "Head"

-- FOV Circle
local fovCircle = Drawing.new("Circle")
fovCircle.Radius = FOV
fovCircle.Thickness = 1
fovCircle.Filled = false
fovCircle.Color = Color3.fromRGB(255,255,255)
fovCircle.Visible = false  -- เริ่มต้นปิดไว้

-- Tracer Line
local tracer = Drawing.new("Line")
tracer.Thickness = 2
tracer.Color = Color3.fromRGB(255,0,0)
tracer.Visible = false

-- Billboard Dot
local billboard = Instance.new("BillboardGui")
billboard.Size = UDim2.new(0, 35, 0, 35)
billboard.AlwaysOnTop = true
billboard.MaxDistance = math.huge
billboard.StudsOffset = Vector3.new(0, 0, 0)
billboard.Enabled = false
billboard.Parent = CoreGui

local img = Instance.new("ImageLabel")
img.Size = UDim2.new(1, 0, 1, 0)
img.BackgroundTransparency = 1
img.ScaleType = Enum.ScaleType.Fit
img.AnchorPoint = Vector2.new(0.5, 0.5)
img.Position = UDim2.new(0.5, 0, 0.5, 0)
img.Image = "rbxassetid://139464476852547"
img.Parent = billboard

local currentTarget = nil
local rotation = 0
local shotIndex = 0

local function RainbowColor(i)
    return Color3.fromHSV((i % 10) / 10, 1, 1)
end

local function CreateTracer(fromPos, toPos)
    shotIndex = shotIndex + 1
    local distance = (toPos - fromPos).Magnitude
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.4, 0.4, distance)
    part.CFrame = CFrame.new(fromPos, toPos) * CFrame.new(0, 0, -distance / 2)
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = RainbowColor(shotIndex)
    part.Parent = workspace
    Debris:AddItem(part, 2)
end

local function WorldToViewPoint(pos)
    return Camera:WorldToViewportPoint(pos)
end

local function IsAlive(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function IsBehindWall(startPos, endPos, ignore)
    local ray = Ray.new(startPos, endPos - startPos)
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, ignore or {})
    return hit ~= nil
end

local function GetTargetPart(character)
    if AimPart == "Head" then
        return character:FindFirstChild("Head")
    elseif AimPart == "HumanoidRootPart" then
        return character:FindFirstChild("HumanoidRootPart")
    elseif AimPart == "Torso" then
        return character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    end
    return character:FindFirstChild("Head")
end

local function GetClosestTarget()
    local closest = nil
    local closestPart = nil
    local dist = math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character and IsAlive(v.Character) and not v:GetAttribute("SilentAimIgnore") then
            local targetPart = GetTargetPart(v.Character)
            if targetPart then
                local pos, onScreen = WorldToViewPoint(targetPart.Position)
                if onScreen then
                    local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if d < FOV and d < dist then
                        closest = v.Character
                        closestPart = targetPart
                        dist = d
                    end
                end
            end
        end
    end
    return closest, closestPart
end

local function GetVelocity(target, pos)
    local t = tick()
    TargetHistory[target] = TargetHistory[target] or {}
    local hist = TargetHistory[target]
    if #hist >= 3 then
        table.remove(hist, 1)
    end
    table.insert(hist, { pos = pos, time = t })
    if #hist < 2 then
        return Vector3.zero
    end
    local p1 = hist[#hist - 1]
    local p2 = hist[#hist]
    local dt = math.max(p2.time - p1.time, 1e-6)
    return (p2.pos - p1.pos) / dt
end

local OldSend
OldSend = hookfunction(Network.send, function(...)
    local args = { ... }
    if args[1] == "shoot_gun" and SilentAimEnabled then
        local target, targetPart = GetClosestTarget()
        if target and targetPart then
            local char = LocalPlayer.Character
            if not char then
                return OldSend(...)
            end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then
                return OldSend(...)
            end

            local myPos = root.Position
            local targetPos = targetPart.Position
            local vel = GetVelocity(target, targetPos)
            local speed = vel.Magnitude
            local predictedPos
            local lookDir = targetPart.CFrame.LookVector
            local scaled = math.clamp(speed, 0, 125) / 125

            if speed > 126 then
                predictedPos = targetPos
            else
                local maxLead = 15
                local leadDistance = scaled * maxLead
                predictedPos = targetPos + (lookDir * leadDistance)
                if vel.Y > 2 then
                    predictedPos = predictedPos + Vector3.new(0, 3 + scaled * 3, 0)
                elseif vel.Y < -2 then
                    predictedPos = predictedPos - Vector3.new(0, 1.5 + scaled * 2, 0)
                end
            end

            local ignore = { LocalPlayer.Character, target }
            local behind = IsBehindWall(myPos, predictedPos, ignore)

            if behind then
                args[3] = CFrame.new(math.huge, math.huge, math.huge)
            else
                args[3] = CFrame.new(myPos, predictedPos)
            end

            for _, v in pairs(args[4] or {}) do
                for _, x in pairs(v) do
                    x.Position = predictedPos
                    x.Instance = targetPart
                end
            end

            CreateTracer(myPos, predictedPos)
        end
    end
    return OldSend(table.unpack(args))
end)

RunService.RenderStepped:Connect(function()
    local centerPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    if SilentAimEnabled and ShowFOV then
        fovCircle.Position = centerPos
        fovCircle.Radius = FOV
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
    end

    if SilentAimEnabled then
        local target, targetPart = GetClosestTarget()
        if target and targetPart then
            local pos, onScreen = WorldToViewPoint(targetPart.Position)
            if onScreen then
                tracer.From = centerPos
                tracer.To = Vector2.new(pos.X, pos.Y)
                tracer.Visible = true

                if currentTarget ~= target then
                    currentTarget = target
                    billboard.Adornee = targetPart
                    billboard.Enabled = true
                end

                rotation = rotation + 3
                img.Rotation = rotation
            else
                tracer.Visible = false
                billboard.Enabled = false
            end
        else
            tracer.Visible = false
            billboard.Enabled = false
            currentTarget = nil
        end
    else
        tracer.Visible = false
        billboard.Enabled = false
        currentTarget = nil
    end
end)








-- Esp เ




local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local espPlayers = {}
local boxESPEnabled = false
local nameESPEnabled = false
local distanceESPEnabled = false
local healthESPEnabled = false
local highlightEnabled = false
local highlights = {}

local function createHighlight(character)
    if not character then return nil end
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.3
    highlight.OutlineTransparency = 0
    highlight.Parent = character
    return highlight
end

local function updateHighlights()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if not highlights[player] or not highlights[player].Parent then
                highlights[player] = createHighlight(player.Character)
            end
        end
    end
    for player, hl in pairs(highlights) do
        if not player or not player.Parent or not player.Character then
            if hl and hl.Destroy then pcall(function() hl:Destroy() end) end
            highlights[player] = nil
        end
    end
end

local function createESP(player)
    if espPlayers[player] then return end
    
    local lines = {}
    for i = 1, 12 do
        local line = Drawing.new("Line")
        line.Color = Color3.new(1, 1, 1)
        line.Thickness = 2
        line.Visible = false
        line.From = Vector2.new(0, 0)
        line.To = Vector2.new(0, 0)
        lines[i] = line
    end
    
    local nameText = Drawing.new("Text")
    nameText.Size = 16
    nameText.Center = true
    nameText.Outline = true
    nameText.Color = Color3.fromRGB(255, 255, 255)
    nameText.Font = 2
    
    local distanceText = Drawing.new("Text")
    distanceText.Size = 14
    distanceText.Center = true
    distanceText.Outline = true
    distanceText.Color = Color3.fromRGB(255, 255, 255)
    
    local healthBg = Drawing.new("Square")
    healthBg.Filled = false
    healthBg.Thickness = 1
    healthBg.Color = Color3.fromRGB(0, 0, 0)
    healthBg.Transparency = 1
    healthBg.Visible = false
    
    local healthFg = Drawing.new("Square")
    healthFg.Filled = true
    healthFg.Transparency = 1
    healthFg.Visible = false
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = false
    pcall(function() highlight.Parent = player.Character or Workspace end)
    
    local drawings = {nameText, distanceText, healthBg, healthFg, highlight}
    for _, line in ipairs(lines) do table.insert(drawings, line) end
    
    local conn = RunService.RenderStepped:Connect(function()
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
            for _, line in ipairs(lines) do line.Visible = false end
            nameText.Visible = false
            distanceText.Visible = false
            healthBg.Visible = false
            healthFg.Visible = false
            highlight.Enabled = false
            return
        end
        
        if highlight and highlight.Parent and player.Character then
            highlight.Adornee = player.Character
        end
        
        local hrp = player.Character.HumanoidRootPart
        local humanoid = player.Character:FindFirstChild("Humanoid")
        
        local dist = 0
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            dist = (hrp.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
        end
        
        local thickness = dist > 0 and math.clamp(500 / math.max(dist, 1), 0.5, 2) or 2
        local cf = player.Character:GetPivot()
        local size = Vector3.new(3.5, 7, 2)
        local halfSize = size / 2
        
        local corners = {
            cf * Vector3.new(-halfSize.X, -halfSize.Y, -halfSize.Z),
            cf * Vector3.new(-halfSize.X, -halfSize.Y, halfSize.Z),
            cf * Vector3.new(-halfSize.X, halfSize.Y, -halfSize.Z),
            cf * Vector3.new(-halfSize.X, halfSize.Y, halfSize.Z),
            cf * Vector3.new(halfSize.X, -halfSize.Y, -halfSize.Z),
            cf * Vector3.new(halfSize.X, -halfSize.Y, halfSize.Z),
            cf * Vector3.new(halfSize.X, halfSize.Y, -halfSize.Z),
            cf * Vector3.new(halfSize.X, halfSize.Y, halfSize.Z)
        }
        
        local vp = {}
        local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
        local hasFront = false
        
        for i, world in ipairs(corners) do
            local screenPos, onScreen = Camera:WorldToViewportPoint(world)
            vp[i] = {pos = screenPos, on = onScreen}
            if onScreen and screenPos.Z > 0 then
                hasFront = true
                minX = math.min(minX, screenPos.X)
                maxX = math.max(maxX, screenPos.X)
                minY = math.min(minY, screenPos.Y)
                maxY = math.max(maxY, screenPos.Y)
            end
        end
        
        if not hasFront then
            for _, line in ipairs(lines) do line.Visible = false end
            nameText.Visible = false
            distanceText.Visible = false
            healthBg.Visible = false
            healthFg.Visible = false
            highlight.Enabled = false
            return
        end
        
        local width = maxX - minX
        local centerX = (minX + maxX) / 2
        
        local boxColor = Color3.new(1, 1, 1)
        if humanoid and humanoid.Health > 0 then
            local perc = humanoid.Health / (humanoid.MaxHealth > 0 and humanoid.MaxHealth or 1)
            boxColor = Color3.fromHSV(perc * 0.333, 0.5, 1)
        end
        
        if boxESPEnabled then
            local edges = {
                {1,2},{1,3},{1,5},{2,4},{2,6},{3,4},{3,7},{4,8},{5,6},{5,7},{6,8},{7,8}
            }
            for i, edge in ipairs(edges) do
                local aIdx, bIdx = edge[1], edge[2]
                local a, b = vp[aIdx], vp[bIdx]
                if a and b and a.on and b.on and a.pos and b.pos then
                    lines[i].From = Vector2.new(a.pos.X, a.pos.Y)
                    lines[i].To = Vector2.new(b.pos.X, b.pos.Y)
                    lines[i].Color = boxColor
                    lines[i].Thickness = thickness
                    lines[i].Visible = true
                else
                    lines[i].Visible = false
                end
            end
        else
            for _, line in ipairs(lines) do line.Visible = false end
        end
        
        local currentTopY = minY
        
        if healthESPEnabled and humanoid and humanoid.Health > 0 then
            local perc = humanoid.Health / (humanoid.MaxHealth > 0 and humanoid.MaxHealth or 1)
            local barHeight = 4
            local minBarWidth = 50
            local barWidth = math.max(width, minBarWidth)
            local healthX = width < minBarWidth and centerX - minBarWidth / 2 or minX
            healthBg.Position = Vector2.new(healthX, currentTopY - barHeight - 2)
            healthBg.Size = Vector2.new(barWidth, barHeight)
            healthBg.Visible = true
            healthFg.Position = Vector2.new(healthX, currentTopY - barHeight - 2)
            healthFg.Size = Vector2.new(barWidth * perc, barHeight)
            healthFg.Color = Color3.fromHSV(perc * 0.333, 1, 1)
            healthFg.Visible = true
            currentTopY = currentTopY - barHeight - 2
        else
            healthBg.Visible = false
            healthFg.Visible = false
        end
        
        nameText.Text = nameESPEnabled and player.Name or ""
        nameText.Position = Vector2.new(centerX, currentTopY - 16)
        nameText.Visible = nameESPEnabled
        
        distanceText.Text = distanceESPEnabled and string.format("%.0f studs", dist) or ""
        distanceText.Position = Vector2.new(centerX, maxY + 4)
        distanceText.Visible = distanceESPEnabled
        
        highlight.Enabled = highlightEnabled
    end)
    
    espPlayers[player] = {conn = conn, drawings = drawings}
end

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer and not espPlayers[player] then
        createESP(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function()
            task.wait(0.1)
            if not espPlayers[player] then
                createESP(player)
            end
        end)
        if player.Character and not espPlayers[player] then
            task.wait(0.1)
            createESP(player)
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if espPlayers[player] then
        for _, obj in pairs(espPlayers[player].drawings) do
            if obj and obj.Destroy then
                pcall(function() obj:Destroy() end)
            elseif typeof(obj) == "table" and obj.Visible ~= nil then
                obj.Visible = false
            end
        end
        if espPlayers[player].conn then
            pcall(function() espPlayers[player].conn:Disconnect() end)
        end
        espPlayers[player] = nil
    end
end)

task.spawn(function()
    while task.wait(1) do
        if highlightEnabled then
            updateHighlights()
        end
    end
end)











-- Walkspeed







-- Farm ถูพื้นกากๆ


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local ATMModule = require(ReplicatedStorage.Modules.Game.ATM.ATM)
local Net = require(ReplicatedStorage.Modules.Core.Net)

local Client = Players.LocalPlayer
_G.StopWalking = false
_G.AutoDeposit = false
_G.AutoSevenEleven = false

-- Bypass Net.get
if not _G.Bypass then
    local func = getupvalue(Net.get, 2)
    if func then
        setconstant(func, 3, "KUYIENGOKUYIENGO")
        setconstant(func, 4, "KUYIENGOKUYIENGO")
    end
    _G.Bypass = true
end

-- ========== ตัวแปรสำหรับระบบเดิน ==========
local currentTarget = nil
local isWalking = false
local checkPositionTask = nil
local currentDestination = nil

-- ========== UTILITY FUNCTIONS ==========
local function dist(pos)
    if not Client.Character or not Client.Character:FindFirstChild("HumanoidRootPart") then return math.huge end
    return (pos - Client.Character.HumanoidRootPart.Position).Magnitude
end

local function updateCharacter()
    local Character = Client.Character or Client.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")
    local RootPart = Character:WaitForChild("HumanoidRootPart")
    local Backpack = Client:WaitForChild("Backpack")
    return Character, Humanoid, RootPart, Backpack
end

-- ========== ตรวจจับการตายและเกิดใหม่ ==========
Client.CharacterAdded:Connect(function(newChar)
    print("🔄 ตัวละครเกิดใหม่ รีเซ็ตระบบ")
    task.wait(1)
    _G.StopWalking = false
    currentTarget = nil
    currentDestination = nil
    isWalking = false
    
    if checkPositionTask then
        task.cancel(checkPositionTask)
        checkPositionTask = nil
    end
end)

-- ========== ตรวจสอบและเดินกลับเมื่อกระเด็น ==========
local function startPositionCheck(targetPos)
    if checkPositionTask then
        task.cancel(checkPositionTask)
    end
    
    checkPositionTask = task.spawn(function()
        while _G.AutoDeposit and targetPos and not _G.StopWalking do
            task.wait(0.3)
            local char = Client.Character
            if not char then break end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then break end
            local humanoid = char:FindFirstChild("Humanoid")
            if not humanoid or humanoid.Health <= 0 then break end
            
            -- ถ้ากระเด็นออกจากตำแหน่งเกิน 5 หน่วย ให้เดินกลับ
            if dist(targetPos) > 5 then
                print("⚠️ กระเด็นออกจากตำแหน่ง กำลังเดินกลับ...")
                walkTo(targetPos, true)
            end
        end
    end)
end

local function stopPositionCheck()
    if checkPositionTask then
        task.cancel(checkPositionTask)
        checkPositionTask = nil
    end
end

-- ========== WALK FUNCTION (พร้อมล็อคตำแหน่ง) ==========
local function walkTo(destination, value)
    if not value then return false end
    if not destination then return false end
    if _G.StopWalking then return false end
    
    local character = Client.Character or Client.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    
    -- บันทึกตำแหน่งเป้าหมาย
    currentDestination = destination
    startPositionCheck(destination)

    local path = PathfindingService:CreatePath({
        AgentCanJump = true,
        AgentJumpHeight = 2,
        AgentHeight = 5.5,
        AgentRadius = 2.5,
    })

    local success = pcall(function()
        path:ComputeAsync(rootPart.Position, destination)
    end)

    if success and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if _G.StopWalking then return false end
            if humanoid.Health <= 0 then return false end
            
            -- เช็คระยะทาง ถ้าใกล้พอให้จบ
            if dist(destination) <= 3 then
                break
            end

            local finished = false
            local conn
            conn = humanoid.MoveToFinished:Connect(function()
                finished = true
                if conn then conn:Disconnect() end
            end)

            humanoid:MoveTo(wp.Position)

            if wp.Action == Enum.PathWaypointAction.Jump then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end

            local startTime = tick()
            repeat 
                task.wait()
                if _G.StopWalking then
                    if conn then conn:Disconnect() end
                    return false
                end
                if humanoid.Health <= 0 then
                    if conn then conn:Disconnect() end
                    return false
                end
                if tick() - startTime > 5 then
                    break
                end
            until finished or dist(destination) <= 3
        end
    end
    
    return true
end

local function StopWalkingFunc()
    _G.StopWalking = true
    if Client.Character and Client.Character:FindFirstChild("Humanoid") then
        Client.Character.Humanoid:MoveTo(Client.Character.HumanoidRootPart.Position)
    end
    stopPositionCheck()
    task.wait(0.1)
    _G.StopWalking = false
    currentDestination = nil
end

-- ========== AUTO DEPOSIT SYSTEM ==========
local DepositAmount = 200

local function GetMoney()
    local gui = Client:FindFirstChild("PlayerGui")
    if not gui then return 0 end
    local hud = gui:FindFirstChild("TopRightHud", true)
    if not hud then return 0 end
    local label = hud:FindFirstChild("MoneyTextLabel", true)
    if not label or not label.Text then return 0 end
    local text = label.Text:gsub("[$,]", "")
    local num = text:match("%d+")
    return tonumber(num) or 0
end

local function IsATMAvailable(atm)
    if not atm or not atm.states then return false end
    local ok, hackerVal, disabledVal = pcall(function()
        return atm.states.hacker and atm.states.hacker.get(), atm.states.disabled and atm.states.disabled.get()
    end)
    if not ok then return false end
    return hackerVal == nil and disabledVal == false
end

local function GetNearestATM()
    local char = Client.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local objects = ATMModule.class and ATMModule.class.objects
    if not objects then return nil end
    
    local nearest, nearestDist = nil, math.huge
    for _, atm in pairs(objects) do
        if atm and atm.instance and IsATMAvailable(atm) then
            local root = atm.instance:FindFirstChildWhichIsA("BasePart")
            if root then
                local d = (hrp.Position - root.Position).Magnitude
                if d < nearestDist then
                    nearestDist = d
                    nearest = atm
                end
            end
        end
    end
    return nearest
end

local function walkToATM(atm)
    local character = Client.Character or Client.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    local root = atm.instance:FindFirstChildWhichIsA("BasePart")
    if not root then return false end
    
    local targetPos = root.Position
    startPositionCheck(targetPos)
    
    local path = PathfindingService:CreatePath({
        AgentCanJump = true,
        AgentJumpHeight = 6,
        AgentHeight = 5,
        AgentRadius = 2,
        WaypointSpacing = 3
    })
    
    local success = pcall(function()
        path:ComputeAsync(rootPart.Position, targetPos)
    end)
    
    if success and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if humanoid.Health <= 0 then return false end
            if not IsATMAvailable(atm) then return false end
            if _G.StopWalking or not _G.AutoDeposit then return false end
            
            -- ถ้าใกล้ถึงแล้ว ให้จบ
            if dist(targetPos) <= 4 then
                break
            end
            
            humanoid:MoveTo(wp.Position)
            if wp.Action == Enum.PathWaypointAction.Jump then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            
            local reached = false
            local conn = humanoid.MoveToFinished:Connect(function()
                reached = true
                if conn then conn:Disconnect() end
            end)
            
            local start = tick()
            repeat
                task.wait()
                if _G.StopWalking or not _G.AutoDeposit then
                    if conn then conn:Disconnect() end
                    return false
                end
                if humanoid.Health <= 0 then
                    if conn then conn:Disconnect() end
                    return false
                end
                if tick() - start > 3 then
                    if conn then conn:Disconnect() end
                    break
                end
            until reached or dist(targetPos) <= 4
        end
    end
    
    -- รอให้ถึงระยะใกล้
    local timeout = tick() + 10
    repeat
        task.wait(0.1)
        if _G.StopWalking or not _G.AutoDeposit then return false end
        if humanoid.Health <= 0 then return false end
        if tick() > timeout then return false end
    until dist(targetPos) <= 6
    
    return true
end

local function IsNearATM(atm)
    local char = Client.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local root = atm.instance:FindFirstChildWhichIsA("BasePart")
    if not hrp or not root then return false end
    return (hrp.Position - root.Position).Magnitude <= 6
end

local function DepositMoney(amount)
    Net.get("transfer_funds", "hand", "bank", amount)
end

-- ========== SEVEN ELEVEN SYSTEM ==========
local function autoApplyJob()
    if Client:GetAttribute("Job") == "shelf_stocker" then 
        return true 
    end
    
    local jobGui = Client.PlayerGui:FindFirstChild("JobApplication")
    if jobGui and jobGui.Enabled then
        local frame = jobGui:FindFirstChild("JobApplicationFrame") or jobGui:FindFirstChild("Frame")
        local btn = frame and (frame:FindFirstChild("ApplyJob") or frame:FindFirstChild("Apply"))
        
        if frame and frame.Visible and btn and btn.Visible then
            pcall(function()
                btn.Selectable = true
                GuiService.SelectedObject = btn
                task.wait(0.1)
                VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                task.wait(0.05)
                VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
            end)
            task.wait(1.5)
            return Client:GetAttribute("Job") == "shelf_stocker"
        end
    end
    return false
end

local function AutoSevenElevenQuest(value)
    if not value then 
        StopWalkingFunc()
        return 
    end
    
    if _G.StopWalking then return end
    
    local Character, Humanoid, RootPart, Backpack = updateCharacter()
    if not RootPart or not Humanoid or Humanoid.Health <= 0 then return end
    
    if Client:GetAttribute("Job") == "shelf_stocker" then
        if not Backpack:FindFirstChild("BoxTool") and not Character:FindFirstChild("BoxTool") then
            local boxPos = Vector3.new(143, 255, 207)
            walkTo(boxPos, value)
            if dist(boxPos) < 5 then
                local fireproximityprompt = fireproximityprompt or getfenv().fireproximityprompt
                local boxPrompt = workspace:FindFirstChild("Map")
                    and workspace.Map:FindFirstChild("Tiles")
                    and workspace.Map.Tiles:FindFirstChild("GasStationTile")
                    and workspace.Map.Tiles.GasStationTile:FindFirstChild("Quick11")
                    and workspace.Map.Tiles.GasStationTile.Quick11:FindFirstChild("Interior")
                    and workspace.Map.Tiles.GasStationTile.Quick11.Interior:FindFirstChild("ShelfStockingJob")
                    and workspace.Map.Tiles.GasStationTile.Quick11.Interior.ShelfStockingJob:FindFirstChild("NormalBox")
                    and workspace.Map.Tiles.GasStationTile.Quick11.Interior.ShelfStockingJob.NormalBox:FindFirstChild("ProximityPrompt")
                if boxPrompt then
                    fireproximityprompt(boxPrompt, 3)
                end
            end
        elseif Character:FindFirstChild("BoxTool") then
            local shelves = workspace:FindFirstChild("Map")
                and workspace.Map:FindFirstChild("Tiles")
                and workspace.Map.Tiles:FindFirstChild("GasStationTile")
                and workspace.Map.Tiles.GasStationTile:FindFirstChild("Quick11")
                and workspace.Map.Tiles.GasStationTile.Quick11:FindFirstChild("Interior")
                and workspace.Map.Tiles.GasStationTile.Quick11.Interior:FindFirstChild("ShelfStockingJob")
                and workspace.Map.Tiles.GasStationTile.Quick11.Interior.ShelfStockingJob:FindFirstChild("Shelves")
            if shelves then
                for _, shelf in ipairs(shelves:GetChildren()) do
                    if not _G.AutoSevenEleven or _G.StopWalking then break end
                    if shelf:FindFirstChild("Attachment") then
                        walkTo(shelf.Position, value)
                        task.wait(1)
                    end
                end
            end
        else
            local tool = Backpack:FindFirstChild("BoxTool")
            if tool then Humanoid:EquipTool(tool) end
        end
    else
        local jobPos = Vector3.new(166.34539794921875, 255.19053649902344, 203.02333068847656)
        walkTo(jobPos, value)
        task.wait(0.5)
        autoApplyJob()
    end
end

-- ========== MAIN LOOP ==========
task.spawn(function()
    while task.wait(1) do
        if _G.AutoDeposit and not _G.AutoSevenEleven then
            if not _G.StopWalking then
                local money = GetMoney()
                if money >= DepositAmount then
                    _G.StopWalking = true
                    local atm = GetNearestATM()
                    if atm then
                        local success = walkToATM(atm)
                        if success and IsNearATM(atm) then
                            DepositMoney(DepositAmount)
                            task.wait(2)
                        end
                    end
                    _G.StopWalking = false
                    stopPositionCheck()
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if _G.AutoSevenEleven and not _G.AutoDeposit then
            if not _G.StopWalking then
                AutoSevenElevenQuest(true)
            end
        end
        task.wait(0.1)
    end
end)



-- hitaura





-- Anti kill

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local CharModule = require(game.ReplicatedStorage.Modules.Core.Char)


local enabled = false
local flickering = false
local undergroundBaseCFrame = nil
local DROP_DEPTH = -55
local MOVE_RADIUS = 10
local FLICKER_RATE = 0.1

local function isDowned()
    local hum = CharModule.get_hum()
    return hum and (hum:GetAttribute("HasBeenDowned") or hum:GetAttribute("IsDead") or hum.Health <= 0)
end

local function getHRP()
    local char = CharModule.current_char.get()
    if not char then return end
    return char:FindFirstChild("HumanoidRootPart")
end

local function teleportUnderground()
    local hrp = getHRP()
    if not hrp then return end
    local original = hrp.CFrame
    undergroundBaseCFrame = original + Vector3.new(0, DROP_DEPTH, 0)
    hrp.CFrame = undergroundBaseCFrame
end

local function flickerAndMove()
    if flickering then return end
    flickering = true
    task.spawn(function()
        while flickering and enabled and isDowned() do
            local hrp = getHRP()
            if hrp and undergroundBaseCFrame then
                local angle = math.random() * math.pi * 2
                local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * MOVE_RADIUS
                local randomPos = undergroundBaseCFrame.Position + offset
                hrp.CFrame = CFrame.new(randomPos)
                task.wait(0.05)
                hrp.CFrame = undergroundBaseCFrame
            end
            task.wait(FLICKER_RATE)
        end
        flickering = false
    end)
end

RunService.Heartbeat:Connect(function()
    if not enabled then return end
    if isDowned() then
        local hrp = getHRP()
        if hrp and not undergroundBaseCFrame then
            teleportUnderground()
        end
        flickerAndMove()
    else
        if undergroundBaseCFrame then
            local hrp = getHRP()
            if hrp then
                hrp.CFrame = undergroundBaseCFrame + Vector3.new(0, -DROP_DEPTH, 0)
            end
        end
        undergroundBaseCFrame = nil
        flickering = false
    end
end)



-- Esp items drop




local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local itemsFolder = ReplicatedStorage:WaitForChild("Items")
local dropFolder = workspace:WaitForChild("DroppedItems")

local RarityColors = {
    Common = Color3.fromRGB(200,200,200),
    Uncommon = Color3.fromRGB(86,176,62),
    Rare = Color3.fromRGB(0,162,255),
    Epic = Color3.fromRGB(170,85,255),
    Legendary = Color3.fromRGB(255,170,0),
    Omega = Color3.fromRGB(255,75,255),
    Money = Color3.fromRGB(0,255,0)
}

local ItemRarityDB = {}
local activeVisuals = {}
local espEnabled = false
local hiddenRarities = {}

local categories = {"gun","melee","throwable","consumable","farming","misc","rod","fish"}

local function registerItems(folder)
    for _, item in ipairs(folder:GetChildren()) do
        ItemRarityDB[item.Name] = item:GetAttribute("RarityName") or "Common"
    end
end

for _, category in ipairs(categories) do
    local cat = itemsFolder:FindFirstChild(category)
    if cat then registerItems(cat) end
end

local function getRarity(name)
    if name == "Money" then return "Money" end
    return ItemRarityDB[name] or "Common"
end

local function getColor(name, rarity)
    if name == "Money" then return Color3.fromRGB(0,255,0) end
    return RarityColors[rarity] or Color3.new(1,1,1)
end

local function shouldShowItem(item)
    if not espEnabled then return false end
    local rarity = getRarity(item.Name)
    for _, hidden in ipairs(hiddenRarities) do
        if rarity == hidden then return false end
    end
    return true
end

local function createVisual(item)
    if activeVisuals[item] then return end
    if not shouldShowItem(item) then return end

    local part = item:FindFirstChild("Handle") or item:FindFirstChildWhichIsA("BasePart")
    if not part then return end

    local rarity = getRarity(item.Name)
    local color = getColor(item.Name, rarity)
    local amount = item:GetAttribute("Amount") or 1

    local highlight = Instance.new("Highlight")
    highlight.Adornee = item
    highlight.FillTransparency = 0.3
    highlight.OutlineTransparency = 0
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.Parent = item

    local pointLight = Instance.new("PointLight")
    pointLight.Color = color
    pointLight.Range = 10
    pointLight.Brightness = 2
    pointLight.Parent = part

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = part
    billboard.Size = UDim2.new(0, 140, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = item

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1,0,0,22)
    nameLabel.Position = UDim2.new(0,0,0,0)
    nameLabel.TextScaled = false
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = 14
    nameLabel.TextColor3 = color
    nameLabel.TextStrokeTransparency = 0.3
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    nameLabel.Text = "[" .. item.Name .. "] x" .. amount
    nameLabel.Parent = billboard

    local distLabel = Instance.new("TextLabel")
    distLabel.BackgroundTransparency = 1
    distLabel.Size = UDim2.new(1,0,0,18)
    distLabel.Position = UDim2.new(0,0,0,22)
    distLabel.TextScaled = false
    distLabel.Font = Enum.Font.SourceSans
    distLabel.TextSize = 11
    distLabel.TextColor3 = Color3.fromRGB(255,255,255)
    distLabel.TextStrokeTransparency = 0.5
    distLabel.Text = "[0m]"
    distLabel.Parent = billboard

    local player = game.Players.LocalPlayer
    local updateConnection
    if player and player.Character then
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            updateConnection = RunService.RenderStepped:Connect(function()
                if not item or not item.Parent or not hrp or not hrp.Parent then
                    if updateConnection then updateConnection:Disconnect() end
                    return
                end
                local dist = (hrp.Position - part.Position).Magnitude
                distLabel.Text = string.format("[%.1fm]", dist)
            end)
        end
    end

    activeVisuals[item] = {
        Highlight = highlight,
        PointLight = pointLight,
        Billboard = billboard,
        UpdateConnection = updateConnection
    }
end

local function removeVisual(item)
    local visuals = activeVisuals[item]
    if visuals then
        if visuals.UpdateConnection then visuals.UpdateConnection:Disconnect() end
        if visuals.Highlight then visuals.Highlight:Destroy() end
        if visuals.PointLight then visuals.PointLight:Destroy() end
        if visuals.Billboard then visuals.Billboard:Destroy() end
        activeVisuals[item] = nil
    end
end

local function removeAllVisuals()
    for item, _ in pairs(activeVisuals) do
        removeVisual(item)
    end
    activeVisuals = {}
end

local function updateAllESP()
    removeAllVisuals()
    if espEnabled then
        for _, item in ipairs(dropFolder:GetChildren()) do
            if shouldShowItem(item) then
                createVisual(item)
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    if espEnabled then
        for _, item in ipairs(dropFolder:GetChildren()) do
            if not activeVisuals[item] and shouldShowItem(item) then
                createVisual(item)
            elseif activeVisuals[item] and not shouldShowItem(item) then
                removeVisual(item)
            end
        end
    end
end)

dropFolder.ChildRemoved:Connect(removeVisual)










-- Esp anti aim

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local IMAGEAntiaim_ID = "rbxassetid://94861926327838"
local EspVelocit_limit = 200
local RATIO_LIMIT = 0.35
local MIN_MOVE = 2
local DETECT_FRAMES = 3

local AntiAimEnabled = false

local ESPsAntiAim = {}
local LastData = {}
local Flags = {}

local function createESP(char, player)
    if ESPsAntiAim[player] then return end

    local head = char:FindFirstChild("Head")
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 60, 0, 60)
    billboard.AlwaysOnTop = true
    billboard.Adornee = head
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)

    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(0, 45, 0, 45)
    img.Position = UDim2.new(0.5, -22, 0, 0)
    img.BackgroundTransparency = 1
    img.Image = IMAGEAntiaim_ID
    img.Parent = billboard

    billboard.Parent = head

    ESPsAntiAim[player] = {
        gui = billboard,
        img = img,
        t = 0
    }
end

local function removeESP(player)
    if ESPsAntiAim[player] then
        ESPsAntiAim[player].gui:Destroy()
        ESPsAntiAim[player] = nil
    end
end

local function clearAllESP()
    for player in pairs(ESPsAntiAim) do
        removeESP(player)
    end
end

function updateAllESPVisibility()
    if not AntiAimEnabled then
        clearAllESP()
    end
end

RunService.RenderStepped:Connect(function(dt)
    if not AntiAimEnabled then return end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then

                local hrp = char.HumanoidRootPart
                local pos = hrp.Position
                local vel = hrp.Velocity.Magnitude

                local last = LastData[player]
                local suspicious = false

                if last then
                    local distance = (pos - last.pos).Magnitude
                    local expected = vel * dt

                    local ratio = 1
                    if expected > 0 then
                        ratio = distance / expected
                    end

                    if vel > EspVelocit_limit then
                        suspicious = true
                    end

                    if vel > EspVelocit_limit and distance < MIN_MOVE then
                        suspicious = true
                    end

                    if vel > EspVelocit_limit and ratio < RATIO_LIMIT then
                        suspicious = true
                    end
                end

                Flags[player] = Flags[player] or 0

                if suspicious then
                    Flags[player] += 1
                else
                    Flags[player] = 0
                end

                if Flags[player] >= DETECT_FRAMES then
                    createESP(char, player)
                else
                    removeESP(player)
                end

                LastData[player] = {pos = pos}
            else
                removeESP(player)
                LastData[player] = nil
                Flags[player] = nil
            end
        end
    end

    for _, data in pairs(ESPsAntiAim) do
        data.t += dt * 3
        local offset = math.sin(data.t) * 5
        data.img.Position = UDim2.new(0.5, -22, 0, offset)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
    LastData[player] = nil
    Flags[player] = nil
end)



-- Anti Aim


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = Players.LocalPlayer
local Char = require(game.ReplicatedStorage.Modules.Core.Char)

getgenv().AntiAim = false

RunService.Heartbeat:Connect(function()
    if getgenv().AntiAim then   
        local HumanoidModule = Char.get_hum()
        if HumanoidModule and not HumanoidModule:GetAttribute("HasBeenDowned") then 
            local RootPartModule = Char.get_hrp()
            if not RootPartModule then return end

            local A = RootPartModule.Velocity
            local B = RootPartModule.AssemblyLinearVelocity
            local C = RootPartModule.AssemblyAngularVelocity

            RootPartModule.Velocity = Vector3.new(
                math.random(-100000,999999),
                math.random(-100000,999999),
                math.random(-100000,999999)
            )

            RootPartModule.AssemblyLinearVelocity = Vector3.new(
                math.random(-100000,999999),
                math.random(-100000,999999),
                math.random(-100000,999999)
            )

            RootPartModule.AssemblyAngularVelocity = Vector3.new(
                math.random(-100000,999999),
                math.random(-100000,999999),
                math.random(-100000,999999)
            )

            RunService.RenderStepped:Wait()

            RootPartModule.Velocity = A
            RootPartModule.AssemblyLinearVelocity = B
            RootPartModule.AssemblyAngularVelocity = C
        end
    end
end)





local CombatTab = Window:Tab({Title = "COMBAT", Icon = "swords"})




CombatTab:Toggle({
    Title = "Silent Aim",
    Default = SilentAimEnabled,
    Callback = function(v)
        SilentAimEnabled = v
        if not v then
            billboard.Enabled = false
            tracer.Visible = false
            currentTarget = nil
            fovCircle.Visible = false  
        end
    end
})

CombatTab:Toggle({
    Title = "Show FOV",
    Description = "แสดงวง FOV",
    Default = ShowFOV,
    Callback = function(v)
        ShowFOV = v
        if not SilentAimEnabled then
            fovCircle.Visible = false
        end
    end
})

CombatTab:Slider({
    Title = "FOV Size",
    Step = 1,
    Value = {
        Min = 50,
        Max = 500,
        Default = FOV
    },
    Callback = function(v)
        FOV = v
    end
})

CombatTab:Dropdown({
    Title = "Aim Part",
    Description = "เลือกส่วนที่จะเล็ง",
    Values = { "Head", "HumanoidRootPart", "Torso" },
    Default = "Head",
    Callback = function(selected)
        AimPart = selected
    end
})

local function GetPlayerNames()
    local t = {}
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(t, plr.Name)
        end
    end
    return t
end

CombatTab:Dropdown({
    Title = "Save Friend",
    Description = "เลือกเพื่อนที่จะไม่ถูกเล็ง",
    Values = GetPlayerNames(),
    Multi = true,
    Default = {},
    Callback = function(selected)
        for _, plr in pairs(Players:GetPlayers()) do
            plr:SetAttribute("SilentAimIgnore", false)
        end
        for _, name in pairs(selected) do
            local plr = Players:FindFirstChild(name)
            if plr then
                plr:SetAttribute("SilentAimIgnore", true)
            end
        end
    end
})






local EspTab = Window:Tab({Title = "ESP", Icon = "eye"})



EspTab:Toggle({
    Title = "Box ESP",
    Desc = "กล่องสี่เหลี่ยมทุกคน",
    Default = false,
    Callback = function(state) boxESPEnabled = state end
})

EspTab:Toggle({
    Title = "Name ESP",
    Desc = "แสดงชื่อคนทั้งหมด",
    Default = false,
    Callback = function(state) nameESPEnabled = state end
})

EspTab:Toggle({
    Title = "Health ESP",
    Desc = "แสดงแถบเลือดของทุดคน",
    Default = false,
    Callback = function(state) healthESPEnabled = state end
})

EspTab:Toggle({
    Title = "Distance ESP",
    Desc = "แสดงระยะห่างจากทุกคน",
    Default = false,
    Callback = function(state) distanceESPEnabled = state end
})

EspTab:Toggle({
    Title = "Highlight",
    Desc = "ไฮไลท์สีขาวบนตัวทุกคน",
    Default = false,
    Callback = function(state)
        highlightEnabled = state
        if not state then
            for _, hl in pairs(highlights) do
                if hl and hl.Destroy then pcall(function() hl:Destroy() end) end
            end
            highlights = {}
        end
    end
})
EspTab:Toggle({
	Title = 'Esp Inventory',
	Desc = "แสดงไอเท็มในกระเป๋าทุกคน",
	Default = true,
	Callback = function(Value)
		_G.InventoryViewerEnabled = Value
		local Players = game:GetService('Players')
		local ReplicatedStorage = game:GetService('ReplicatedStorage')
		local Client = Players.LocalPlayer
		local function GetColorFromRarity(rarityName)
			local colors = {
				["Common"] = Color3.fromRGB(200, 200, 200),
				["Uncommon"] = Color3.fromRGB(86, 176, 62),
				["Rare"] = Color3.fromRGB(0, 162, 255),
				["Epic"] = Color3.fromRGB(170, 85, 255),
				["Legendary"] = Color3.fromRGB(255, 170, 0),
				["Omega"] = Color3.fromRGB(255, 75, 75)
			}
			return colors[rarityName] or Color3.fromRGB(255, 255, 255)
		end

		if Value then
			if not _G.ViewerRunning then
				_G.ViewerRunning = true
				task.spawn(function()
					while task.wait(0.2) do
						if not _G.InventoryViewerEnabled then
							continue
						end
						pcall(function()
							for _, v in pairs(Players:GetPlayers()) do
								if v ~= Client and v.Character and v.Character:FindFirstChild('HumanoidRootPart') then
									local root = v.Character.HumanoidRootPart
									local gui = root:FindFirstChild('ItemBillboard')
									if not gui then
										gui = Instance.new('BillboardGui')
										gui.Name = 'ItemBillboard'
										gui.AlwaysOnTop = true
										gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
										gui.Size = UDim2.new(0, 200, 0, 50)
										gui.StudsOffset = Vector3.new(0, -5, 0)
										gui.ExtentsOffset = Vector3.new(0, 1, 0)
										gui.LightInfluence = 1
										gui.Parent = root

										local bg = Instance.new('Frame')
										bg.Name = 'BG'
										bg.BackgroundTransparency = 1
										bg.Size = UDim2.new(1, 0, 1, 0)
										bg.AnchorPoint = Vector2.new(0.5, 0.5)
										bg.Position = UDim2.new(0.5, 0, 0.5, 0)
										bg.Parent = gui

										local layout = Instance.new('UIListLayout')
										layout.FillDirection = Enum.FillDirection.Horizontal
										layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
										layout.VerticalAlignment = Enum.VerticalAlignment.Center
										layout.Padding = UDim.new(0, 5)
										layout.Parent = bg
									end

									local bg = gui:FindFirstChild('BG')
									if not bg then
										continue
									end

									local Items = {}

									for _, child in pairs(bg:GetChildren()) do
										if child:IsA('Frame') then
											child:Destroy()
										end
									end

									-- loop item ใน backpack + character
									for _, container in pairs({
										v:FindFirstChild('Backpack'),
										v.Character
									}) do
										if container then
											for _, tool in pairs(container:GetChildren()) do
												if tool:IsA('Tool') and not tool:GetAttribute('JobTool') and not tool:GetAttribute('Locked') then
													local itemFolder = tool:GetAttribute('AmmoType') and ReplicatedStorage.Items.gun or ReplicatedStorage.Items.melee
													for _, z in pairs(itemFolder:GetChildren()) do
														if tool:GetAttribute('RarityName') == z:GetAttribute('RarityName') and tool:GetAttribute('RarityPrice') == z:GetAttribute('RarityPrice') then
															local imageId = z:GetAttribute('ImageId')
															if imageId then
																Items[z.Name] = true
																if not bg:FindFirstChild(z.Name .. '_bg') then
																	local iconBg = Instance.new('Frame')
																	iconBg.Name = z.Name .. '_bg'
																	iconBg.Size = UDim2.new(0, 34, 0, 34)
																	iconBg.BackgroundColor3 = GetColorFromRarity(z:GetAttribute('RarityName'))
																	iconBg.BackgroundTransparency = 1
																	iconBg.BorderSizePixel = 0
																	iconBg.Parent = bg

																	local bgImage = Instance.new('ImageLabel')
																	bgImage.Name = 'Background'
																	bgImage.Size = UDim2.new(1, 0, 1, 0)
																	bgImage.BackgroundTransparency = 1
																	bgImage.Image = 'rbxassetid://137066731814190'
																	bgImage.ImageColor3 = GetColorFromRarity(z:GetAttribute('RarityName'))
																	bgImage.ZIndex = 0
																	bgImage.Parent = iconBg

																	local corner = Instance.new('UICorner')
																	corner.CornerRadius = UDim.new(0.15, 0)
																	corner.Parent = iconBg

																	local icon = Instance.new('ImageLabel')
																	icon.Name = z.Name
																	icon.Image = imageId
																	icon.BackgroundTransparency = 1
																	icon.BorderSizePixel = 0
																	icon.Size = UDim2.new(0.85, 0, 0.85, 0)
																	icon.Position = UDim2.new(0.075, 0, 0.075, 0)
																	icon.Parent = iconBg

																	local corner2 = Instance.new('UICorner')
																	corner2.CornerRadius = UDim.new(0, 9)
																	corner2.Parent = icon
																end
															end
														end
													end
												end
											end
										end
									end

									gui.Enabled = _G.InventoryViewerEnabled

									for _, child in pairs(bg:GetChildren()) do
										if child:IsA('Frame') then
											local itemName = child.Name:gsub('_bg$', '')
											if not Items[itemName] then
												child:Destroy()
											end
										end
									end
								end
							end
						end)
					end
				end)
			end
		else
			for _, v in pairs(Players:GetPlayers()) do
				if v.Character and v.Character:FindFirstChild('HumanoidRootPart') then
					local gui = v.Character.HumanoidRootPart:FindFirstChild('ItemBillboard')
					if gui then
						gui:Destroy()
					end
				end
			end
		end
	end  
})


EspTab:Toggle({
    Title = "ESP Items Drop",
    Desc = "แสดงไอเทมที่ตกพื้น",
    Default = false,
    Callback = function(state)
        espEnabled = state
        updateAllESP()
    end
})

EspTab:Dropdown({
    Title = "Hide Rarity items drop",
    Desc = "เลือกระดับที่จะไม่แสดง สำหรับไอเท็มดรอบ",
    Values = { "Money", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Omega" },
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(option)
        hiddenRarities = option
        updateAllESP()
    end
})




EspTab:Toggle({
    Title = "ESP Anti aim",
    Desc = "แสดงคนที่เปิดกันล็อค",
    Default = false,
    Callback = function(state)
        AntiAimEnabled = state
        updateAllESPVisibility()
    end
})



local ChaterTab = Window:Tab({Title = "Character", Icon = "user"})

ChaterTab:Divider()

ChaterTab:Section({Title = "Body"})

local staminaConnection
ChaterTab:Toggle({
    Title = "infinity stamina",
    Desc = "สตามิน่าไม่จำกัด",
    Default = false,
    Callback = function(state)
        if state then
            if not getgenv().Bypassed then
                local NetModule = require(ReplicatedStorage.Modules.Core.Net)
                local func = debug.getupvalue(NetModule.get, 2)
                debug.setconstant(func, 3, '__Bypass')
                debug.setconstant(func, 4, '__Bypass')
                getgenv().Bypassed = true
            end

            repeat task.wait() until getgenv().Bypassed

            local NetModule = require(ReplicatedStorage.Modules.Core.Net)
            local SprintModule = require(ReplicatedStorage.Modules.Game.Sprint)

            if staminaConnection then staminaConnection:Disconnect() end

            staminaConnection = RunService.Heartbeat:Connect(function()
                NetModule.send("set_sprinting_1", true)
            end)

            local consume_stamina = SprintModule.consume_stamina
            local SprintBar = debug.getupvalue(consume_stamina, 2).sprint_bar
            local oldUpdate = SprintBar.update

            SprintBar.update = function(...)
                if getgenv().InfiniteStamina then
                    return 1 
                end
                return oldUpdate(...)
            end

            getgenv().InfiniteStamina = true
        else
            getgenv().InfiniteStamina = false
            if staminaConnection then
                staminaConnection:Disconnect()
                staminaConnection = nil
            end
        end
    end
})



ChaterTab:Toggle({Title = "jump power (กระโดดสูง)", Default = false, Callback = function(state)
    jumpEnabled = state
    if jumpConnection then jumpConnection:Disconnect() jumpConnection = nil end
    if state then
        jumpConnection = UserInputService.JumpRequest:Connect(function()
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                char.HumanoidRootPart.Velocity = Vector3.new(char.HumanoidRootPart.Velocity.X, jumpPower, char.HumanoidRootPart.Velocity.Z)
            end
        end)
    end
end})


ChaterTab:Slider({Title = "Jump power valu (ปรับความสูง)", Step = 5, Value = {Min = 20, Max = 80, Default = 70}, Callback = function(v) jumpPower = v end})
ChaterTab:Toggle({
    Title = "Anti Aim",
	Desc = "กันล็อค(ถ้าเปิดจะกระโดดสูงไม่ได้)",
    Flag = "antiaim",
    Value = false,
    Callback = function(v)
        getgenv().AntiAim = v
    end
})

ChaterTab:Divider()

ChaterTab:Section({Title = "Mod"})

local AntiKillToggle = ChaterTab:Toggle({
    Title = "Anti Kill",
	Desc = "กันตาย",
    Default = false,
    Callback = function(state)
        enabled = state
        if state then
            if WindUI then
                WindUI:Notify({
                    Title = "🛡️ Anti Kill Enabled",
                    Description = "",
                    Duration = 3
                })
            end
        else
            if WindUI then
                WindUI:Notify({
                    Title = "❌ Anti Kill Disabled",
                    Description = "",
                    Duration = 3
                })
            end
        end
    end
})


local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local hideNameEnabled = false

local function HideName()
    if not hideNameEnabled then return end
    local character = LocalPlayer.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local gui = hrp:FindFirstChild("CharacterBillboardGui")
        if gui then
            local nameLabel = gui:FindFirstChild("PlayerName")
            if nameLabel and nameLabel:IsA("TextLabel") then
                nameLabel.Visible = false
            end
        end
    end
end


ChaterTab:Toggle({
    Title = "Hide Name",
	Desc = "ปิดชื่อ(ปิดแค่เราคนเดียวคนอื่นเห็นเหมือนเดิม)",
    Default = false,
    Callback = function(state)
        hideNameEnabled = state
        if state then
            HideName()
        end
    end
})

LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    if hideNameEnabled then
        HideName()
    end
end)
local DroppedFolder = workspace:FindFirstChild("DroppedItems")
local NetModule = require(ReplicatedStorage.Modules.Core.Net)
local pick
ChaterTab:Toggle({
    Title = "Auto Pickup item",
	Desc = "ดูดของ",
    Default = false,
    Callback = function(state)
        if state then
            pick = task.spawn(function()
                while task.wait() do
                    for _, v in pairs(DroppedFolder:GetChildren()) do
                        if v:IsA("Model") and v:FindFirstChild("PickUpZone") then
                            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if root and (v:GetPivot().Position - root.Position).Magnitude < 50 then
                                NetModule.get("pickup_dropped_item", v)
                            end
                        end
                    end
                end
            end)
        else
            if pick then
                task.cancel(pick)
                pick = nil
            end
        end
    end
})

local plsraknet = Raknet or raknet
if not plsraknet then return end

ChaterTab:Toggle({
    Title = "Desync is op ",
    Desc = "ล่องหน",
    Default = false,
    Callback = function(state)
        if plsraknet and plsraknet.desync then
            plsraknet.desync(state)
        end
    end
})


local RagdollModule = require(game.ReplicatedStorage.Modules.Game.Ragdoll)
local Network = require(game.ReplicatedStorage.Modules.Core.Net)

local OldGet = RagdollModule.is_ragdolling.get

RagdollModule.is_ragdolling.get = function(...)
    local result = OldGet(...)
    if result == true and _G.AntiRagdoll then
        RagdollModule.is_ragdolling.set(false)
        Network.send("end_ragdoll_early")
        Network.send("clear_ragdoll")
    end
    return result
end

ChaterTab:Toggle({
    Title = "Anti Ragdoll",
	Desc = "กันกระเดนเปิดแล้วจะไม่กระเดน",
    Flag = "AntiRagdoll",
    Value = false,
    Callback = function(Value)
        _G.AntiRagdoll = Value
    end
})


-- มุดดิน


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Client = Players.LocalPlayer
local Char = require(ReplicatedStorage.Modules.Core.Char)

local EnabledSnapRunning = false
local YoffsetValue = 10
local snapThread = nil

local function GetDeltaY(baseY, currentY, offset)
    return (baseY - offset) - currentY
end

local function SetSnapState(state)
    EnabledSnapRunning = state
    getgenv().Snap = state

    if snapThread then
        task.cancel(snapThread)
        snapThread = nil
    end

    if state then
        snapThread = task.spawn(function()
            local baseY = nil

            while EnabledSnapRunning do
                task.wait(0.01)

                local char = Char.get()
                local hrp = Char.get_hrp()

                if char and hrp then
                    if not baseY then
                        baseY = hrp.Position.Y
                    end

                    local currentY = hrp.Position.Y
                    local deltaY = GetDeltaY(baseY, currentY, YoffsetValue)

                    char:PivotTo(hrp.CFrame * CFrame.new(0, deltaY, 0))
                else
                    baseY = nil
                end
            end
        end)
    end
end

ChaterTab:Toggle({
    Title = "Snap Under Map",
	Desc = "มุดดิน",
    Default = false,
    Callback = function(state)
        SetSnapState(state)
    end
})

ChaterTab:Keybind({
    Title = "Snap Keybind",
	Desc = "คีย์ลัดสำหรับPC",
    Flag = "snap_keybind",
    Value = "G",
    Callback = function()
        SetSnapState(not EnabledSnapRunning)
    end
})

ChaterTab:Slider({
    Title = "Snap Depth",
	Desc = "ระยะในการมุด",
    Flag = "snap_height",
    Step = 1,
    Value = { Min = 1, Max = 50, Default = YoffsetValue },
    Callback = function(value)
        YoffsetValue = value
    end
})

local carTab = Window:Tab({Title = "Car", Icon = "car"})



local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local function getVehicleRoot(vehicle)
    local p = vehicle.PrimaryPart
        or vehicle:FindFirstChild("PrimaryPart")
        or vehicle:FindFirstChild("Chassis")
        or vehicle:FindFirstChild("HumanoidRootPart")
        or vehicle:FindFirstChild("VehicleSeat")
        or vehicle:FindFirstChild("Body")
        or vehicle:FindFirstChild("Frame")
    if p and p:IsA("BasePart") then return p end
    for _, part in ipairs(vehicle:GetDescendants()) do
        if part:IsA("VehicleSeat") then return part end
    end
    for _, part in ipairs(vehicle:GetChildren()) do
        if part:IsA("BasePart") then return part end
    end
    return nil
end

local function PullMyVehicleOnly()
    local vehicles = workspace:FindFirstChild("Vehicles")
    if not vehicles then return end
    
    for _, vehicle in ipairs(vehicles:GetChildren()) do
        if vehicle:IsA("Model") then
            local ownerId = vehicle:GetAttribute("OwnerUserId")
            if ownerId and ownerId == LocalPlayer.UserId then
                local primary = getVehicleRoot(vehicle)
                if primary then
                    vehicle:SetPrimaryPartCFrame(rootPart.CFrame * CFrame.new(0, 0, -5))
                    WindUI:Notify({
                        Title = "ดึงรถสำเร็จ",
                        Content = "ดึงรถ " .. vehicle.Name .. " มาแล้ว",
                        Duration = 2,
                        Icon = "car"
                    })
                    return
                end
            end
        end
    end
    
    WindUI:Notify({
        Title = "ไม่พบรถ",
        Content = "ไม่พบรถที่เป็นของคุณ",
        Duration = 2,
        Icon = "car"
    })
end


carTab:Button({
    Title = "Bring your car", 
    Desc = "ดึงรถ(ของตัวเอง)", 
    Callback = function()
        PullMyVehicleOnly()
    end
})



local FarmTab = Window:Tab({Title = "FARM", Icon = "hand-coins"})



FarmTab:Divider()

FarmTab:Toggle({
    Title = "Auto Seven Eleven",
    Desc = "ออโต้ฟาม ยกกล่อง",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        _G.AutoSevenEleven = state
        if state then
            _G.AutoDeposit = false
        end
        if not state then
            _G.StopWalking = false
            stopPositionCheck()
        end
    end
})



FarmTab:Toggle({
    Title = "Auto Money Deposit",
    Desc = "ฝากเงินอัตโนมัติ",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        _G.AutoDeposit = state
        if state then
            _G.AutoSevenEleven = false
        end
        if not state then
            _G.StopWalking = false
            stopPositionCheck()
        end
    end
})

FarmTab:Input({
    Title = "DepositAmmo",
    Desc = "จำนวนเงินที่จะฝากแต่ละครั้ง",
    Value = "200",
    InputIcon = "bird",
    Type = "Input",
    Placeholder = "ใส่จำนวนเงิน",
    Callback = function(input)
        local num = tonumber(input)
        if num and num > 0 then
            DepositAmount = num
        end
    end
})














local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local SPEED = 260
local SPEED_MIN = 10
local SPEED_MAX = 500
local DEBOUNCE = 0.35
local SMOOTH = 0

local UI_WIDTH = 132
local UI_HEIGHT = 44
local SPEEDBOX_W = 56
local SPEEDBOX_H = 14

local freecam = false
local dummy = nil
local char, humanoid, hrp = nil, nil, nil
local saved = {}
local pendingStamp = 0
local allowMovement = false
local initialDummyCFrame = nil
local initialCameraCFrame = nil
local initialDistance = nil
local savedPartAnchors = {}
local savedPlatformStand = nil
local yaw = 0
local pitch = 0
local ROT_SENS = 0.0025
local lastInputPos = Vector2.new(0,0)
local ignoreNextInput = false

local function safeSet(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("Spectator: safeSet error:", err) end
end

local function createGui()
    if playerGui:FindFirstChild("SpectatorCleanGUI") then
        local g = playerGui.SpectatorCleanGUI
        return {Gui = g, Frame = g.Container, Toggle = g.Container.Toggle, SpeedBox = g.Container.SpeedBox, Info = g.Container.Info}
    end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SpectatorCleanGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    local frame = Instance.new("Frame")
    frame.Name = "Container"
    frame.Size = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT)
    frame.Position = UDim2.new(0, 8, 0, 8)
    frame.BackgroundColor3 = Color3.fromRGB(18,20,24)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(45,50,60); stroke.Transparency = 0.7; stroke.Thickness = 1
    local title = Instance.new("TextLabel", frame)
    title.Name = "Title"
    title.Size = UDim2.new(0.64, 0, 0, 22)
    title.Position = UDim2.new(0, 8, 0, 6)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextColor3 = Color3.fromRGB(235,235,235)
    title.Text = "ถอดจิต"
    title.TextXAlignment = Enum.TextXAlignment.Left
    local toggle = Instance.new("TextButton", frame)
    toggle.Name = "Toggle"
    toggle.Size = UDim2.new(0.32, -8, 0, 22)
    toggle.Position = UDim2.new(0.62, 0, 0, 6)
    toggle.BackgroundColor3 = Color3.fromRGB(36,40,48)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 12
    toggle.Text = "OFF"
    toggle.TextColor3 = Color3.fromRGB(220,220,220)
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0,6)
    Instance.new("UIStroke", toggle).Color = Color3.fromRGB(60,70,80)
    local speedBox = Instance.new("TextBox", frame)
    speedBox.Name = "SpeedBox"
    speedBox.Size = UDim2.new(0, SPEEDBOX_W, 0, SPEEDBOX_H)
    speedBox.Position = UDim2.new(0, 8, 1, -18)
    speedBox.BackgroundColor3 = Color3.fromRGB(34,38,46)
    speedBox.PlaceholderText = tostring(SPEED)
    speedBox.Text = ""
    speedBox.Font = Enum.Font.Gotham
    speedBox.TextSize = 12
    speedBox.TextColor3 = Color3.fromRGB(235,235,235)
    Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0,5)
    local sbstroke = Instance.new("UIStroke", speedBox)
    sbstroke.Color = Color3.fromRGB(55,65,75); sbstroke.Transparency = 0.8
    local info = Instance.new("TextLabel", frame)
    info.Name = "Info"
    info.Size = UDim2.new(1, -10, 0, 10)
    info.Position = UDim2.new(0, 5, 1, -10)
    info.BackgroundTransparency = 1
    info.Font = Enum.Font.Gotham
    info.TextSize = 10
    info.TextColor3 = Color3.fromRGB(210,195,110)
    info.Text = ""
    return {Gui = screenGui, Frame = frame, Toggle = toggle, SpeedBox = speedBox, Info = info}
end

local gui = createGui()
local toggleBtn = gui.Toggle
local speedBox = gui.SpeedBox
local infoLabel = gui.Info

local function makeDummy()
    local name = "SpecDummy_" .. player.UserId
    local ex = workspace:FindFirstChild(name)
    if ex then
        safeSet(function()
            if ex:IsA("BasePart") then
                ex.Anchored = true
                ex.CanCollide = false
                ex.Transparency = 1
            end
        end)
        return ex
    end
    local p = Instance.new("Part")
    p.Name = name
    p.Size = Vector3.new(1,1,1)
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 1
    p.Parent = workspace
    return p
end

local function saveHumanoidValues(h)
    if not h then return end
    saved.WalkSpeed = h.WalkSpeed
    saved.JumpPower = h.JumpPower
    saved.AutoRotate = h.AutoRotate
end

local function restoreHumanoidValues(h)
    if not h then return end
    safeSet(function() if saved.WalkSpeed then h.WalkSpeed = saved.WalkSpeed end end)
    safeSet(function() if saved.JumpPower then h.JumpPower = saved.JumpPower end end)
    safeSet(function() if saved.AutoRotate ~= nil then h.AutoRotate = saved.AutoRotate end end)
end

local function setInfo(text)
    if infoLabel and infoLabel.Parent then
        infoLabel.Text = tostring(text or "")
        delay(1.2, function()
            if infoLabel and infoLabel.Parent then infoLabel.Text = "" end
        end)
    end
end

local function tryApplySpeed(txt)
    if not txt or txt == "" then return end
    local n = tonumber(txt)
    if not n then setInfo("Invalid number"); return end
    n = math.clamp(n, SPEED_MIN, SPEED_MAX)
    SPEED = n
    speedBox.PlaceholderText = tostring(SPEED)
    speedBox.Text = ""
    setInfo("Speed set: " .. tostring(SPEED))
end

local function anchorAllCharacterParts(character)
    savedPartAnchors = {}
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            savedPartAnchors[part] = part.Anchored
            safeSet(function()
                if part.AssemblyLinearVelocity then part.AssemblyLinearVelocity = Vector3.new(0,0,0) end
                if part.AssemblyAngularVelocity then part.AssemblyAngularVelocity = Vector3.new(0,0,0) end
                part.Anchored = true
            end)
        end
    end
end

local function restoreAllCharacterParts()
    for part, prev in pairs(savedPartAnchors) do
        safeSet(function()
            if part and part.Parent then
                part.Anchored = (prev == true)
            end
        end)
    end
    savedPartAnchors = {}
end

UserInputService.InputChanged:Connect(function(input, processed)
    if not freecam then return end
    if allowMovement then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local pos
        if input.Position and typeof(input.Position) == "Vector2" then
            pos = input.Position
        else
            pos = UserInputService:GetMouseLocation()
        end
        if ignoreNextInput then
            lastInputPos = pos
            ignoreNextInput = false
            return
        end
        local d = pos - lastInputPos
        lastInputPos = pos
        yaw = yaw - d.X * ROT_SENS
        pitch = math.clamp(pitch - d.Y * ROT_SENS, -math.rad(89), math.rad(89))
    end
end)

local function startSpectator()
    char = player.Character or player.CharacterAdded:Wait()
    humanoid = char:FindFirstChildOfClass("Humanoid")
    hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then warn("Spectator: no humanoid/hrp"); return end
    dummy = makeDummy()
    local camCFrame = camera.CFrame
    dummy.CFrame = camCFrame
    initialDummyCFrame = dummy.CFrame
    initialCameraCFrame = camCFrame
    local rel = (camera.CFrame.Position - dummy.Position)
    local r = rel.Magnitude
    initialDistance = math.max(r, 1)
    local look = rel.Unit
    yaw = math.atan2(look.X, look.Z)
    pitch = math.asin(math.clamp(look.Y, -1, 1))
    saveHumanoidValues(humanoid)
    anchorAllCharacterParts(char)
    savedPlatformStand = humanoid.PlatformStand
    safeSet(function() humanoid.PlatformStand = true end)
    safeSet(function() humanoid.WalkSpeed = 0 end)
    safeSet(function() humanoid.JumpPower = 0 end)
    safeSet(function() humanoid.AutoRotate = false end)
    savedCameraFOV = camera.FieldOfView or 70
    camera.CameraType = Enum.CameraType.Scriptable
    camera.FieldOfView = savedCameraFOV
    lastInputPos = UserInputService:GetMouseLocation()
    ignoreNextInput = true
    freecam = true
    toggleBtn.Text = "ON"
    toggleBtn.TextColor3 = Color3.fromRGB(120,235,120)
    allowMovement = false
    setInfo("Locked. Move to unlock.")
end

local function stopSpectator()
    freecam = false
    local targetHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if targetHum then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = targetHum
    else
        camera.CameraType = Enum.CameraType.Custom
    end
    if savedCameraFOV then
        safeSet(function() camera.FieldOfView = savedCameraFOV end)
        savedCameraFOV = nil
    end
    initialDistance = nil
    initialDummyCFrame = nil
    initialCameraCFrame = nil
    lastInputPos = Vector2.new(0,0)
    ignoreNextInput = false
    safeSet(function()
        if humanoid and humanoid.Parent then
            if savedPlatformStand ~= nil then
                humanoid.PlatformStand = savedPlatformStand
            else
                humanoid.PlatformStand = false
            end
        end
    end)
    savedPlatformStand = nil
    restoreAllCharacterParts()
    if dummy and dummy.Parent then
        safeSet(function() dummy:Destroy() end)
        dummy = nil
    end
    if humanoid then restoreHumanoidValues(humanoid) end
    toggleBtn.Text = "OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(220,220,220)
    setInfo("Disabled")
end

RunService.RenderStepped:Connect(function(dt)
    if not freecam then return end
    if not dummy then return end
    if not allowMovement and initialDummyCFrame and initialCameraCFrame and initialDistance then
        safeSet(function() dummy.CFrame = initialDummyCFrame end)
        for part, _ in pairs(savedPartAnchors) do
            safeSet(function()
                if part and part.Parent then
                    if part.AssemblyLinearVelocity then part.AssemblyLinearVelocity = Vector3.new(0,0,0) end
                    if part.AssemblyAngularVelocity then part.AssemblyAngularVelocity = Vector3.new(0,0,0) end
                    part.Anchored = true
                end
            end)
        end
        local lx = math.sin(yaw) * math.cos(pitch)
        local ly = math.sin(pitch)
        local lz = math.cos(yaw) * math.cos(pitch)
        local lookFromDummy = Vector3.new(lx, ly, lz)
        local camPos = dummy.Position + lookFromDummy * initialDistance
        safeSet(function() camera.CFrame = CFrame.new(camPos, dummy.Position) end)
        if savedCameraFOV and camera.FieldOfView > savedCameraFOV then
            camera.FieldOfView = savedCameraFOV
        end
        local md = (humanoid and humanoid.MoveDirection) or Vector3.new()
        local mdMag = md.Magnitude
        local kbVec = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then kbVec = kbVec + camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then kbVec = kbVec - camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then kbVec = kbVec - camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then kbVec = kbVec + camera.CFrame.RightVector end
        local kbMag = kbVec.Magnitude
        local JOYSTICK_THRESHOLD = 0.14
        if mdMag > JOYSTICK_THRESHOLD or kbMag > 0.01 then
            allowMovement = true
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = dummy
            setInfo("Unlocked")
        end
        return
    end
    if camera.CameraSubject ~= dummy then safeSet(function() camera.CameraSubject = dummy end) end
    if savedCameraFOV and camera.FieldOfView > savedCameraFOV then camera.FieldOfView = savedCameraFOV end
    local md = (humanoid and humanoid.MoveDirection) or Vector3.new()
    local mdMag = md.Magnitude
    local kbVec = Vector3.new()
    if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then kbVec = kbVec + camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then kbVec = kbVec - camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then kbVec = kbVec - camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then kbVec = kbVec + camera.CFrame.RightVector end
    local kbMag = kbVec.Magnitude
    local moveVec
    if mdMag > 0.001 and humanoid then
        local camForward = camera.CFrame.LookVector
        local forwardFlat = Vector3.new(camForward.X, 0, camForward.Z)
        if forwardFlat.Magnitude < 1e-6 then forwardFlat = Vector3.new(0,0,-1) end
        forwardFlat = forwardFlat.Unit
        local camRight = camera.CFrame.RightVector
        local xAxis = md:Dot(camRight)
        local zAxis = md:Dot(forwardFlat)
        moveVec = (camRight * xAxis) + (camera.CFrame.LookVector * zAxis)
    else
        moveVec = kbVec
    end
    if moveVec.Magnitude < 1e-6 then return end
    local appliedSpeed = math.clamp(SPEED, SPEED_MIN, SPEED_MAX)
    local displacement = moveVec.Unit * appliedSpeed * dt * math.clamp(mdMag, 0, 1)
    local newC = dummy.CFrame + displacement
    if SMOOTH and SMOOTH > 0 then
        dummy.CFrame = dummy.CFrame:Lerp(newC, math.clamp(SMOOTH*60*dt, 0, 1))
    else
        dummy.CFrame = newC
    end
end)

toggleBtn.MouseButton1Click:Connect(function()
    if freecam then stopSpectator() else startSpectator() end
end)

speedBox:GetPropertyChangedSignal("Text"):Connect(function()
    pendingStamp = tick()
    local stamp = pendingStamp
    delay(DEBOUNCE, function()
        if pendingStamp == stamp then tryApplySpeed(speedBox.Text) end
    end)
end)
speedBox.FocusLost:Connect(function()
    tryApplySpeed(speedBox.Text)
end)

player.CharacterAdded:Connect(function(c)
    if savedPlatformStand ~= nil and humanoid and humanoid.Parent then
        safeSet(function() humanoid.PlatformStand = savedPlatformStand end)
        savedPlatformStand = nil
    end
    if next(savedPartAnchors) then restoreAllCharacterParts() end
    char = c
    humanoid = c:FindFirstChildOfClass("Humanoid")
    hrp = c:FindFirstChild("HumanoidRootPart")
    if freecam then stopSpectator() end
end)

speedBox.PlaceholderText = tostring(SPEED)
