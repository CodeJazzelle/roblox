-- HazardSpawner.lua
-- Spawns environmental hazards during active rounds.
-- StartRound() / StopRound() are wired into the round lifecycle in RemotesSetup.server.lua.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HazardStartedEvent = Remotes:WaitForChild("HazardStarted")
local HazardEndedEvent = Remotes:WaitForChild("HazardEnded")

local HazardSpawner = {}

HazardSpawner.Hazards = {
    {
        id = "SyrupSpill",
        name = "Syrup Spill",
        description = "Sticky patch on the floor - slows anyone who steps on it.",
        duration = 25,
    },
    {
        id = "EspressoFire",
        name = "Espresso Fire!",
        description = "Espresso machine caught fire - put it out at the extinguisher.",
        duration = 20,
    },
    {
        id = "PowerFlicker",
        name = "Power Flicker",
        description = "Lights flicker. Order tickets get harder to read.",
        duration = 15,
    },
    {
        id = "RushSurge",
        name = "Rush Surge",
        description = "Influx of customers - orders spawn 3x faster for a window.",
        duration = 20,
    },
    {
        id = "PickyCustomer",
        name = "Picky Customer",
        description = "One order requires perfect ingredient order or it fails.",
        duration = 60,
    },
    {
        id = "CupShortage",
        name = "Cup Shortage",
        description = "Cup tower locked - refill before continuing.",
        duration = 15,
    },
    {
        id = "SyrupRunOut",
        name = "Syrup Out",
        description = "A random syrup pump is empty for a few seconds.",
        duration = 18,
    },
}

HazardSpawner.Active = {} -- [instanceId] = hazard
HazardSpawner.RoundActive = false
HazardSpawner._nextId = 1

local MIN_INTERVAL = 25
local MAX_INTERVAL = 50
local STARTUP_GRACE = 20

local function pickRandom(list)
    return list[math.random(1, #list)]
end

function HazardSpawner:Spawn(hazardId)
    local hazard
    for _, h in ipairs(self.Hazards) do
        if h.id == hazardId then
            hazard = h
            break
        end
    end
    if not hazard then return end

    local instanceId = self._nextId
    self._nextId += 1
    self.Active[instanceId] = hazard

    HazardStartedEvent:FireAllClients(instanceId, hazard)

    task.delay(hazard.duration, function()
        if self.Active[instanceId] then
            self.Active[instanceId] = nil
            HazardEndedEvent:FireAllClients(instanceId)
        end
    end)
end

function HazardSpawner:SpawnRandom()
    local hazard = pickRandom(self.Hazards)
    self:Spawn(hazard.id)
end

function HazardSpawner:StartRound()
    if self.RoundActive then return end
    self.RoundActive = true
    self.Active = {}

    task.spawn(function()
        task.wait(STARTUP_GRACE)
        while self.RoundActive do
            self:SpawnRandom()
            task.wait(math.random(MIN_INTERVAL, MAX_INTERVAL))
        end
    end)
end

function HazardSpawner:StopRound()
    self.RoundActive = false
    for instanceId, _ in pairs(self.Active) do
        HazardEndedEvent:FireAllClients(instanceId)
    end
    self.Active = {}
end

function HazardSpawner:GetActive()
    return self.Active
end

return HazardSpawner
