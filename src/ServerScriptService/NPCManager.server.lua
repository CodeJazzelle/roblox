-- NPCManager.server.lua
-- Spawns 3-5 ambient pedestrian NPCs around the parking lot to make the
-- world feel alive. Each NPC is an R15 character produced via
-- Players:CreateHumanoidModelFromDescription with randomized skin / shirt /
-- pants colors, given a fun floating-name label, and assigned one of two
-- AI states:
--   * WALKING — Humanoid:MoveTo random parking-lot waypoints
--   * DANCING — loops one of three Roblox dance animations in place
--
-- Performance: total NPC count capped at MAX_NPCS, AI tick is ~1s. Each
-- NPC despawns after ~60s and respawns with a fresh appearance.
--
-- Cheer hook: when OrderManager fires its OrderCompleted BindableEvent,
-- the closest NPC plays an emote and shows a "Thanks!" chat bubble.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- Lazy require — OrderManager isn't strictly required (cheer is best-effort).
local function safeRequireOrderManager()
    local mod = script.Parent:FindFirstChild("OrderManager")
    if not mod then return nil end
    local ok, val = pcall(require, mod)
    if ok then return val end
    return nil
end

-- ============================================================
-- Tunables
-- ============================================================
local MAX_NPCS = 5
local INITIAL_DANCERS = 2
local SPAWN_TICK = 8     -- seconds between maintenance ticks
local MAX_NPC_LIFETIME = 60

local NAMES = {
    "Brad", "Karen with a Latte", "Skater Bro", "Yoga Mom", "Coffee Chad",
    "Dancing Sam", "Beach Bex", "Rebel Riley", "Grumpy Greg", "Sunshine Sage",
    "Mocha Max", "Lavender Lex", "Boba Bea", "Frosty Finn", "Pacific Paige",
}
local SKIN_COLORS = {
    Color3.fromRGB(255, 220, 180), Color3.fromRGB(180, 130, 90),
    Color3.fromRGB(140, 90, 60),   Color3.fromRGB(220, 180, 140),
    Color3.fromRGB(100, 70, 50),
}
local CLOTHING_COLORS = {
    Color3.fromRGB(0, 90, 171),    Color3.fromRGB(255, 122, 0),
    Color3.fromRGB(255, 200, 50),  Color3.fromRGB(220, 60, 90),
    Color3.fromRGB(80, 180, 100),  Color3.fromRGB(180, 80, 200),
    Color3.fromRGB(100, 220, 220),
}
local DANCE_ANIMS = {
    "rbxassetid://507771019",  -- dance1
    "rbxassetid://507776043",  -- dance2
    "rbxassetid://507777268",  -- dance3
}

-- Parking-lot bounds for random walk targets (matches BuildStand layout)
local PARKING_X_MIN, PARKING_X_MAX = -50, 50
local PARKING_Z_MIN, PARKING_Z_MAX = 25, 50
local SPAWN_Y = 4   -- HRP height above floor

-- ============================================================
-- Helpers
-- ============================================================
local function pick(list)
    return list[math.random(1, #list)]
end

local function randomTarget()
    return Vector3.new(
        math.random(PARKING_X_MIN, PARKING_X_MAX),
        SPAWN_Y,
        math.random(PARKING_Z_MIN, PARKING_Z_MAX)
    )
end

local function applyColors(model, skin, shirt, pants)
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            local n = descendant.Name
            if n == "Head" or n:find("Hand") or n:find("Arm") or n:find("Leg") or n:find("Foot") or n == "UpperTorso" or n == "LowerTorso" then
                if n:find("Hand") or n:find("Arm") or n == "Head" then
                    descendant.Color = skin
                elseif n:find("Leg") or n:find("Foot") then
                    descendant.Color = pants
                else
                    descendant.Color = shirt
                end
            end
        end
    end
end

local function addNameLabel(model, name)
    local head = model:FindFirstChild("Head")
    if not head then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "NPCNameLabel"
    bb.Adornee = head
    bb.Size = UDim2.new(0, 180, 0, 28)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 80
    bb.Parent = head
    -- Tag so mobile clients can disable cosmetic NPC names to keep the
    -- screen clean (see MobileLabelFilter.client.lua).
    CollectionService:AddTag(bb, "NPCNameLabel")

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    label.BackgroundTransparency = 0.4
    label.Text = name
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.5
    label.Parent = bb
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = label
end

local function showChatBubble(model, text, duration)
    local head = model:FindFirstChild("Head")
    if not head then return end
    local bb = Instance.new("BillboardGui")
    bb.Adornee = head
    bb.Size = UDim2.new(0, 220, 0, 44)
    bb.StudsOffset = Vector3.new(0, 4.5, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 60
    bb.Parent = head

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    frame.BorderSizePixel = 0
    frame.Parent = bb
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -8, 1, -4)
    label.Position = UDim2.fromOffset(4, 2)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(20, 20, 20)
    label.TextWrapped = true
    label.Parent = frame

    task.delay(duration or 3.5, function()
        if bb.Parent then bb:Destroy() end
    end)
end

local function playAnimation(humanoid, animId)
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end
    local anim = Instance.new("Animation")
    anim.AnimationId = animId
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return nil end
    track.Looped = true
    track:Play()
    return track
end

-- ============================================================
-- NPC creation
-- ============================================================
local function makeNPC(state)
    local desc = Instance.new("HumanoidDescription")
    desc.WidthScale = 0.95
    desc.HeightScale = math.random(95, 110) / 100
    desc.HeadScale = 1
    desc.DepthScale = 1
    desc.BodyTypeScale = 1

    local ok, model = pcall(function()
        return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
    end)
    if not ok or not model then
        warn("[NPCManager] CreateHumanoidModelFromDescription failed: " .. tostring(model))
        return nil
    end

    local skin  = pick(SKIN_COLORS)
    local shirt = pick(CLOTHING_COLORS)
    local pants = pick(CLOTHING_COLORS)
    applyColors(model, skin, shirt, pants)

    local name = pick(NAMES)
    model.Name = "NPC_" .. name:gsub("%s+", "")
    addNameLabel(model, name)

    -- Don't collide with players so NPCs can't block the player's path
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CanCollide = false end
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CollisionGroup = "Default"
            -- Soft-disable collision against players by setting on each
            -- limb. Simplest: just keep CanCollide on for floor support
            -- but prevent player-NPC pushing via Massless.
            part.Massless = true
        end
    end

    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = math.random(8, 14)
        hum.AutoRotate = true
    end

    -- Spawn in
    local spawnCFrame = CFrame.new(randomTarget())
    model:PivotTo(spawnCFrame)
    model.Parent = Workspace

    return model
end

-- ============================================================
-- AI loops
-- ============================================================
local function walkingLoop(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    while model.Parent and hum and hum.Health > 0 do
        local target = randomTarget()
        hum:MoveTo(target)
        local reached = hum.MoveToFinished:Wait()
        if not model.Parent then return end
        task.wait(math.random(1, 4))
    end
end

local function dancingLoop(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local track = playAnimation(hum, pick(DANCE_ANIMS))
    while model.Parent and hum.Health > 0 do
        task.wait(8 + math.random())
        if not model.Parent then return end
        if track then track:Stop() end
        track = playAnimation(hum, pick(DANCE_ANIMS))
    end
    if track then track:Stop() end
end

-- ============================================================
-- Spawn / despawn loop
-- ============================================================
local activeNPCs = {}  -- model -> {state, spawnedAt}

local function spawnOne(forceState)
    if #activeNPCs >= MAX_NPCS then return end
    local danceCount = 0
    for _, info in pairs(activeNPCs) do
        if info.state == "DANCING" then danceCount += 1 end
    end
    local state = forceState
        or (danceCount < INITIAL_DANCERS and "DANCING")
        or "WALKING"

    local model = makeNPC(state)
    if not model then return end
    activeNPCs[model] = {state = state, spawnedAt = tick()}

    if state == "DANCING" then
        task.spawn(function() dancingLoop(model) end)
    else
        task.spawn(function() walkingLoop(model) end)
    end
end

task.spawn(function()
    -- Initial population
    for _ = 1, MAX_NPCS do spawnOne() end

    while true do
        task.wait(SPAWN_TICK)

        -- Recycle stale NPCs
        for model, info in pairs(activeNPCs) do
            if not model.Parent then
                activeNPCs[model] = nil
            elseif tick() - info.spawnedAt > MAX_NPC_LIFETIME then
                model:Destroy()
                activeNPCs[model] = nil
            end
        end

        -- Refill
        for _ = 1, MAX_NPCS do
            local count = 0
            for _ in pairs(activeNPCs) do count += 1 end
            if count >= MAX_NPCS then break end
            spawnOne()
        end
    end
end)

-- ============================================================
-- Cheer hook — when an order completes, the nearest NPC reacts
-- ============================================================
local function findNearestNPC(position)
    local nearest, nearestDist = nil, math.huge
    for model in pairs(activeNPCs) do
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp then
            local d = (hrp.Position - position).Magnitude
            if d < nearestDist then
                nearest, nearestDist = model, d
            end
        end
    end
    return nearest
end

local function onOrderCompleted(_, player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local npc = findNearestNPC(hrp.Position)
    if npc then
        showChatBubble(npc, "Thanks bro! 🙌", 3)
    end
end

local OrderManager = safeRequireOrderManager()
if OrderManager and OrderManager.OrderCompleted then
    OrderManager.OrderCompleted.Event:Connect(onOrderCompleted)
end

print("[NPCManager] Ambient pedestrians active (" .. MAX_NPCS .. " max)")
