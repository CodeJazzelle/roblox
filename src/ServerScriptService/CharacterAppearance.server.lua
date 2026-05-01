-- CharacterAppearance.server.lua
-- Mutates the player's actual Character based on their equipped customizer
-- selections. Single source of truth: PlayerData:Get(player).equipped
-- (NOT the EquipItem remote args), so this can't desync with the
-- bookkeeping write that EconomyManager already does.
--
-- Triggers re-application on:
--   * Players.PlayerAdded (bind to that player's CharacterAdded)
--   * EquipItem.OnServerEvent (any equip change for any player)
--   * Player.CharacterAdded (respawn after death — preserve look)
--
-- Slots and what each one mutates:
--   Head    → Character.Head.Color set to a per-option Color3
--   Hair    → Character.EquippedHair part welded to Head, color from palette
--   Body    → Humanoid:ApplyDescription with scaling values (R15 only).
--             R6 fallback: tint UpperTorso/Torso instead of scaling.
--   Voice   → player:SetAttribute("VoicePack", id) — no visual change.
--
-- Asset IDs aren't needed; everything is procedural color/scale changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipItemEvent = Remotes:WaitForChild("EquipItem")

-- ===== Per-option lookups (mirror what the customizer client uses) =====
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

local HAIR_PALETTE = {
    Color3.fromRGB(40,  30,  20),
    Color3.fromRGB(180, 130, 60),
    Color3.fromRGB(220, 50,  50),
    Color3.fromRGB(20,  20,  20),
    Color3.fromRGB(180, 180, 180),
    Color3.fromRGB(180, 80,  200),
    Color3.fromRGB(50,  100, 220),
    Color3.fromRGB(255, 122, 0),
}

-- HumanoidDescription scaling values (R15 only).
local BODY_SCALES = {
    body_short   = {height = 0.85, width = 1.00, depth = 1.00, head = 1.00, body = 1.00},
    body_average = {height = 1.00, width = 1.00, depth = 1.00, head = 1.00, body = 1.00},
    body_tall    = {height = 1.15, width = 0.95, depth = 1.00, head = 1.00, body = 0.95},
    body_round   = {height = 1.00, width = 1.20, depth = 1.20, head = 1.00, body = 1.20},
    body_lanky   = {height = 1.10, width = 0.85, depth = 0.85, head = 1.00, body = 0.85},
}

-- R6 fallback: tint torso color when scaling isn't available.
local BODY_R6_TINTS = {
    body_short   = Color3.fromRGB(255, 200, 100),
    body_average = Color3.fromRGB(120, 180, 220),
    body_tall    = Color3.fromRGB(150, 220, 150),
    body_round   = Color3.fromRGB(220, 140, 200),
    body_lanky   = Color3.fromRGB(220, 220, 120),
}

-- ===== Mutation primitives =====
local function getOrCreateHair(character)
    local existing = character:FindFirstChild("EquippedHair")
    if existing then return existing end
    local head = character:FindFirstChild("Head")
    if not head then return nil end
    local hair = Instance.new("Part")
    hair.Name = "EquippedHair"
    hair.Size = Vector3.new(2.2, 0.9, 2.2)
    hair.CanCollide = false
    hair.Massless = true
    hair.TopSurface = Enum.SurfaceType.Smooth
    hair.BottomSurface = Enum.SurfaceType.Smooth
    hair.Material = Enum.Material.SmoothPlastic
    hair.CFrame = head.CFrame * CFrame.new(0, 0.65, 0)
    -- Weld to head so it follows the character through movement / scaling
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hair
    weld.Part1 = head
    weld.Parent = hair
    hair.Parent = character
    return hair
end

local function applyHead(character, itemId)
    local head = character:FindFirstChild("Head")
    if not head then return end
    head.Color = HEAD_COLORS[itemId] or Color3.fromRGB(255, 220, 180)
end

local function applyHair(character, itemId)
    if not itemId then return end
    local hair = getOrCreateHair(character)
    if not hair then return end
    local idx = tonumber(string.match(itemId, "hair_(%d+)")) or 1
    hair.Color = HAIR_PALETTE[(idx - 1) % #HAIR_PALETTE + 1]
end

local function applyBody(character, itemId)
    if not itemId then return end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local isR15 = hum.RigType == Enum.HumanoidRigType.R15
    if isR15 then
        local scales = BODY_SCALES[itemId]
        if not scales then return end
        local desc = hum:GetAppliedDescription()
        if not desc then return end
        desc.HeightScale = scales.height
        desc.WidthScale  = scales.width
        desc.DepthScale  = scales.depth
        desc.HeadScale   = scales.head
        desc.BodyTypeScale = scales.body
        local ok, err = pcall(function() hum:ApplyDescription(desc) end)
        if not ok then
            warn("[CharacterAppearance] ApplyDescription failed: " .. tostring(err))
        end
    else
        -- R6 fallback: tint torso color
        local tint = BODY_R6_TINTS[itemId]
        if not tint then return end
        local torso = character:FindFirstChild("Torso")
        if torso then torso.Color = tint end
    end
end

local function applyVoice(player, itemId)
    if not itemId then return end
    player:SetAttribute("VoicePack", itemId)
end

-- ===== Top-level apply: read profile and apply every slot =====
local function applyAllForPlayer(player)
    local character = player.Character
    if not character then return end
    local profile = PlayerData:Get(player)
    if not profile or not profile.equipped then return end

    -- Wait briefly for the body to be assembled (Humanoid + parts) so
    -- mutations take effect on the right instances.
    if not character:FindFirstChildOfClass("Humanoid") then
        character:WaitForChild("Humanoid", 5)
    end

    applyHead(character, profile.equipped.Head)
    applyHair(character, profile.equipped.Hair)
    applyBody(character, profile.equipped.Body)
    applyVoice(player,    profile.equipped.Voice)
end

-- ===== Bind to all the trigger surfaces =====
local function bindPlayer(player)
    player.CharacterAdded:Connect(function()
        -- Slight delay so the character finishes loading
        task.defer(function() applyAllForPlayer(player) end)
    end)
    if player.Character then
        task.defer(function() applyAllForPlayer(player) end)
    end
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in ipairs(Players:GetPlayers()) do
    bindPlayer(player)
end

-- When EquipItem fires for a player, EconomyManager has already updated
-- PlayerData (or will, on the same tick — both connections fire on the
-- same RemoteEvent). We re-apply from the profile, so we can't desync.
EquipItemEvent.OnServerEvent:Connect(function(player)
    -- Defer so EconomyManager's connection (which writes PlayerData) runs
    -- first regardless of connection order.
    task.defer(function() applyAllForPlayer(player) end)
end)

print("[CharacterAppearance] Ready — listening to EquipItem + CharacterAdded")
