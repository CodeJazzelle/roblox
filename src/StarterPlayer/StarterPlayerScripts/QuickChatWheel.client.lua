-- QuickChatWheel.client.lua
-- Hold C to open a radial menu of Dutch Bros lingo phrases. Click to broadcast.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local QuickChatEvent = Remotes:WaitForChild("QuickChat")
local QuickChatBroadcast = Remotes:WaitForChild("QuickChatBroadcast")

local player = Players.LocalPlayer
local DUTCH_BLUE = Color3.fromHex("#005AAB")

local PHRASES = {
    "Bro!",
    "Bless your day!",
    "Coming up!",
    "Need a hand?",
    "On it!",
    "Refill please!",
    "Whoops!",
    "Order up!",
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QuickChatWheel"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local wheel = Instance.new("Frame")
wheel.Size = UDim2.fromOffset(360, 360)
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.fromScale(0.5, 0.5)
wheel.BackgroundTransparency = 1
wheel.Visible = false
wheel.Parent = screenGui

local center = Instance.new("Frame")
center.Size = UDim2.fromOffset(140, 140)
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.fromScale(0.5, 0.5)
center.BackgroundColor3 = DUTCH_BLUE
center.BackgroundTransparency = 0.2
center.Parent = wheel
local centerCorner = Instance.new("UICorner")
centerCorner.CornerRadius = UDim.new(1, 0)
centerCorner.Parent = center

local hoverLabel = Instance.new("TextLabel")
hoverLabel.Size = UDim2.fromScale(1, 1)
hoverLabel.BackgroundTransparency = 1
hoverLabel.TextColor3 = Color3.new(1, 1, 1)
hoverLabel.Font = Enum.Font.GothamBold
hoverLabel.TextSize = 14
hoverLabel.TextWrapped = true
hoverLabel.Text = "Quick Chat"
hoverLabel.Parent = center

for i, phrase in ipairs(PHRASES) do
    local angle = math.rad((i - 1) * (360 / #PHRASES))
    local r = 130
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(120, 56)
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.Position = UDim2.new(0.5, math.sin(angle) * r, 0.5, -math.cos(angle) * r)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextColor3 = Color3.fromRGB(20, 20, 20)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.Text = phrase
    btn.AutoButtonColor = true
    btn.Parent = wheel
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    btn.MouseEnter:Connect(function() hoverLabel.Text = phrase end)
    btn.MouseLeave:Connect(function() hoverLabel.Text = "Quick Chat" end)
    btn.MouseButton1Click:Connect(function()
        QuickChatEvent:FireServer(phrase)
        wheel.Visible = false
    end)
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.C then
        wheel.Visible = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.C then
        wheel.Visible = false
        hoverLabel.Text = "Quick Chat"
    end
end)

QuickChatBroadcast.OnClientEvent:Connect(function(senderName, phrase)
    -- Placeholder: print to dev console; future work can render a chat bubble
    -- above the sender's character.
    print(("[Quick Chat] %s: %s"):format(senderName, phrase))
end)
