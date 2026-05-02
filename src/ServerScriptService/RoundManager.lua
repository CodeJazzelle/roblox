-- RoundManager.lua
-- Top-level controller: starts rounds, tracks tips, ends rounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OrderManager = require(script.Parent:WaitForChild("OrderManager"))
local SoundManager = require(script.Parent:WaitForChild("SoundManager"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RoundStartedEvent = Remotes:WaitForChild("RoundStarted")
local RoundEndedEvent = Remotes:WaitForChild("RoundEnded")
local TipsUpdatedEvent = Remotes:WaitForChild("TipsUpdated")

local RoundManager = {}
RoundManager.TotalTips = 0
RoundManager.RoundLength = 240
RoundManager.RoundActive = false

function RoundManager:StartRound()
    self.RoundActive = true
    self.TotalTips = 0
    RoundStartedEvent:FireAllClients(self.RoundLength)
    OrderManager:StartRound(self.RoundLength)
    SoundManager:PlayAt("round_start", nil, 0.5)

    task.delay(self.RoundLength, function()
        self:EndRound()
    end)
end

function RoundManager:AddTip(amount)
    self.TotalTips += amount
    TipsUpdatedEvent:FireAllClients(self.TotalTips)
end

function RoundManager:EndRound()
    self.RoundActive = false
    local stars = 1
    if self.TotalTips >= 100 then stars = 2 end
    if self.TotalTips >= 200 then stars = 3 end

    RoundEndedEvent:FireAllClients(self.TotalTips, stars)
    SoundManager:PlayAt("round_end", nil, 0.5)

    -- Clear any orders still in the queue so the UI doesn't keep stale
    -- cards visible during the gap before the next round. Goes through
    -- ClearAllOrders (NOT FailOrder) so no failure consequences fire.
    OrderManager:ClearAllOrders("Round ended")

    -- Auto-cycle: 5s end-of-round screen, then start the next round.
    task.delay(5, function()
        if #Players:GetPlayers() > 0 then
            self:StartRound()
        end
    end)
end

-- Auto-start the very first round 3 seconds after the first player
-- joins. Subsequent players join into whatever round is in progress —
-- they don't trigger a new one. The auto-cycle in EndRound handles every
-- round after the first.
local autoStartScheduled = false
Players.PlayerAdded:Connect(function()
    if autoStartScheduled then return end
    if RoundManager.RoundActive then return end
    if #Players:GetPlayers() ~= 1 then return end
    autoStartScheduled = true
    print("[RoundManager] First player joined — starting round automatically")
    task.delay(3, function()
        if not RoundManager.RoundActive and #Players:GetPlayers() > 0 then
            RoundManager:StartRound()
        end
    end)
end)
-- If a player is somehow already present at module-load time (hot reload
-- in Studio), schedule the same first-round auto-start.
if not autoStartScheduled and #Players:GetPlayers() > 0 then
    autoStartScheduled = true
    print("[RoundManager] Player already present — starting round automatically")
    task.delay(3, function()
        if not RoundManager.RoundActive and #Players:GetPlayers() > 0 then
            RoundManager:StartRound()
        end
    end)
end

return RoundManager
