-- HandoffWindow.server.lua
-- Wires up parts tagged "HandoffWindow" (the drive-thru counter built in
-- BuildStand) to submit the player's current cup against the OLDEST active
-- order. The cup must be lidded.
--
-- Cross-script glue: this script intentionally talks to StationInteraction
-- via the _G.GetPlayerCup / _G.ClearPlayerCup hooks rather than reaching into
-- its module table. OrderManager:SubmitDrink is monkey-patched in
-- RemotesSetup to award tips and Bro Bucks, so calling it here also fires
-- those side effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local OrderManager = require(script.Parent:WaitForChild("OrderManager"))

local function setupWindow(part)
    local prompt = part:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.HoldDuration = 0.3
        prompt.MaxActivationDistance = 8
        prompt.ActionText = "Hand off"
        prompt.ObjectText = "Drive-Thru"
        prompt.Parent = part
    end

    prompt.Triggered:Connect(function(player)
        local cup = _G.GetPlayerCup and _G.GetPlayerCup(player)
        if not cup or not cup.hasLid then return end

        local oldestId, oldestSpawn = nil, math.huge
        for id, order in pairs(OrderManager.ActiveOrders) do
            if order.spawnedAt < oldestSpawn then
                oldestId, oldestSpawn = id, order.spawnedAt
            end
        end
        if not oldestId then return end

        OrderManager:SubmitDrink(player, oldestId, cup:Serialize())
        if _G.ClearPlayerCup then _G.ClearPlayerCup(player) end
    end)
end

for _, part in ipairs(CollectionService:GetTagged("HandoffWindow")) do
    setupWindow(part)
end
CollectionService:GetInstanceAddedSignal("HandoffWindow"):Connect(setupWindow)
