-- CharacterCustomizer.client.lua
-- The first thing a new player sees. Full-screen menu shown automatically on join,
-- not gated behind a keybind. Lets the player pick hair, head, body, and voice,
-- then click START SHIFT to fire the StartShift remote — server teleports them
-- into the stand and unfreezes movement. Pressing M re-opens the menu later
-- (post-shift) so players can re-customize without restarting.
--
-- Note: the actual "freeze the player at the lobby pad" piece lives in
-- SpawnFlow.server.lua. This client only owns the UI and the remote fire.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipItemEvent = Remotes:WaitForChild("EquipItem")
local ProfileLoadedEvent = Remotes:WaitForChild("ProfileLoaded")
local StartShiftEvent = Remotes:WaitForChild("StartShift")

local player = Players.LocalPlayer
local DUTCH_BLUE = Color3.fromRGB(0, 90, 171)
local DUTCH_ORANGE = Color3.fromRGB(255, 122, 0)

-- ===== Customization data =====
local Hairstyles = {}
do
    local names = {
        "Buzz Cut", "Classic Side Part", "Slick Back", "Quiff", "Pompadour",
        "Undercut", "Top Knot", "Man Bun", "Mullet", "Mohawk",
        "Faux Hawk", "Dreads", "Cornrows", "Curly Fro", "Long Wavy",
        "Pixie Cut", "Bob Cut", "Lob", "Beach Waves", "Long Straight",
        "Pigtails", "Space Buns", "High Pony", "Low Pony", "Braids",
        "French Braid", "Crown Braid", "Half-Up Half-Down", "Bedhead Mess",
        "Anime Spikes", "Galaxy Tipped", "Rainbow Tips", "Frosted Tips",
    }
    for i, name in ipairs(names) do
        table.insert(Hairstyles, {id = "hair_" .. i, name = name, icon = "💇"})
    end
end

local Heads = {
    {id = "head_classic",     name = "Classic Bro",  icon = "😎"},
    {id = "head_frog",        name = "Frog",         icon = "🐸"},
    {id = "head_cat",         name = "Cat",          icon = "🐱"},
    {id = "head_toaster",     name = "Toaster",      icon = "🍞"},
    {id = "head_pumpkin",     name = "Pumpkin",      icon = "🎃"},
    {id = "head_robot",       name = "Robot",        icon = "🤖"},
    {id = "head_dino",        name = "Dinosaur",     icon = "🦖"},
    {id = "head_penguin",     name = "Penguin",      icon = "🐧"},
    {id = "head_alien",       name = "Lil' Alien",   icon = "👽"},
    {id = "head_marshmallow", name = "Marshmallow",  icon = "🍢"},
    {id = "head_donut",       name = "Donut",        icon = "🍩"},
    {id = "head_cup",         name = "Walking Cup",  icon = "☕"},
}

local BodyTypes = {
    {id = "body_short",   name = "Short",   icon = "🧒"},
    {id = "body_average", name = "Average", icon = "🧍"},
    {id = "body_tall",    name = "Tall",    icon = "🦒"},
    {id = "body_round",   name = "Round",   icon = "🫧"},
    {id = "body_lanky",   name = "Lanky",   icon = "🦴"},
}

local VoicePacks = {
    {id = "voice_chill",   name = "Chill Bro",   icon = "🌊"},
    {id = "voice_hyper",   name = "Hyper Bro",   icon = "⚡"},
    {id = "voice_zen",     name = "Zen Bro",     icon = "🧘"},
    {id = "voice_pirate",  name = "Pirate Bro",  icon = "🏴"},
    {id = "voice_robot",   name = "Robo Bro",    icon = "🤖"},
    {id = "voice_cowboy",  name = "Cowboy Bro",  icon = "🤠"},
    {id = "voice_baby",    name = "Baby Bro",    icon = "👶"},
    {id = "voice_grandma", name = "Grandma Bro", icon = "👵"},
}

local TabConfig = {
    Hair  = {items = Hairstyles, slot = "Hair"},
    Head  = {items = Heads,      slot = "Head"},
    Body  = {items = BodyTypes,  slot = "Body"},
    Voice = {items = VoicePacks, slot = "Voice"},
}
local TAB_ORDER = {"Hair", "Head", "Body", "Voice"}

-- ===== UI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CharacterCustomizer"
screenGui.ResetOnSpawn = false
screenGui.Enabled = true            -- shown immediately on join
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 50
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Dimmed full-screen backdrop so the world behind feels muted while customizing
local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
backdrop.BackgroundTransparency = 0.25
backdrop.BorderSizePixel = 0
backdrop.Parent = screenGui

local frame = Instance.new("Frame")
frame.Name = "Root"
frame.Size = UDim2.fromScale(0.78, 0.86)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
frame.Parent = screenGui
local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 14)
frameCorner.Parent = frame
local frameStroke = Instance.new("UIStroke")
frameStroke.Color = DUTCH_ORANGE
frameStroke.Thickness = 2
frameStroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 64)
title.Text = "Customize Your Broista"
title.BackgroundColor3 = DUTCH_BLUE
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 26
title.Parent = frame
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 14)
titleCorner.Parent = title

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0, 22)
subtitle.Position = UDim2.fromOffset(0, 64)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Pick your look, then start your shift."
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextSize = 14
subtitle.TextColor3 = Color3.fromRGB(220, 220, 230)
subtitle.Parent = frame

-- Avatar preview pane (left 40%). Uses ViewportFrame to render the live character.
local previewPane = Instance.new("Frame")
previewPane.Size = UDim2.new(0.40, -16, 1, -180)
previewPane.Position = UDim2.fromOffset(8, 96)
previewPane.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
previewPane.BorderSizePixel = 0
previewPane.Parent = frame
local previewCorner = Instance.new("UICorner")
previewCorner.CornerRadius = UDim.new(0, 10)
previewCorner.Parent = previewPane

local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.fromScale(1, 1)
viewport.BackgroundTransparency = 1
viewport.Parent = previewPane

local previewLabel = Instance.new("TextLabel")
previewLabel.Size = UDim2.new(1, 0, 0, 28)
previewLabel.Position = UDim2.new(0, 0, 1, -28)
previewLabel.BackgroundTransparency = 0.4
previewLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
previewLabel.Text = "Live Preview"
previewLabel.Font = Enum.Font.GothamMedium
previewLabel.TextSize = 14
previewLabel.TextColor3 = Color3.new(1, 1, 1)
previewLabel.Parent = previewPane

-- Tab bar + list (right 60%)
local rightPane = Instance.new("Frame")
rightPane.Size = UDim2.new(0.60, -16, 1, -180)
rightPane.Position = UDim2.new(0.40, 8, 0, 96)
rightPane.BackgroundTransparency = 1
rightPane.Parent = frame

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 40)
tabBar.BackgroundTransparency = 1
tabBar.Parent = rightPane

local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, 0, 1, -52)
listFrame.Position = UDim2.fromOffset(0, 48)
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel = 0
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.ScrollBarThickness = 6
listFrame.Parent = rightPane

local listLayout = Instance.new("UIGridLayout")
listLayout.CellSize = UDim2.fromOffset(210, 64)
listLayout.CellPadding = UDim2.fromOffset(8, 8)
listLayout.Parent = listFrame

local currentTab = "Hair"
local equipped = {} -- slot -> id, mirrored from server

local function clearList()
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
end

local function makeOption(item, slot)
    local isSelected = equipped[slot] == item.id
    local btn = Instance.new("TextButton")
    btn.Text = ""  -- layout uses child labels for icon/name/check
    btn.BackgroundColor3 = isSelected and DUTCH_BLUE or Color3.fromRGB(48, 48, 56)
    btn.AutoButtonColor = true
    btn.BorderSizePixel = 0
    btn.Parent = listFrame
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    local stroke = Instance.new("UIStroke")
    stroke.Color = isSelected and Color3.new(1, 1, 1) or Color3.fromRGB(70, 70, 80)
    stroke.Thickness = isSelected and 2 or 1
    stroke.Name = "OptionStroke"
    stroke.Parent = btn

    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 44, 1, 0)
    icon.Position = UDim2.fromOffset(8, 0)
    icon.BackgroundTransparency = 1
    icon.Text = item.icon or ""
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 26
    icon.TextColor3 = Color3.new(1, 1, 1)
    icon.Parent = btn

    local name = Instance.new("TextLabel")
    name.Name = "Name"
    name.Size = UDim2.new(1, -90, 1, 0)
    name.Position = UDim2.fromOffset(56, 0)
    name.BackgroundTransparency = 1
    name.Text = item.name
    name.Font = Enum.Font.GothamBold
    name.TextSize = 16
    name.TextColor3 = Color3.new(1, 1, 1)
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.Parent = btn

    local check = Instance.new("TextLabel")
    check.Name = "Check"
    check.Size = UDim2.new(0, 28, 1, 0)
    check.Position = UDim2.new(1, -32, 0, 0)
    check.BackgroundTransparency = 1
    check.Text = isSelected and "✓" or ""
    check.Font = Enum.Font.GothamBlack
    check.TextSize = 24
    check.TextColor3 = Color3.fromRGB(120, 230, 140)
    check.Parent = btn

    btn.MouseButton1Click:Connect(function()
        EquipItemEvent:FireServer(slot, item.id)
        equipped[slot] = item.id
        for _, sibling in ipairs(listFrame:GetChildren()) do
            if sibling:IsA("TextButton") then
                sibling.BackgroundColor3 = Color3.fromRGB(48, 48, 56)
                local sibCheck = sibling:FindFirstChild("Check")
                if sibCheck then sibCheck.Text = "" end
                local sibStroke = sibling:FindFirstChild("OptionStroke")
                if sibStroke then
                    sibStroke.Color = Color3.fromRGB(70, 70, 80)
                    sibStroke.Thickness = 1
                end
            end
        end
        btn.BackgroundColor3 = DUTCH_BLUE
        check.Text = "✓"
        stroke.Color = Color3.new(1, 1, 1)
        stroke.Thickness = 2
        -- Update the live preview character. The function lives in the
        -- viewport setup block below; expose it via _G to avoid a forward
        -- declaration through the rest of the file.
        if _G.CharacterCustomizerApplyLook then
            _G.CharacterCustomizerApplyLook(slot, item)
        end
    end)
end

local function refreshList()
    clearList()
    local cfg = TabConfig[currentTab]
    for _, item in ipairs(cfg.items) do
        makeOption(item, cfg.slot)
    end
end

for i, tabName in ipairs(TAB_ORDER) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1/#TAB_ORDER, -4, 1, 0)
    btn.Position = UDim2.new((i-1)/#TAB_ORDER, 2, 0, 0)
    btn.Text = tabName
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Parent = tabBar
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    btn.MouseButton1Click:Connect(function()
        currentTab = tabName
        refreshList()
    end)
end

-- ===== START YOUR SHIFT button (bottom of frame, large + green + centered) =====
local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0, 360, 0, 68)
startBtn.AnchorPoint = Vector2.new(0.5, 1)
startBtn.Position = UDim2.new(0.5, 0, 1, -16)
startBtn.Text = "▶ START YOUR SHIFT"
startBtn.Font = Enum.Font.GothamBlack
startBtn.TextSize = 26
startBtn.TextColor3 = Color3.new(1, 1, 1)
startBtn.BackgroundColor3 = Color3.fromRGB(40, 170, 80)
startBtn.AutoButtonColor = true
startBtn.Parent = frame
local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 14)
startCorner.Parent = startBtn
local startStroke = Instance.new("UIStroke")
startStroke.Color = Color3.new(1, 1, 1)
startStroke.Thickness = 3
startStroke.Parent = startBtn

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -32, 0, 18)
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -76)
hint.BackgroundTransparency = 1
hint.Text = "Tip: press M anytime to re-open this menu after your shift starts."
hint.Font = Enum.Font.Gotham
hint.TextSize = 12
hint.TextColor3 = Color3.fromRGB(180, 180, 190)
hint.Parent = frame

local started = false
startBtn.MouseButton1Click:Connect(function()
    if started then return end
    started = true
    StartShiftEvent:FireServer()
    screenGui.Enabled = false
end)

ProfileLoadedEvent.OnClientEvent:Connect(function(profile)
    if profile and profile.equipped then
        for slot, itemId in pairs(profile.equipped) do
            equipped[slot] = itemId
        end
        refreshList()
    end
end)

refreshList()

-- Allow re-opening the menu after the shift has started (so players can adjust look)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.M and started then
        screenGui.Enabled = not screenGui.Enabled
    end
end)

-- ===== Live avatar preview =====
-- Clones the player's character into the ViewportFrame so equipment changes
-- show in real time, and orbits the camera around it continuously. The
-- previewClone reference is exposed so `applyPreviewLook` (called from the
-- option-click handler) can color body parts to indicate selection.
local previewClone
local previewCenter = Vector3.new(0, 3, 0)
local previewAngle = 0

local function refreshPreview(character)
    -- Hard guard: nothing to clone if the caller passed nil.
    if not character then return end
    -- CharacterAdded can fire before the body parts finish parenting and
    -- before Archivable settles. Wait for the Humanoid so :Clone() returns
    -- a fully-populated model rather than nil/partial.
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then
        hum = character:WaitForChild("Humanoid", 5)
        if not hum then return end
    end

    local clone = character:Clone()
    if not clone then return end  -- Archivable=false on some descendant; bail

    -- Clear any previous preview only AFTER we've confirmed the new clone
    -- is valid, so a failed clone doesn't leave the viewport empty.
    for _, child in ipairs(viewport:GetChildren()) do
        if not child:IsA("Camera") then child:Destroy() end
    end

    previewClone = clone
    -- ViewportFrames don't run physics — anchor every part so the clone
    -- holds pose, and strip any local scripts the character carries.
    for _, descendant in ipairs(previewClone:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
        elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
            descendant:Destroy()
        end
    end
    previewClone.Parent = viewport

    local hrp = previewClone:FindFirstChild("HumanoidRootPart")
    previewCenter = hrp and hrp.Position or Vector3.new(0, 3, 0)

    local cam = viewport:FindFirstChildOfClass("Camera")
    if not cam then
        cam = Instance.new("Camera")
        cam.Parent = viewport
    end
    viewport.CurrentCamera = cam
end

-- Trigger the first refresh when the character is ready, and re-run
-- whenever it respawns so the preview never goes stale.
if player.Character then
    task.defer(function() refreshPreview(player.Character) end)
end
player.CharacterAdded:Connect(function(character)
    task.defer(function() refreshPreview(character) end)
end)

-- ===== Mobile / small-screen scaling =====
-- On screens narrower than 800px the desktop layout is unreadable; widen
-- the frame to 96% and apply a UIScale so all child labels shrink with it.
local mobileScale = Instance.new("UIScale")
mobileScale.Parent = frame
local function applyResponsiveSize()
    local width = screenGui.AbsoluteSize.X
    if width < 800 then
        frame.Size = UDim2.fromScale(0.96, 0.96)
        mobileScale.Scale = math.clamp(width / 1280, 0.55, 0.85)
    else
        frame.Size = UDim2.fromScale(0.78, 0.86)
        mobileScale.Scale = 1
    end
end
applyResponsiveSize()
screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyResponsiveSize)

-- Orbit the viewport camera around the preview character. ViewportFrames
-- don't tick physics, so we drive the camera ourselves on RenderStepped.
RunService.RenderStepped:Connect(function(dt)
    if not previewClone or not previewClone.Parent then return end
    local cam = viewport:FindFirstChildOfClass("Camera")
    if not cam then return end
    previewAngle += dt * 0.6
    local r = 7
    local lookAt = previewCenter + Vector3.new(0, 1, 0)
    local eye = previewCenter + Vector3.new(math.cos(previewAngle) * r, 2, math.sin(previewAngle) * r)
    cam.CFrame = CFrame.lookAt(eye, lookAt)
end)

-- Visual feedback when an option is clicked. Since we don't have real
-- HumanoidDescription asset IDs hooked up, we just tint the preview's body
-- parts (or attach a placeholder hair part) to indicate the selection.
local HEAD_COLORS = {
    head_classic     = Color3.fromRGB(255, 220, 180),
    head_frog        = Color3.fromRGB(80,  180, 100),
    head_cat         = Color3.fromRGB(200, 130, 80),
    head_toaster     = Color3.fromRGB(180, 180, 200),
    head_pumpkin     = Color3.fromRGB(255, 122, 0),
    head_robot       = Color3.fromRGB(150, 150, 160),
    head_dino        = Color3.fromRGB(60,  130, 80),
    head_penguin     = Color3.fromRGB(40,  40,  50),
    head_alien       = Color3.fromRGB(100, 220, 100),
    head_marshmallow = Color3.fromRGB(255, 240, 230),
    head_donut       = Color3.fromRGB(220, 150, 100),
    head_cup         = Color3.fromRGB(0,   90,  171),
}

local BODY_TINTS = {
    body_short   = {torso = Color3.fromRGB(255, 200, 100)},
    body_average = {torso = Color3.fromRGB(120, 180, 220)},
    body_tall    = {torso = Color3.fromRGB(150, 220, 150)},
    body_round   = {torso = Color3.fromRGB(220, 140, 200)},
    body_lanky   = {torso = Color3.fromRGB(220, 220, 120)},
}

local HAIR_PALETTE = {
    Color3.fromRGB(40,  30,  20),    -- dark brown
    Color3.fromRGB(180, 130, 60),    -- blonde
    Color3.fromRGB(220, 50,  50),    -- red
    Color3.fromRGB(20,  20,  20),    -- black
    Color3.fromRGB(180, 180, 180),   -- gray
    Color3.fromRGB(180, 80,  200),   -- purple
    Color3.fromRGB(50,  100, 220),   -- blue
    Color3.fromRGB(255, 122, 0),     -- orange
}

local function getOrCreateHairPart()
    if not previewClone then return nil end
    local existing = previewClone:FindFirstChild("PreviewHair")
    if existing then return existing end
    local head = previewClone:FindFirstChild("Head")
    if not head then return nil end
    local hairPart = Instance.new("Part")
    hairPart.Name = "PreviewHair"
    hairPart.Size = Vector3.new(2.2, 0.9, 2.2)
    hairPart.Anchored = true
    hairPart.CanCollide = false
    hairPart.TopSurface = Enum.SurfaceType.Smooth
    hairPart.BottomSurface = Enum.SurfaceType.Smooth
    hairPart.Material = Enum.Material.SmoothPlastic
    hairPart.CFrame = head.CFrame * CFrame.new(0, 0.65, 0)
    hairPart.Parent = previewClone
    return hairPart
end

local function applyPreviewLook(slot, item)
    if not previewClone then return end
    if slot == "Head" then
        local head = previewClone:FindFirstChild("Head")
        if head then
            head.Color = HEAD_COLORS[item.id] or Color3.fromRGB(255, 220, 180)
        end
    elseif slot == "Hair" then
        local hairPart = getOrCreateHairPart()
        if hairPart then
            local idx = (tonumber(string.match(item.id, "hair_(%d+)")) or 1)
            hairPart.Color = HAIR_PALETTE[(idx - 1) % #HAIR_PALETTE + 1]
        end
    elseif slot == "Body" then
        local tints = BODY_TINTS[item.id]
        if tints then
            local torso = previewClone:FindFirstChild("Torso") or previewClone:FindFirstChild("UpperTorso")
            if torso and tints.torso then torso.Color = tints.torso end
            local lower = previewClone:FindFirstChild("LowerTorso")
            if lower and tints.torso then lower.Color = tints.torso end
        end
    end
    -- Voice slot: no visible preview change (the audio identity is the change)
end

_G.CharacterCustomizerApplyLook = applyPreviewLook
