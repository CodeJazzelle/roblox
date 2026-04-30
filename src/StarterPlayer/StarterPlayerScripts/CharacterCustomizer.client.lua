-- CharacterCustomizer.client.lua
-- Lobby character customizer: hairstyles (30+), heads (classic + weird), bodies, voice packs.
-- Builds a ScreenGui at runtime, no pre-built UI required. Press M to toggle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipItemEvent = Remotes:WaitForChild("EquipItem")
local ProfileLoadedEvent = Remotes:WaitForChild("ProfileLoaded")

local player = Players.LocalPlayer
local DUTCH_BLUE = Color3.fromHex("#005AAB")

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
        table.insert(Hairstyles, {id = "hair_" .. i, name = name, assetId = 0})
    end
end

local Heads = {
    {id = "head_classic",     name = "Classic Bro",  weird = false},
    {id = "head_frog",        name = "Frog",         weird = true},
    {id = "head_cat",         name = "Cat",          weird = true},
    {id = "head_toaster",     name = "Toaster",      weird = true},
    {id = "head_pumpkin",     name = "Pumpkin",      weird = true},
    {id = "head_robot",       name = "Robot",        weird = true},
    {id = "head_dino",        name = "Dinosaur",     weird = true},
    {id = "head_penguin",     name = "Penguin",      weird = true},
    {id = "head_alien",       name = "Lil' Alien",   weird = true},
    {id = "head_marshmallow", name = "Marshmallow",  weird = true},
    {id = "head_donut",       name = "Donut",        weird = true},
    {id = "head_cup",         name = "Walking Cup",  weird = true},
}

local BodyTypes = {
    {id = "body_short",   name = "Short"},
    {id = "body_average", name = "Average"},
    {id = "body_tall",    name = "Tall"},
    {id = "body_round",   name = "Round"},
    {id = "body_lanky",   name = "Lanky"},
}

local VoicePacks = {
    {id = "voice_chill",   name = "Chill Bro"},
    {id = "voice_hyper",   name = "Hyper Bro"},
    {id = "voice_zen",     name = "Zen Bro"},
    {id = "voice_pirate",  name = "Pirate Bro"},
    {id = "voice_robot",   name = "Robo Bro"},
    {id = "voice_cowboy",  name = "Cowboy Bro"},
    {id = "voice_baby",    name = "Baby Bro"},
    {id = "voice_grandma", name = "Grandma Bro"},
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
screenGui.Enabled = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Root"
frame.Size = UDim2.fromScale(0.7, 0.8)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
frame.Parent = screenGui
local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 12)
frameCorner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 56)
title.Text = "Customize Your Broista"
title.BackgroundColor3 = DUTCH_BLUE
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.Parent = frame
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = title

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -16, 0, 40)
tabBar.Position = UDim2.fromOffset(8, 64)
tabBar.BackgroundTransparency = 1
tabBar.Parent = frame

local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, -16, 1, -120)
listFrame.Position = UDim2.fromOffset(8, 112)
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel = 0
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.ScrollBarThickness = 6
listFrame.Parent = frame

local listLayout = Instance.new("UIGridLayout")
listLayout.CellSize = UDim2.fromOffset(160, 64)
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
    local btn = Instance.new("TextButton")
    btn.Text = item.name
    btn.BackgroundColor3 = (equipped[slot] == item.id) and DUTCH_BLUE or Color3.fromRGB(48, 48, 56)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 14
    btn.AutoButtonColor = true
    btn.Parent = listFrame
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    btn.MouseButton1Click:Connect(function()
        EquipItemEvent:FireServer(slot, item.id)
        equipped[slot] = item.id
        btn.BackgroundColor3 = DUTCH_BLUE
        for _, sibling in ipairs(listFrame:GetChildren()) do
            if sibling ~= btn and sibling:IsA("TextButton") then
                sibling.BackgroundColor3 = Color3.fromRGB(48, 48, 56)
            end
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

ProfileLoadedEvent.OnClientEvent:Connect(function(profile)
    if profile and profile.equipped then
        for slot, itemId in pairs(profile.equipped) do
            equipped[slot] = itemId
        end
        refreshList()
    end
end)

refreshList()

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.M then
        screenGui.Enabled = not screenGui.Enabled
    end
end)
