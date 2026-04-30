-- RoundManager.lua
-- Top-level controller: starts rounds, tracks tips, ends rounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OrderManager = require(script.Parent:WaitForChild("OrderManager"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RoundStartedEvent = Remotes:WaitForChild("RoundStarted")
local RoundEndedEvent = Remotes:WaitForChild("RoundEnded")
local TipsUpdatedEvent = Remotes:WaitForChild("TipsUpdated")

local RoundManager = {}
RoundManager.TotalTips = 0
RoundManager.RoundLength = 240

function RoundManager:StartRound()
    self.TotalTips = 0
    RoundStartedEvent:FireAllClients(self.RoundLength)
    OrderManager:StartRound(self.RoundLength)

    task.delay(self.RoundLength, function()
        self:EndRound()
    end)
end

function RoundManager:AddTip(amount)
    self.TotalTips += amount
    TipsUpdatedEvent:FireAllClients(self.TotalTips)
end

function RoundManager:EndRound()
    local stars = 1
    if self.TotalTips >= 100 then stars = 2 end
    if self.TotalTips >= 200 then stars = 3 end

    RoundEndedEvent:FireAllClients(self.TotalTips, stars)
end

task.spawn(function()
    while true do
        task.wait(15)
        if #Players:GetPlayers() > 0 then
            RoundManager:StartRound()
            task.wait(RoundManager.RoundLength + 10)
        end
    end
end)

return RoundManager
