local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
repeat task.wait() until player and player.Parent

local function killAC(char)
    local hum = char:WaitForChild("Humanoid", 10)
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    if not hum or not hrp then return end
    for _, sig in ipairs({
        hum:GetPropertyChangedSignal("WalkSpeed"),
        hum:GetPropertyChangedSignal("HipHeight"),
        hrp:GetPropertyChangedSignal("CanCollide"),
    }) do
        local ok, conns = pcall(getconnections, sig)
        if ok and conns then
            for _, c in ipairs(conns) do pcall(function() c:Disable() end) end
        end
    end
    local ok, conns = pcall(getconnections, char.DescendantAdded)
    if ok and conns then
        for _, c in ipairs(conns) do
            local fn = c.Function
            local isAC = false
            if type(fn) == "function" and debug and debug.getconstants then
                local ok2, k = pcall(debug.getconstants, fn)
                if ok2 and k then
                    for _, v in pairs(k) do
                        if v == "BodyGyro" or v == "BodyVelocity" then isAC = true end
                    end
                end
            end
            if isAC then pcall(function() c:Disable() end)
            else pcall(function() c:Enable() end) end
        end
    end
end

if player.Character then killAC(player.Character) end
player.CharacterAdded:Connect(function(c) task.wait(1) killAC(c) end)
print("[ 999MS ] AC Bypass: ACTIVE")

local function importRelease(owner, repo, version, file)
    local tag = (version == "latest" and "latest/download" or "download/" .. version)
    return loadstring(game:HttpGetAsync(
        ("https://github.com/%s/%s/releases/%s/%s"):format(owner, repo, tag, file)
    ), file)()
end
local cascade = importRelease("cascadeui", "Cascade", "latest", "dist.luau")

local SkillCheck = { Enabled = false }
function SkillCheck:Start()
    if self.Enabled then return end
    local ev = ReplicatedStorage:WaitForChild("Events", 8)
    if not ev or not ev:FindFirstChild("SkillcheckUpdate") then return end
    local rf = ev.SkillcheckUpdate
    rf.OnClientInvoke = function(mg, ...)
        local mt = mg and mg:GetAttribute("MinigameType")
        if mt == "Circle" then return { hit = true, circle = "great" } end
        if mt == "Bar" or mt == "Line" then return { hit = true, bar = "great" } end
        return "supercomplete"
    end
    self.Enabled = true
end
function SkillCheck:Stop() self.Enabled = false end

local Flags = { SkillCheck = false, Noclip = false }
local UIToggles = {}

local SPEED, FLY_UP, FLY_SPEED = 30, 50, 30
local AWAY, SAFE_DIST, TICK, PIVOT_D = 50, 50, 0.1, 10
local THREAT, ARRIVE = 80, 30 / 4
local FIRE_WAIT, BUSY_TIMEOUT, EVADE_WAIT = 0.3, 15, 90

local busy, target, busyTick, fireTick = false, nil, 0, 0
local isNoclipping, isTransitioning = false, false
local isEvading, currentGen = false, nil

local function getChar()
    local c = player and player.Character
    if not c then return end
    return c, c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end
local function dist(a, b)
    if not a or not b then return math.huge end
    return (a - b).Magnitude
end
local function getPos(t)
    if not t then return nil end
    if typeof(t) == "Vector3" then return t end
    if t.PrimaryPart then return t.PrimaryPart.Position end
    local ok, p = pcall(function() return t:GetPivot() end)
    if ok and p then return p.Position end
    return nil
end
local function getGenPos(g)
    if not g then return nil end
    local tp = g:FindFirstChild("TeleportPositions")
    if tp then
        local tpp = tp:FindFirstChild("TeleportPosition")
        if tpp and tpp:IsA("BasePart") then return tpp.Position end
    end
    return getPos(g)
end
local function getMyModel()
    local c = player and player.Character
    if c and c.Parent then return c end
    local ig = workspace:FindFirstChild("InGamePlayers")
    if ig then
        for _, o in pairs(ig:GetChildren()) do
            if o:IsA("Model") and o:GetAttribute("UserId") == player.UserId then return o end
        end
    end
end
local function getChasing()
    local me = getMyModel()
    if not me then return false, nil end
    local room = workspace:FindFirstChild("CurrentRoom")
    if not room then return false, nil end
    local myRoot = me:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false, nil end
    local best, bestD = nil, math.huge
    for _, map in pairs(room:GetChildren()) do
        if map:IsA("Model") or map:IsA("Folder") then
            local mf = map:FindFirstChild("Monsters")
            if mf then
                for _, m in pairs(mf:GetChildren()) do
                    if m:IsA("Model") then
                        local cv = m:FindFirstChild("ChasingValue")
                        if cv and cv:IsA("ObjectValue") and cv.Value == me then
                            local mr = m:FindFirstChild("HumanoidRootPart")
                            if mr then
                                local d = dist(myRoot.Position, mr.Position)
                                if d < bestD then bestD = d; best = m end
                            end
                        end
                    end
                end
            end
        end
    end
    if best and bestD < THREAT then return true, best, bestD end
    return false, best, bestD
end
local function restoreCollision()
    if Flags.Noclip then return end
    local c = player and player.Character
    if c then
        for _, p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end
local function setBV(root, vel)
    local bv = root:FindFirstChild("_BV")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "_BV"
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = root
    end
    bv.Velocity = vel
end
local function clearBV(root)
    local bv = root:FindFirstChild("_BV")
    if bv then bv:Destroy() end
end

task.spawn(function()
    while task.wait(0.3) do
        if Flags.SkillCheck and not SkillCheck.Enabled then SkillCheck:Start()
        elseif not Flags.SkillCheck and SkillCheck.Enabled then SkillCheck:Stop() end
    end
end)
task.spawn(function()
    while task.wait(0.05) do
        if Flags.Noclip or isNoclipping then
            local c = player.Character
            if c then
                for _, p in pairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
                end
            end
        end
    end
end)

local function moveTo(t)
    local c, hum, root = getChar()
    if not c or not hum or not root then return "fail" end
    isNoclipping = true
    local function targetPos()
        if typeof(t) == "Vector3" then return t end
        if t:FindFirstChild("TeleportPositions") then return getGenPos(t) end
        return getPos(t)
    end
    local startPos = targetPos()
    if startPos then
        local d0 = (startPos - root.Position).Magnitude
        if d0 <= PIVOT_D then
            isNoclipping = false; restoreCollision(); clearBV(root)
            root.CFrame = CFrame.lookAt(startPos + Vector3.new(0, 3, 0), startPos)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            hum:MoveTo(root.Position)
            task.wait(0.1)
            return "reached"
        end
    end
    while true do
        task.wait(TICK)
        if isEvading then clearBV(root); hum:MoveTo(root.Position); return "evading" end
        if typeof(t) ~= "Vector3" and not t.Parent then
            clearBV(root); hum:MoveTo(root.Position)
            isNoclipping = false; restoreCollision()
            return "changed"
        end
        local pos = targetPos()
        if not pos then
            clearBV(root); hum:MoveTo(root.Position)
            isNoclipping = false; restoreCollision()
            return "fail"
        end
        local delta = pos - root.Position
        local d = delta.Magnitude
        if d <= PIVOT_D then
            isNoclipping = false; restoreCollision(); clearBV(root)
            root.CFrame = CFrame.lookAt(pos + Vector3.new(0, 3, 0), pos)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            hum:MoveTo(root.Position)
            task.wait(0.1)
            return "reached"
        end
        if d <= ARRIVE then
            clearBV(root); hum:MoveTo(root.Position)
            isNoclipping = false; restoreCollision()
            return "reached"
        end
        setBV(root, delta.Unit * SPEED)
    end
end

local function flyUpHover(h)
    local c, _, root = getChar()
    if not c or not root then return end
    local startY = root.Position.Y
    local targetY = startY + h
    while true do
        task.wait(TICK)
        if not root.Parent then return end
        if root.Position.Y >= targetY - 3 then break end
        setBV(root, Vector3.new(0, FLY_SPEED, 0))
    end
    clearBV(root)
    local bp = root:FindFirstChild("_BP")
    if bp then bp:Destroy() end
    bp = Instance.new("BodyPosition")
    bp.Name = "_BP"
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.P = 20000; bp.D = 500
    bp.Position = Vector3.new(root.Position.X, targetY, root.Position.Z)
    bp.Parent = root
    local startTime = tick()
    while true do
        task.wait(0.2)
        if not root.Parent then break end
        if tick() - startTime > 30 then break end
        local still, mon, md = getChasing()
        if not still then
            if mon and md and md >= AWAY then break end
            if not mon then break end
        end
        local cur = root.Position
        bp.Position = Vector3.new(cur.X, targetY, cur.Z)
    end
    bp:Destroy()
end

local function getClosestGen()
    local _, _, root = getChar()
    local room = workspace:FindFirstChild("CurrentRoom")
    if not root or not room then return nil end
    local best, bestD = nil, math.huge
    for _, m in ipairs(room:GetChildren()) do
        if m:IsA("Model") or m:IsA("Folder") then
            local f = m:FindFirstChild("Generators")
            if f then
                for _, g in ipairs(f:GetChildren()) do
                    if g:IsA("Model") then
                        local st = g:FindFirstChild("Stats")
                        local cp = st and st:FindFirstChild("Completed")
                        if cp and cp:IsA("BoolValue") and not cp.Value then
                            local pos = getGenPos(g)
                            if pos then
                                local d = dist(root.Position, pos)
                                if d < bestD then bestD = d; best = g end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end
local function allGenDone()
    local room = workspace:FindFirstChild("CurrentRoom")
    if not room then return false end
    local any = false
    for _, m in ipairs(room:GetChildren()) do
        if m:IsA("Model") or m:IsA("Folder") then
            local f = m:FindFirstChild("Generators")
            if f then
                for _, g in ipairs(f:GetChildren()) do
                    if g:IsA("Model") then
                        local st = g:FindFirstChild("Stats")
                        local cp = st and st:FindFirstChild("Completed")
                        if cp and cp:IsA("BoolValue") then
                            any = true
                            if not cp.Value then return false end
                        end
                    end
                end
            end
        end
    end
    return any
end
local function stopInt(g)
    if not g or not g.Parent then return end
    local st = g:FindFirstChild("Stats")
    if not st then return end
    local ev = st:FindFirstChild("StopInteracting")
    if ev and ev:IsA("RemoteEvent") then
        pcall(function() ev:FireServer("Stop") end)
    end
end
local function firePrompt(g)
    if tick() - fireTick < FIRE_WAIT then return false end
    fireTick = tick()
    local pr = g:FindFirstChildOfClass("ProximityPrompt")
    if not pr then
        for _, o in ipairs(g:GetDescendants()) do
            if o:IsA("ProximityPrompt") then pr = o; break end
        end
    end
    if not pr or not pr.Enabled then return false end
    if getChasing() then return false end
    local _, _, root = getChar()
    if root and pr.Parent and pr.Parent:IsA("BasePart") then
        local md = pr.MaxActivationDistance or 10
        if dist(root.Position, pr.Parent.Position) > md then return false end
    end
    return pcall(function()
        if pr.HoldDuration and pr.HoldDuration > 0 then
            pr:InputHoldBegin(); task.wait(pr.HoldDuration); pr:InputHoldEnd()
        else
            if fireproximityprompt then fireproximityprompt(pr)
            else pr:InputHoldBegin(); task.wait(0.05); pr:InputHoldEnd() end
        end
    end)
end
local function getElevator()
    local e = workspace:FindFirstChild("Elevators")
    return e and e:FindFirstChild("Elevator")
end

local Autofarm = { Enabled = false }
function Autofarm:Start()
    if self.Enabled then return end
    self.Enabled = true
    Flags.SkillCheck = true
    Flags.Noclip = true
    if UIToggles.SkillCheck then UIToggles.SkillCheck.Value = true end
    if UIToggles.Noclip then UIToggles.Noclip.Value = true end

    task.spawn(function()
        while self.Enabled do
            task.wait(0.3)
            if isEvading or isTransitioning then continue end
            local targeted, mon, md = getChasing()
            if not targeted then continue end
            if mon and md and md >= SAFE_DIST then continue end
            isEvading = true
            isNoclipping = true
            if currentGen and currentGen.Parent then stopInt(currentGen) end
            local _, _, root = getChar()
            if not root then
                isEvading = false; isNoclipping = false
                restoreCollision(); continue
            end
            flyUpHover(FLY_UP)
            local w = 0
            while w < EVADE_WAIT and self.Enabled do
                task.wait(0.3); w += 0.3
                local still, mon2, md2 = getChasing()
                if not still then
                    if mon2 and md2 and md2 >= AWAY then break end
                    if not mon2 then break end
                end
            end
            isNoclipping = false
            restoreCollision()
            isEvading = false
        end
    end)

    task.spawn(function()
        while self.Enabled do
            task.wait(0.2)
            if isEvading then continue end
            if busy and (tick() - busyTick) > BUSY_TIMEOUT then busy = false; target = nil end
            if busy then continue end
            if allGenDone() then
                local elev = getElevator()
                if elev then
                    busy = true; busyTick = tick(); target = elev
                    isTransitioning = true
                    moveTo(elev)
                    task.wait(0.5)
                    isTransitioning = false
                    busy = false; target = nil
                end
                task.wait(2); continue
            end
            local gen = getClosestGen()
            if not gen then task.wait(1); continue end
            if target == gen and busy then continue end
            busy = true; busyTick = tick(); target = gen
            currentGen = gen
            local res = moveTo(gen)
            if res == "evading" then
                currentGen = nil; busy = false; target = nil
                continue
            end
            local st = gen:FindFirstChild("Stats")
            local cp = st and st:FindFirstChild("Completed")
            if cp and cp:IsA("BoolValue") then
                while gen.Parent and not cp.Value and self.Enabled do
                    if isEvading then break end
                    if getChasing() then stopInt(gen); break end
                    local ok = firePrompt(gen)
                    task.wait(0.2)
                    if cp.Value then break end
                    if not ok then
                        local r2 = moveTo(gen)
                        if r2 == "evading" then break end
                        task.wait(0.3)
                    end
                    task.wait(0.3)
                end
            end
            busy = false; target = nil
            currentGen = nil
        end
    end)
end
function Autofarm:Stop()
    if not self.Enabled then return end
    self.Enabled = false
    Flags.SkillCheck = false
    Flags.Noclip = false
    if UIToggles.SkillCheck then UIToggles.SkillCheck.Value = false end
    if UIToggles.Noclip then UIToggles.Noclip.Value = false end
    isNoclipping = false; isEvading = false
    local _, _, root = getChar()
    if root then
        clearBV(root)
        local bp = root:FindFirstChild("_BP")
        if bp then bp:Destroy() end
    end
    restoreCollision()
    busy = false; target = nil
    isTransitioning = false
    currentGen = nil
end
function Autofarm:Toggle(state)
    if state == nil then state = not self.Enabled end
    if state then self:Start() else self:Stop() end
    return self.Enabled
end
getgenv().Autofarm = Autofarm

local flySpeed, rotationSpeed, accelFactor = 50, 0.15, 0.28
local flyEnabled, flying = false, false
local bodyVelocity, bodyGyro, flyConnection
local currentVelocity = Vector3.zero
local lastLookDirection = Vector3.new(0, 0, -1)
local currentKeybind = Enum.KeyCode.F

local function getCharacter() return player.Character or player.CharacterAdded:Wait() end
local function getRootPart()
    local char = getCharacter()
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
end
local function waitForControlModule()
    local ok, mod = pcall(function()
        return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
    end)
    return ok and mod or nil
end

local function startFly()
    local char = getCharacter()
    local root = getRootPart()
    if not char or not root then return end
    flying = true
    currentVelocity = Vector3.zero
    if bodyVelocity then bodyVelocity:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = root
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyGyro.P = 5e4; bodyGyro.D = 500
    bodyGyro.CFrame = root.CFrame
    bodyGyro.Parent = root
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = true
        for _, t in ipairs(humanoid:GetPlayingAnimationTracks()) do t:Stop() end
    end
    local controlModule = waitForControlModule()
    local camera = workspace.CurrentCamera
    lastLookDirection = camera.CFrame.LookVector
    if flyConnection then flyConnection:Disconnect() end
    flyConnection = RunService.Heartbeat:Connect(function()
        if not flyEnabled or not flying or not root or not root.Parent then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and not hum.PlatformStand then hum.PlatformStand = true end
        local moveVec = controlModule and controlModule:GetMoveVector() or Vector3.zero
        local targetVelocity = Vector3.zero
        if moveVec.Magnitude > 0.05 then
            targetVelocity = camera.CFrame:VectorToWorldSpace(moveVec).Unit * flySpeed
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            targetVelocity = targetVelocity + Vector3.new(0, flySpeed, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            targetVelocity = targetVelocity + Vector3.new(0, -flySpeed, 0)
        end
        currentVelocity = currentVelocity:Lerp(targetVelocity, accelFactor)
        if bodyVelocity then bodyVelocity.Velocity = currentVelocity end
        if bodyGyro then
            local smoothed = lastLookDirection:Lerp(camera.CFrame.LookVector, rotationSpeed)
            lastLookDirection = smoothed
            local targetCFrame = CFrame.lookAt(root.Position, root.Position + smoothed)
            bodyGyro.CFrame = bodyGyro.CFrame:Lerp(targetCFrame, 0.4)
        end
    end)
end
local function stopFly()
    flying = false
    currentVelocity = Vector3.zero
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    local char = getCharacter()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = getRootPart()
    if hum and root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end
end
local function setFlyEnabled(v)
    flyEnabled = v
    if v then startFly() else stopFly() end
end

local boostConns = {}
local boostActive = false
local function SpeedBoost(state)
    if state == nil then state = not boostActive end
    boostActive = state
    for _, c in ipairs(boostConns) do c:Disconnect() end
    table.clear(boostConns)
    if not state then return end
    local function lock()
        local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if h and h.WalkSpeed ~= 30 then h.WalkSpeed = 30 end
    end
    boostConns[#boostConns+1] = RunService.Heartbeat:Connect(lock)
    boostConns[#boostConns+1] = player.CharacterAdded:Connect(function()
        task.wait(0.1) lock()
    end)
    lock()
end

local function findInFolder(folderName)
    local out = {}
    local room = workspace:FindFirstChild("CurrentRoom")
    if not room then return out end
    for _, m in ipairs(room:GetChildren()) do
        if m:IsA("Model") or m:IsA("Folder") then
            local f = m:FindFirstChild(folderName)
            if f then
                for _, o in ipairs(f:GetChildren()) do
                    if o:IsA("Model") then table.insert(out, o) end
                end
            end
        end
    end
    return out
end
local function findPlayers()
    local out = {}
    local ig = workspace:FindFirstChild("InGamePlayers")
    if not ig then return out end
    for _, m in ipairs(ig:GetChildren()) do
        if m:IsA("Model") and m.Name ~= player.Name then
            table.insert(out, m)
        end
    end
    return out
end

local app = cascade.New({
    Theme = cascade.Themes.Dark,
    Accent = cascade.Accents.Blue,
    WindowPill = true,
})

local window = app:Window({
    Title = "999ms HUB | Dandy's world",
    Subtitle = "Made by 009.exe",
    Size = UDim2.fromOffset(600, 350),
    MinSize = Vector2.new(500, 300),
    MaxSize = Vector2.new(800, 500),
    Resizable = true,
    SideBarWidth = 180,
    Searching = false,
    Draggable = true,
    Dropshadow = true,
})

local secMain = window:Section({
    Title = "Main",
    Disclosure = true,
    Expanded = true,
})
local tabMain = secMain:Tab({
    Selected = true,
    Title = "Main",
    Icon = cascade.Symbols.squareStack3dUp,
})
local formMain = tabMain:Form()

do
    local row = formMain:Row({ SearchIndex = "Autofarm" })
    row:Left():TitleStack({ Title = "Autofarm", Subtitle = "ออโต้ฟาม" })
    UIToggles.Autofarm = row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, value)
            Autofarm:Toggle(value)
            app:Notification({
                Title = value and "Autofarm ON" or "Autofarm OFF",
                Subtitle = value and "เปิดครบทุกอย่าง" or "ปิดครบทุกอย่าง",
                Duration = 3,
            })
        end,
    })
    task.spawn(function()
        while task.wait(0.5) do
            if UIToggles.Autofarm and UIToggles.Autofarm.Value ~= Autofarm.Enabled then
                UIToggles.Autofarm.Value = Autofarm.Enabled
            end
        end
    end)
end

do
    local row = formMain:Row({ SearchIndex = "Skill Check" })
    row:Left():TitleStack({ Title = "Auto Skill Check", Subtitle = "ออโต้ผ่านมินิเกม" })
    UIToggles.SkillCheck = row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, value) Flags.SkillCheck = value end,
    })
end

do
    local gui = app.__instance or app
    local visible = true
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightControl then
            visible = not visible
            if gui and gui:IsA("ScreenGui") then gui.Enabled = visible end
        end
    end)
end

local tabVision = secMain:Tab({
    Title = "Vision",
    Icon  = cascade.Symbols.eye,
})
local formVision = tabVision:Form()

local function makeTag(model, tagName, color, withDist)
    local bb = model:FindFirstChild(tagName)
    if not bb then
        bb = Instance.new("BillboardGui")
        bb.Name = tagName
        bb.Size = UDim2.new(8, 0, 2, 0)
        bb.AlwaysOnTop = true
        bb.MaxDistance = 2000
        bb.Parent = model

        local tl = Instance.new("TextLabel")
        tl.Name = "Label"
        tl.Size = UDim2.new(1, 0, 1, 0)
        tl.BackgroundTransparency = 1
        tl.Font = Enum.Font.RobotoMono
        tl.TextScaled = true
        tl.Parent = bb

        local st = Instance.new("UIStroke")
        st.Thickness = 3
        st.Color = Color3.fromRGB(0, 0, 0)
        st.Parent = tl
    end

    local text = model.Name
    if withDist then
        local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local mr = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
        if myRoot and mr then
            local d = math.floor((myRoot.Position - mr.Position).Magnitude)
            text = string.format("%s [%d]", model.Name, d)
        end
    end

    bb.Label.Text = text
    bb.Label.TextColor3 = color
end

local function cleanTag(tag)
    for _, o in ipairs(workspace:GetDescendants()) do
        if (o:IsA("Highlight") or o:IsA("BillboardGui"))
           and (o.Name == "ESP_" .. tag or o.Name == "NT_" .. tag) then
            o:Destroy()
        end
    end
end

do
    local row = formVision:Row({ SearchIndex = "ESP Twisteds" })
    row:Left():TitleStack({ Title = "ESP Twisteds", Subtitle = "ไฮไลต์มอนสเตอร์ทั้งหมด" })

    local conn
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, on)
            if conn then conn:Disconnect() conn = nil end
            cleanTag("Twisteds")
            if not on then return end
            conn = RunService.Heartbeat:Connect(function()
                local col = Color3.fromRGB(255, 20, 20)
                for _, m in ipairs(findInFolder("Monsters")) do
                    local h = m:FindFirstChild("ESP_Twisteds")
                    if not h then
                        h = Instance.new("Highlight")
                        h.Name = "ESP_Twisteds"
                        h.OutlineColor = Color3.fromRGB(0, 0, 0)
                        h.FillTransparency = 0.35
                        h.Parent = m
                    end
                    h.FillColor = col
                    makeTag(m, "NT_Twisteds", col, true)
                end
            end)
        end,
    })
end

do
    local row = formVision:Row({ SearchIndex = "ESP Generators" })
    row:Left():TitleStack({ Title = "ESP Generators", Subtitle = "แดง = ยังไม่ซ่อม | เขียว = ซ่อมแล้ว" })

    local conn
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, on)
            if conn then conn:Disconnect() conn = nil end
            cleanTag("Generators")
            if not on then return end
            conn = RunService.Heartbeat:Connect(function()
                for _, m in ipairs(findInFolder("Generators")) do
                    local st = m:FindFirstChild("Stats")
                    local cp = st and st:FindFirstChild("Completed")
                    local done = cp and cp:IsA("BoolValue") and cp.Value
                    local col = done and Color3.fromRGB(0, 255, 80)
                                    or  Color3.fromRGB(255, 20, 20)

                    local h = m:FindFirstChild("ESP_Generators")
                    if not h then
                        h = Instance.new("Highlight")
                        h.Name = "ESP_Generators"
                        h.OutlineColor = Color3.fromRGB(0, 0, 0)
                        h.FillTransparency = 0.35
                        h.Parent = m
                    end
                    h.FillColor = col
                    makeTag(m, "NT_Generators", col, true)
                end
            end)
        end,
    })
end

do
    local row = formVision:Row({ SearchIndex = "ESP Items" })
    row:Left():TitleStack({ Title = "ESP Items", Subtitle = "ไฮไลต์ไอเทม + ระยะ" })

    local conn
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, on)
            if conn then conn:Disconnect() conn = nil end
            cleanTag("Items")
            if not on then return end
            conn = RunService.Heartbeat:Connect(function()
                local col = Color3.fromRGB(10, 30, 180)
                for _, m in ipairs(findInFolder("Items")) do
                    local h = m:FindFirstChild("ESP_Items")
                    if not h then
                        h = Instance.new("Highlight")
                        h.Name = "ESP_Items"
                        h.OutlineColor = Color3.fromRGB(0, 0, 0)
                        h.FillTransparency = 0.15
                        h.Parent = m
                    end
                    h.FillColor = col
                    makeTag(m, "NT_Items", col, true)
                end
            end)
        end,
    })
end

do
    local row = formVision:Row({ SearchIndex = "ESP Player Health" })
    row:Left():TitleStack({ Title = "ESP Player Health", Subtitle = "ไฮไลต์ผู้เล่น + โชว์เลือด" })

    local conn
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, on)
            if conn then conn:Disconnect() conn = nil end
            cleanTag("PlayerHP")
            if not on then return end
            conn = RunService.Heartbeat:Connect(function()
                for _, m in ipairs(findPlayers()) do
                    local hum = m:FindFirstChildOfClass("Humanoid")
                    local hp, maxHp = 0, 100
                    if hum then hp = math.floor(hum.Health); maxHp = math.floor(hum.MaxHealth) end
                    local pct = maxHp > 0 and hp / maxHp or 0
                    local col
                    if pct > 0.6 then col = Color3.fromRGB(80, 255, 120)
                    elseif pct > 0.3 then col = Color3.fromRGB(255, 220, 0)
                    else col = Color3.fromRGB(255, 20, 20) end

                    local h = m:FindFirstChild("ESP_PlayerHP")
                    if not h then
                        h = Instance.new("Highlight")
                        h.Name = "ESP_PlayerHP"
                        h.OutlineColor = Color3.fromRGB(0, 0, 0)
                        h.FillTransparency = 0.4
                        h.Parent = m
                    end
                    h.FillColor = col

                    local bb = m:FindFirstChild("NT_PlayerHP")
                    if not bb then
                        bb = Instance.new("BillboardGui")
                        bb.Name = "NT_PlayerHP"
                        bb.Size = UDim2.new(8, 0, 2, 0)
                        bb.AlwaysOnTop = true
                        bb.MaxDistance = 2000
                        bb.Parent = m

                        local tl = Instance.new("TextLabel")
                        tl.Name = "Label"
                        tl.Size = UDim2.new(1, 0, 1, 0)
                        tl.BackgroundTransparency = 1
                        tl.Font = Enum.Font.RobotoMono
                        tl.TextScaled = true
                        tl.Parent = bb

                        local st = Instance.new("UIStroke")
                        st.Thickness = 3
                        st.Color = Color3.fromRGB(0, 0, 0)
                        st.Parent = tl
                    end

                    local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    local mr = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                    local d = 0
                    if myRoot and mr then
                        d = math.floor((myRoot.Position - mr.Position).Magnitude)
                    end

                    bb.Label.Text = string.format("%s [%d/%d] %d", m.Name, hp, maxHp, d)
                    bb.Label.TextColor3 = col
                end
            end)
        end,
    })
end

local secMove = window:Section({
    Title = "Menu",
    Disclosure = false,
    Expanded = true,
})
local tabMove = secMove:Tab({
    Title = "Movement",
    Icon  = cascade.Symbols.figureWalk,
})
local formMove = tabMove:Form()

do
    local row = formMove:Row({ SearchIndex = "Enable Fly" })
    row:Left():TitleStack({ Title = "Fly", Subtitle = "บิน" })
    local tog
    tog = row:Right():Toggle({
        Value = flyEnabled,
        ValueChanged = function(_, v) setFlyEnabled(v) end,
    })
    _G.__syncFlyToggle = function(v) tog.Value = v end
end

do
    local row = formMove:Row({ SearchIndex = "Fly Speed" })
    row:Left():TitleStack({ Title = "Fly Speed", Subtitle = "ความเร็วในการบิน" })
    local valueLabel
    local stack = row:Right():HStack({
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Center,
    })
    stack:Slider({
        Minimum = 10, Maximum = 300, Value = flySpeed,
        ValueChanged = function(_, v)
            flySpeed = v
            if valueLabel then valueLabel.Text = string.format("%.0f", v) end
        end,
    })
    valueLabel = stack:Label({ Text = string.format("%.0f", flySpeed) })
end

do
    local row = formMove:Row({ SearchIndex = "Speed Boost" })
    row:Left():TitleStack({
        Title = "Speed Boost",
        Subtitle = "ล็อคความเร็ว = 30 ตลอดเวลา",
    })
    row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, v) SpeedBoost(v) end,
    })
end

do
    local row = formMove:Row({ SearchIndex = "Noclip" })
    row:Left():TitleStack({ Title = "Noclip", Subtitle = "ทะลุกำแพงตลอดเวลา" })
    UIToggles.Noclip = row:Right():Toggle({
        Value = false,
        ValueChanged = function(_, value)
            Flags.Noclip = value
            if not value then restoreCollision() end
        end,
    })
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == currentKeybind then
        setFlyEnabled(not flyEnabled)
        if _G.__syncFlyToggle then _G.__syncFlyToggle(flyEnabled) end
    end
end)

player.CharacterAdded:Connect(function()
    if flyEnabled then
        task.wait(1)
        startFly()
    end
end)

print("[ 999MS ] Cascade UI Loaded — F = Fly | RightCtrl = ซ่อน UI")