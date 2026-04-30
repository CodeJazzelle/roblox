-- EndOfRoundScreen / Display.client.lua
-- Modal shown when the round ends. Renders final tips, star rating (1-3), and
-- a Continue button. Driven by the RoundEnded RemoteEvent's (totalTips, stars) payload.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RoundEnded = Remotes:WaitForChild("RoundEnded")

local screenGui = script.Parent
local DUTCH_BLUE = Color3.fromHex("#005AAB")

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.4
backdrop.Visible = false
backdrop.Parent = screenGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(440, 380)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
panel.Parent = backdrop
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 64)
title.BackgroundColor3 = DUTCH_BLUE
title.Text = "Round Complete!"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 26
title.Parent = panel
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = title

local tipsLabel = Instance.new("TextLabel")
tipsLabel.Size = UDim2.new(1, 0, 0, 40)
tipsLabel.Position = UDim2.fromOffset(0, 80)
tipsLabel.BackgroundTransparency = 1
tipsLabel.Text = "Total Tips: 0"
tipsLabel.TextColor3 = Color3.new(1, 1, 1)
tipsLabel.Font = Enum.Font.GothamMedium
tipsLabel.TextSize = 22
tipsLabel.Parent = panel

local starsRow = Instance.new("Frame")
starsRow.Size = UDim2.new(1, -40, 0, 90)
starsRow.Position = UDim2.fromOffset(20, 132)
starsRow.BackgroundTransparency = 1
starsRow.Parent = panel
local starsLayout = Instance.new("UIListLayout")
starsLayout.FillDirection = Enum.FillDirection.Horizontal
starsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
starsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
starsLayout.Padding = UDim.new(0, 12)
starsLayout.Parent = starsRow

local starLabels = {}
for i = 1, 3 do
    local star = Instance.new("TextLabel")
    star.Size = UDim2.fromOffset(80, 90)
    star.BackgroundTransparency = 1
    star.Text = "☆"
    star.TextColor3 = Color3.fromRGB(60, 60, 60)
    star.Font = Enum.Font.GothamBold
    star.TextSize = 72
    star.LayoutOrder = i
    star.Parent = starsRow
    starLabels[i] = star
end

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, -32, 0, 40)
subLabel.Position = UDim2.fromOffset(16, 240)
subLabel.BackgroundTransparency = 1
subLabel.Text = "Bro Bucks awarded — open the merch shop to spend them!"
subLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
subLabel.Font = Enum.Font.Gotham
subLabel.TextSize = 14
subLabel.TextWrapped = true
subLabel.Parent = panel

local continueBtn = Instance.new("TextButton")
continueBtn.Size = UDim2.new(1, -40, 0, 44)
continueBtn.Position = UDim2.new(0, 20, 1, -64)
continueBtn.BackgroundColor3 = DUTCH_BLUE
continueBtn.TextColor3 = Color3.new(1, 1, 1)
continueBtn.Font = Enum.Font.GothamBold
continueBtn.TextSize = 16
continueBtn.Text = "Continue"
continueBtn.AutoButtonColor = true
continueBtn.Parent = panel
local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = continueBtn

continueBtn.MouseButton1Click:Connect(function()
    backdrop.Visible = false
end)

local function popStar(star)
    local scale = Instance.new("UIScale")
    scale.Scale = 0.2
    scale.Parent = star
    TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    task.delay(0.5, function() scale:Destroy() end)
end

RoundEnded.OnClientEvent:Connect(function(totalTips, stars)
    tipsLabel.Text = ("Total Tips: %d"):format(totalTips or 0)
    backdrop.Visible = true
    for i, star in ipairs(starLabels) do
        if i <= (stars or 0) then
            star.Text = "★"
            star.TextColor3 = Color3.fromRGB(255, 200, 60)
            task.delay((i - 1) * 0.2, function() popStar(star) end)
        else
            star.Text = "☆"
            star.TextColor3 = Color3.fromRGB(60, 60, 60)
        end
    end
end)
