-- SpawnFlow.server.lua
-- Simple freeze/unfreeze flow. The player spawns at the invisible
-- StandSpawn (created by BuildStand at the cup-tower end), so no teleport
-- is required here — we just lock movement until the customizer's
-- START SHIFT button fires the StartShift remote.
--
-- The "shift started" status is held as a player Attribute, so respawning
-- after death does NOT re-freeze the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StartShiftEvent = Remotes:WaitForChild("StartShift")

local function setMovementLocked(character, locked)
    local hum = character:FindFirstChildOfClass("Humanoid")
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

local function onCharacterAdded(player, character)
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
