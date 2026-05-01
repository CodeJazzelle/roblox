-- HandoffFeedback.client.lua
-- Shows a brief center-screen popup whenever the server fires HandoffResult
-- (success or failure), plays a built-in chime, and prints to system chat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HandoffResult = Remotes:WaitForChild("HandoffResult")

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HandoffFeedback"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 60
screenGui.Parent = player:WaitForChild("PlayerGui")

local function spawnPopup(text, bgColor)
    local toast = Instance.new("Frame")
    toast.AnchorPoint = Vector2.new(0.5, 0)
    toast.Position = UDim2.new(0.5, 0, 0, 100)
    toast.Size = UDim2.new(0, 460, 0, 64)
    toast.BackgroundColor3 = bgColor
    toast.BackgroundTransparency = 0
    toast.BorderSizePixel = 0
    toast.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = toast
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Thickness = 2
    stroke.Parent = toast

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.GothamBlack
    label.TextSize = 24
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.5
    label.Parent = toast

    -- Slide in, hold, slide out
    toast.Position = UDim2.new(0.5, 0, 0, 60)
    TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, 100),
    }):Play()

    task.delay(2.5, function()
        local out = TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 0, 60),
            BackgroundTransparency = 1,
        })
        out:Play()
        out.Completed:Wait()
        toast:Destroy()
    end)
end

local function playChime()
    -- Built-in Roblox click — works without uploading custom assets.
    local snd = Instance.new("Sound")
    snd.SoundId = "rbxasset://sounds/electronicpingshort.wav"
    snd.Volume = 1
    snd.Parent = SoundService
    snd:Play()
    snd.Ended:Connect(function() snd:Destroy() end)
    -- Safety cleanup if Ended doesn't fire (some assets don't)
    task.delay(3, function() if snd.Parent then snd:Destroy() end end)
end

local function chatMsg(text, color)
    pcall(function()
        StarterGui:SetCore("ChatMakeSystemMessage", {
            Text = text,
            Color = color,
            Font = Enum.Font.GothamBold,
        })
    end)
end

HandoffResult.OnClientEvent:Connect(function(success, payload)
    if success then
        local tip = tonumber(payload) or 0
        local text = ("Order complete! +%d tips"):format(tip)
        spawnPopup(text, Color3.fromRGB(40, 160, 80))
        chatMsg("[Hand-off] " .. text, Color3.fromRGB(120, 220, 140))
        playChime()
    else
        local reason = tostring(payload or "Wrong drink")
        spawnPopup(reason, Color3.fromRGB(180, 50, 50))
        chatMsg("[Hand-off] " .. reason, Color3.fromRGB(255, 130, 130))
    end
end)
