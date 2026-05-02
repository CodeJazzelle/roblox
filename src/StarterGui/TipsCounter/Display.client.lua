-- TipsCounter / Display.client.lua
-- Companion LocalScript for the TipsCounter ScreenGui. Shows the current round's
-- shared tip total (separate from each player's persistent Bro Bucks balance).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Mobile surfaces the tips count inside the drawer; the persistent
-- top-center counter is hidden on touch devices.
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
if isMobile then return end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TipsUpdated = Remotes:WaitForChild("TipsUpdated")
local RoundStarted = Remotes:WaitForChild("RoundStarted")
local RoundEnded = Remotes:WaitForChild("RoundEnded")

local screenGui = script.Parent
local DUTCH_BLUE = Color3.fromHex("#005AAB")

local frame = Instance.new("Frame")
frame.Name = "Container"
frame.Size = UDim2.fromOffset(200, 56)
frame.AnchorPoint = Vector2.new(0.5, 0)
-- Mobile sits the tips block tighter to the timer (which is shrunk to
-- 0.55) so they don't leave a giant gap.
frame.Position = isMobile and UDim2.new(0.5, 0, 0, 56) or UDim2.new(0.5, 0, 0, 84)
frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
frame.Visible = false
frame.Parent = screenGui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "Tips: 0"
label.TextColor3 = DUTCH_BLUE
label.Font = Enum.Font.GothamBold
label.TextSize = 22
label.Parent = frame

if isMobile then
    local mobileScale = Instance.new("UIScale")
    mobileScale.Scale = 0.55
    mobileScale.Parent = frame
end

local function pulse()
    local scale = Instance.new("UIScale")
    scale.Scale = 1.15
    scale.Parent = frame
    TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Scale = 1}):Play()
    task.delay(0.3, function() scale:Destroy() end)
end

TipsUpdated.OnClientEvent:Connect(function(total)
    label.Text = ("Tips: %d"):format(total or 0)
    pulse()
end)

RoundStarted.OnClientEvent:Connect(function()
    label.Text = "Tips: 0"
    frame.Visible = true
end)

RoundEnded.OnClientEvent:Connect(function()
    frame.Visible = false
end)
