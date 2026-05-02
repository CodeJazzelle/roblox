-- RoundTimer / Display.client.lua
-- Companion LocalScript for the RoundTimer ScreenGui. Listens to RoundStarted /
-- RoundEnded and updates a centered MM:SS countdown each frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RoundStarted = Remotes:WaitForChild("RoundStarted")
local RoundEnded = Remotes:WaitForChild("RoundEnded")

local screenGui = script.Parent
local DUTCH_BLUE = Color3.fromHex("#005AAB")

local frame = Instance.new("Frame")
frame.Name = "Container"
frame.Size = UDim2.fromOffset(220, 60)
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0, 16)
frame.BackgroundColor3 = DUTCH_BLUE
frame.Visible = false
frame.Parent = screenGui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "0:00"
label.TextColor3 = Color3.new(1, 1, 1)
label.Font = Enum.Font.GothamBold
label.TextSize = 32
label.Parent = frame

-- Mobile shrink: 0.55 keeps the timer readable but well clear of the
-- top order-card strip and the corner button clusters.
if isMobile then
    local mobileScale = Instance.new("UIScale")
    mobileScale.Scale = 0.55
    mobileScale.Parent = frame
end

local roundEndsAt = nil

local function fmt(remaining)
    local r = math.max(0, math.floor(remaining))
    return ("%d:%02d"):format(math.floor(r / 60), r % 60)
end

RoundStarted.OnClientEvent:Connect(function(duration)
    roundEndsAt = tick() + duration
    frame.Visible = true
end)

RoundEnded.OnClientEvent:Connect(function()
    roundEndsAt = nil
    frame.Visible = false
end)

RunService.RenderStepped:Connect(function()
    if not roundEndsAt then return end
    local remaining = roundEndsAt - tick()
    label.Text = fmt(remaining)
    if remaining < 10 then
        label.TextColor3 = Color3.fromRGB(255, 80, 80)
    elseif remaining < 30 then
        label.TextColor3 = Color3.fromRGB(255, 200, 60)
    else
        label.TextColor3 = Color3.new(1, 1, 1)
    end
end)
