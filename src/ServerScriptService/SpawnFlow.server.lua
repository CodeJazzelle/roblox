-- SpawnFlow.server.lua
-- Freeze/unfreeze flow plus an EXPLICIT teleport on every CharacterAdded.
-- The SpawnLocation in BuildStand.server.lua should be enough on its own,
-- but Roblox occasionally spawns characters at default-engine positions
-- (origin, or above any roof) when timing is off. The explicit HRP teleport
-- below guarantees the character lands on the floor at the cup-tower end
-- regardless of what Roblox decides.
--
-- The "shift started" status is held as a player Attribute, so respawning
-- after death does NOT re-freeze the player — but they still get
-- teleported back inside the building.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StartShiftEvent = Remotes:WaitForChild("StartShift")

-- Floor top in BuildStand is Y=0. Player HRP wants to land ~4 studs up so
-- feet rest on the floor. Cup-tower end is X=-40.
local STAND_SPAWN_CFRAME = CFrame.new(-40, 4, 0)

local function setMovementLocked(character, locked)
    local hum = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
    if not hum then return end
    if locked then
        hum.WalkSpeed = 0
        hum.JumpPower = 0
        hum.AutoRotate = false
    else
        hum.WalkSpeed = 16
        hum.JumpPower = 50
        hum.AutoRotate = true
    end
end

local function teleport(character)
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    if hrp then
        hrp.CFrame = STAND_SPAWN_CFRAME
    end
end

local function onCharacterAdded(player, character)
    teleport(character)  -- always teleport, even after START SHIFT
    if player:GetAttribute("ShiftStarted") then
        setMovementLocked(character, false)
    else
        setMovementLocked(character, true)
    end
end

local function bindPlayer(player)
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in ipairs(Players:GetPlayers()) do
    bindPlayer(player)
end

StartShiftEvent.OnServerEvent:Connect(function(player)
    if player:GetAttribute("ShiftStarted") then return end
    player:SetAttribute("ShiftStarted", true)
    if player.Character then
        setMovementLocked(player.Character, false)
    end
end)
