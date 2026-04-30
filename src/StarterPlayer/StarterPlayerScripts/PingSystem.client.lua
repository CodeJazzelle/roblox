-- PingSystem.client.lua
-- Hold G then click to ping a world location. Pings broadcast to every player as
-- a brief 3D marker.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PingPlaced = Remotes:WaitForChild("PingPlaced")
local PingBroadcast = Remotes:WaitForChild("PingBroadcast")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local DUTCH_BLUE = Color3.fromHex("#005AAB")

local pingMode = false
local PING_COOLDOWN = 1.5
local lastPing = 0

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.G then
        pingMode = true
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 and pingMode then
        if tick() - lastPing < PING_COOLDOWN then return end
        local target = mouse.Hit
        if target then
            lastPing = tick()
            PingPlaced:FireServer(target.Position)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.G then
        pingMode = false
    end
end)

local function spawnPingMarker(senderName, position)
    local marker = Instance.new("Part")
    marker.Anchored = true
    marker.CanCollide = false
    marker.CanQuery = false
    marker.CanTouch = false
    marker.Size = Vector3.new(2, 0.2, 2)
    marker.Color = DUTCH_BLUE
    marker.Material = Enum.Material.Neon
    marker.Position = position + Vector3.new(0, 1, 0)
    marker.Parent = Workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromOffset(160, 40)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Parent = marker

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 0.3
    label.BackgroundColor3 = DUTCH_BLUE
    label.Text = senderName .. " pinged here"
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = billboard

    TweenService:Create(marker, TweenInfo.new(5, Enum.EasingStyle.Quad), {
        Transparency = 1,
        Size = Vector3.new(8, 0.2, 8),
    }):Play()
    task.delay(5, function() marker:Destroy() end)
end

PingBroadcast.OnClientEvent:Connect(spawnPingMarker)
