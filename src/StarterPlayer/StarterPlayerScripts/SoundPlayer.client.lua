-- SoundPlayer.client.lua
-- Listens to the PlaySound RemoteEvent and creates one-shot Sound
-- instances locally. Wraps everything in pcall so a bad asset ID prints
-- a warning instead of crashing.
--
-- Server fires PlaySound with (soundId: string, target: BasePart?, volume: number).
-- If target is a Part, the sound parents there for 3D audio. Otherwise it
-- parents to SoundService for a flat 2D play.
--
-- Each created sound auto-cleans on .Ended; a 10s safety timer destroys
-- any sound whose .Ended doesn't fire (some assets never report end).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlaySoundEvent = Remotes:WaitForChild("PlaySound")

local player = Players.LocalPlayer

PlaySoundEvent.OnClientEvent:Connect(function(soundId, target, volume)
    if not soundId or type(soundId) ~= "string" then return end

    local sound
    local createOk, createErr = pcall(function()
        sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = tonumber(volume) or 0.5
        sound.RollOffMaxDistance = 80
        sound.RollOffMinDistance = 6
        if typeof(target) == "Instance" and target:IsA("BasePart") then
            sound.Parent = target
        else
            sound.Parent = SoundService
        end
    end)
    if not createOk then
        warn(("[SoundPlayer] Sound construction failed for %s: %s"):format(tostring(soundId), tostring(createErr)))
        return
    end
    if not sound then return end

    -- :Play() guarded separately so a bad asset can't ever crash gameplay
    local playOk, playErr = pcall(function() sound:Play() end)
    if not playOk then
        warn(("[SoundPlayer] :Play() failed for %s: %s"):format(tostring(soundId), tostring(playErr)))
        sound:Destroy()
        return
    end

    sound.Ended:Connect(function() sound:Destroy() end)
    -- Some assets (especially missing/403 ones) never fire .Ended; safety
    -- destroy after 10s so we don't leak Sound instances in SoundService.
    task.delay(10, function()
        if sound and sound.Parent then sound:Destroy() end
    end)
end)
