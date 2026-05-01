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

    local ok, err = pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = tonumber(volume) or 0.5
        sound.RollOffMaxDistance = 80
        sound.RollOffMinDistance = 6

        if typeof(target) == "Instance" and target:IsA("BasePart") then
            sound.Parent = target
        else
            sound.Parent = SoundService
        end

        sound:Play()
        sound.Ended:Connect(function()
            sound:Destroy()
        end)
        -- Safety: some assets never fire .Ended (e.g. bad IDs that
        -- silently fail to load). Destroy after 10s no matter what.
        task.delay(10, function()
            if sound and sound.Parent then sound:Destroy() end
        end)
    end)

    if not ok then
        warn(("[SoundPlayer] Failed to play sound %s: %s"):format(tostring(soundId), tostring(err)))
    end
end)
